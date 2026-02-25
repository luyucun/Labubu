--[[
脚本名称: SevenDayRewardService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/SevenDayRewardService
版本: V1.0
职责: 七日登录奖励状态流转、领奖与一键解锁
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configFolder = ReplicatedStorage:WaitForChild("Config")
local CapsuleConfig = require(configFolder:WaitForChild("CapsuleConfig"))
local SevenDayRewardConfig = require(configFolder:WaitForChild("SevenDayRewardConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EggService = require(script.Parent:WaitForChild("EggService"))
local PotionService = require(script.Parent:WaitForChild("PotionService"))

local SevenDayRewardService = {}
SevenDayRewardService.__index = SevenDayRewardService

local UTC_DAY_SECONDS = 86400
local CLAIM_COOLDOWN = 0.25
local UNLOCK_REQUEST_COOLDOWN = 0.5

local rewardList = {}
local rewardByDay = {}
local validDays = {}
local maxDay = 0
local firstDay = 1

local playerStates = {} -- [userId] = {LastHasClaimable, LastFeatureUnlocked, LastRound, LastPendingReset, LastClaimClock, LastUnlockClock}

local function normalizeNonNegativeInt(value, fallback)
	local num = tonumber(value)
	if not num then
		return math.max(0, math.floor(tonumber(fallback) or 0))
	end
	if num < 0 then
		num = 0
	end
	return math.floor(num)
end

local function getUtcDayKey(timestamp)
	local now = normalizeNonNegativeInt(timestamp, os.time())
	return math.floor(now / UTC_DAY_SECONDS)
end

local function getSecondsUntilNextUtc(timestamp)
	local now = normalizeNonNegativeInt(timestamp, os.time())
	local dayKey = math.floor(now / UTC_DAY_SECONDS)
	local nextBoundary = (dayKey + 1) * UTC_DAY_SECONDS
	return math.max(0, nextBoundary - now)
end

local function rebuildRewardIndex()
	table.clear(rewardList)
	table.clear(rewardByDay)
	table.clear(validDays)
	maxDay = 0
	for _, info in ipairs(SevenDayRewardConfig.GetAll()) do
		if info and info.Day then
			local day = tonumber(info.Day) or info.Day
			local reward = {
				Day = day,
				Kind = tostring(info.Kind or ""),
				ItemId = tonumber(info.ItemId) or info.ItemId,
				Count = math.max(0, math.floor(tonumber(info.Count) or 0)),
			}
			table.insert(rewardList, reward)
			rewardByDay[day] = reward
			validDays[day] = true
			if type(day) == "number" and day > maxDay then
				maxDay = day
			end
		end
	end
	table.sort(rewardList, function(a, b)
		return (tonumber(a.Day) or 0) < (tonumber(b.Day) or 0)
	end)
	if rewardList[1] and rewardList[1].Day then
		firstDay = rewardList[1].Day
	else
		firstDay = 1
	end
end
rebuildRewardIndex()

local function ensureLabubuEvents()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		eventsFolder = Instance.new("Folder")
		eventsFolder.Name = "Events"
		eventsFolder.Parent = ReplicatedStorage
	end
	local labubuEvents = eventsFolder:FindFirstChild("LabubuEvents")
	if not labubuEvents then
		labubuEvents = Instance.new("Folder")
		labubuEvents.Name = "LabubuEvents"
		labubuEvents.Parent = eventsFolder
	end
	return labubuEvents
end

local function ensureRemoteEvent(name)
	local labubuEvents = ensureLabubuEvents()
	local event = labubuEvents:FindFirstChild(name)
	if event and not event:IsA("RemoteEvent") then
		event:Destroy()
		event = nil
	end
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = labubuEvents
	end
	return event
end

local requestDataEvent = ensureRemoteEvent("RequestSevenDayRewardData")
local pushDataEvent = ensureRemoteEvent("PushSevenDayRewardData")
local requestClaimEvent = ensureRemoteEvent("RequestSevenDayRewardClaim")
local pushClaimedEvent = ensureRemoteEvent("PushSevenDayRewardClaimed")
local requestUnlockAllEvent = ensureRemoteEvent("RequestSevenDayUnlockAll")
local errorHintEvent = ensureRemoteEvent("ErrorHint")

local function sendErrorHint(player, code, message)
	if not player or not player.Parent or not errorHintEvent then
		return
	end
	errorHintEvent:FireClient(player, code, message)
end

local function getCapsuleInfo(capsuleId)
	if type(CapsuleConfig.GetById) == "function" then
		return CapsuleConfig.GetById(capsuleId)
	end
	local list = CapsuleConfig.Capsules
	if type(list) ~= "table" and type(CapsuleConfig) == "table" then
		list = CapsuleConfig
	end
	if type(list) ~= "table" then
		return nil
	end
	for _, info in ipairs(list) do
		if info and info.Id == capsuleId then
			return info
		end
	end
	return nil
end

local function getPlayerState(player)
	local state = playerStates[player.UserId]
	if state then
		return state
	end
	state = {
		LastHasClaimable = false,
		LastFeatureUnlocked = false,
		LastRound = 0,
		LastPendingReset = false,
		LastClaimClock = 0,
		LastUnlockClock = 0,
	}
	playerStates[player.UserId] = state
	return state
end

local function normalizeDayMap(value)
	if type(value) ~= "table" then
		return {}, true
	end
	local normalized = {}
	local changed = false
	for key, claimed in pairs(value) do
		local day = tonumber(key) or key
		if day and validDays[day] and claimed == true then
			normalized[day] = true
			if key ~= day then
				changed = true
			end
		else
			changed = true
		end
	end
	return normalized, changed
end

local function buildDefaultState(nowDayKey)
	local state = {
		Round = 1,
		LastUnlockDayKey = nowDayKey,
		Claimed = {},
		Claimable = {},
		PendingReset = false,
	}
	if firstDay then
		state.Claimable[firstDay] = true
	end
	return state
end

local function hasClaimable(state)
	for day, unlocked in pairs(state.Claimable) do
		if unlocked == true and state.Claimed[day] ~= true then
			return true
		end
	end
	return false
end

local function hasLockedRewards(state)
	for _, reward in ipairs(rewardList) do
		local day = reward.Day
		if state.Claimed[day] ~= true and state.Claimable[day] ~= true then
			return true
		end
	end
	return false
end

local function areAllRewardsClaimed(state)
	for _, reward in ipairs(rewardList) do
		if state.Claimed[reward.Day] ~= true then
			return false
		end
	end
	return #rewardList > 0
end

local function getNextLockedDay(state)
	for _, reward in ipairs(rewardList) do
		local day = reward.Day
		if state.Claimed[day] ~= true and state.Claimable[day] ~= true then
			return day
		end
	end
	return nil
end

local function normalizeState(rawState, nowDayKey)
	if type(rawState) ~= "table" then
		return buildDefaultState(nowDayKey), true
	end
	local state = rawState
	local changed = false

	local round = normalizeNonNegativeInt(state.Round, 1)
	if round < 1 then
		round = 1
	end
	if state.Round ~= round then
		state.Round = round
		changed = true
	end

	local lastUnlockDayKey = normalizeNonNegativeInt(state.LastUnlockDayKey, nowDayKey)
	if state.LastUnlockDayKey ~= lastUnlockDayKey then
		state.LastUnlockDayKey = lastUnlockDayKey
		changed = true
	end

	local claimedMap, claimedChanged = normalizeDayMap(state.Claimed)
	if claimedChanged then
		state.Claimed = claimedMap
		changed = true
	elseif type(state.Claimed) ~= "table" then
		state.Claimed = claimedMap
		changed = true
	end

	local claimableMap, claimableChanged = normalizeDayMap(state.Claimable)
	if claimableChanged then
		state.Claimable = claimableMap
		changed = true
	elseif type(state.Claimable) ~= "table" then
		state.Claimable = claimableMap
		changed = true
	end

	local pendingReset = state.PendingReset == true
	if state.PendingReset ~= pendingReset then
		state.PendingReset = pendingReset
		changed = true
	end

	for day, unlocked in pairs(state.Claimable) do
		if unlocked == true and state.Claimed[day] == true then
			state.Claimable[day] = nil
			changed = true
		end
	end

	if next(state.Claimed) == nil and next(state.Claimable) == nil and not state.PendingReset and state.Round <= 1 then
		if firstDay then
			state.Claimable[firstDay] = true
		end
		if state.LastUnlockDayKey ~= nowDayKey then
			state.LastUnlockDayKey = nowDayKey
		end
		changed = true
	end

	return state, changed
end

local function refreshState(state, nowDayKey, allowRoundReset)
	local changed = false

	if allowRoundReset and state.PendingReset then
		state.Round = math.max(1, normalizeNonNegativeInt(state.Round, 1)) + 1
		state.Claimed = {}
		state.Claimable = {}
		state.PendingReset = false
		state.LastUnlockDayKey = nowDayKey
		changed = true
	end

	for day, unlocked in pairs(state.Claimable) do
		if unlocked == true and state.Claimed[day] == true then
			state.Claimable[day] = nil
			changed = true
		end
	end

	if areAllRewardsClaimed(state) then
		if not state.PendingReset then
			state.PendingReset = true
			changed = true
		end
		return changed
	end

	if state.PendingReset then
		state.PendingReset = false
		changed = true
	end

	if hasClaimable(state) then
		if nowDayKey > state.LastUnlockDayKey then
			state.LastUnlockDayKey = nowDayKey
			changed = true
		end
		return changed
	end

	if nowDayKey > state.LastUnlockDayKey then
		local nextDay = getNextLockedDay(state)
		if nextDay then
			state.Claimable[nextDay] = true
			changed = true
		end
		state.LastUnlockDayKey = nowDayKey
		changed = true
	end

	return changed
end

local function getOpenedCapsuleTotal(player)
	local total = 0
	if DataService and DataService.GetCapsuleOpenTotal then
		total = tonumber(DataService:GetCapsuleOpenTotal(player)) or 0
	end
	if total <= 0 and player then
		total = tonumber(player:GetAttribute("CapsuleOpenTotal")) or total
	end
	if total < 0 then
		total = 0
	end
	return math.floor(total)
end

local function getUnlockThreshold()
	return math.max(0, math.floor(tonumber(SevenDayRewardConfig.UnlockCapsuleOpenTotal) or 0))
end

local function isFeatureUnlocked(player)
	local threshold = getUnlockThreshold()
	if threshold <= 0 then
		return true
	end
	return getOpenedCapsuleTotal(player) >= threshold
end

local function getOrCreateState(player, nowTimestamp, allowRoundReset)
	local data = DataService:GetData(player)
	if type(data) ~= "table" then
		return nil, false
	end
	local nowDayKey = getUtcDayKey(nowTimestamp)
	local state, changed = normalizeState(data.SevenDayReward, nowDayKey)
	if data.SevenDayReward ~= state then
		data.SevenDayReward = state
		changed = true
	end
	if refreshState(state, nowDayKey, allowRoundReset) then
		changed = true
	end
	if changed then
		DataService:MarkDirty(player)
	end
	return state, changed
end

local function buildRewardsPayload(state)
	local list = {}
	for _, reward in ipairs(rewardList) do
		local day = reward.Day
		table.insert(list, {
			Day = day,
			Kind = reward.Kind,
			ItemId = reward.ItemId,
			Count = reward.Count,
			Claimed = state.Claimed[day] == true,
			Claimable = state.Claimable[day] == true and state.PendingReset ~= true,
		})
	end
	return list
end

local function buildPayload(player, nowTimestamp, allowRoundReset)
	local now = normalizeNonNegativeInt(nowTimestamp, os.time())
	local state, changed = getOrCreateState(player, now, allowRoundReset)
	if not state then
		return nil, false
	end
	local featureUnlocked = isFeatureUnlocked(player)
	local openedCapsules = getOpenedCapsuleTotal(player)
	local payload = {
		ServerTime = now,
		DayKey = getUtcDayKey(now),
		Round = normalizeNonNegativeInt(state.Round, 1),
		PendingReset = state.PendingReset == true,
		IsFeatureUnlocked = featureUnlocked,
		UnlockNeedCapsules = getUnlockThreshold(),
		OpenedCapsules = openedCapsules,
		HasClaimable = featureUnlocked and hasClaimable(state),
		HasLockedRewards = hasLockedRewards(state),
		NextRefreshSeconds = getSecondsUntilNextUtc(now),
		Rewards = buildRewardsPayload(state),
	}
	return payload, changed
end

local function grantReward(player, reward)
	if not reward or reward.Count <= 0 then
		return {}
	end
	if reward.Kind == "Capsule" then
		local capsuleId = tonumber(reward.ItemId)
		if not capsuleId then
			return nil
		end
		local info = getCapsuleInfo(capsuleId)
		for _ = 1, reward.Count do
			DataService:AddEgg(player, capsuleId)
			if info then
				EggService:GiveCapsuleTool(player, info)
			end
		end
		return {
			{ Kind = "Capsule", ItemId = capsuleId, Count = reward.Count },
		}
	end
	if reward.Kind == "Potion" then
		local potionId = tonumber(reward.ItemId)
		if not potionId then
			return nil
		end
		DataService:AddPotionCount(player, potionId, reward.Count)
		if PotionService and PotionService.PushState then
			PotionService:PushState(player)
		end
		return {
			{ Kind = "Potion", ItemId = potionId, Count = reward.Count },
		}
	end
	return nil
end

function SevenDayRewardService:PushState(player, options)
	if not player or not player.Parent then
		return nil, false, false
	end
	if not DataService:GetData(player) then
		return nil, false, false
	end
	local opt = type(options) == "table" and options or {}
	local now = normalizeNonNegativeInt(opt.Now, os.time())
	local allowRoundReset = opt.AllowRoundReset == true
	local forcePush = opt.Force == true
	local payload, changed = buildPayload(player, now, allowRoundReset)
	if not payload then
		return nil, false, false
	end

	local cache = getPlayerState(player)
	local shouldPush = forcePush
	if not shouldPush then
		shouldPush = changed
			or payload.HasClaimable ~= cache.LastHasClaimable
			or payload.IsFeatureUnlocked ~= cache.LastFeatureUnlocked
			or payload.Round ~= cache.LastRound
			or payload.PendingReset ~= cache.LastPendingReset
	end

	if shouldPush and pushDataEvent then
		pushDataEvent:FireClient(player, payload)
	end

	cache.LastHasClaimable = payload.HasClaimable == true
	cache.LastFeatureUnlocked = payload.IsFeatureUnlocked == true
	cache.LastRound = normalizeNonNegativeInt(payload.Round, 1)
	cache.LastPendingReset = payload.PendingReset == true

	return payload, changed, shouldPush
end

function SevenDayRewardService:HandleClaim(player, day)
	if not player or not player.Parent then
		return
	end
	if not DataService:GetData(player) then
		return
	end

	local cache = getPlayerState(player)
	local nowClock = os.clock()
	if nowClock - cache.LastClaimClock < CLAIM_COOLDOWN then
		return
	end
	cache.LastClaimClock = nowClock

	if not isFeatureUnlocked(player) then
		sendErrorHint(player, "SevenDayReward", "Feature locked")
		return
	end

	local rewardDay = tonumber(day) or day
	local reward = rewardByDay[rewardDay]
	if not reward then
		return
	end

	local now = os.time()
	local state = select(1, getOrCreateState(player, now, false))
	if not state then
		return
	end
	if state.PendingReset then
		sendErrorHint(player, "SevenDayReward", "Open panel to refresh next round")
		return
	end
	if state.Claimed[rewardDay] == true then
		sendErrorHint(player, "SevenDayReward", "Already claimed")
		return
	end
	if state.Claimable[rewardDay] ~= true then
		sendErrorHint(player, "SevenDayReward", "Not ready yet")
		return
	end

	local rewards = grantReward(player, reward)
	if not rewards then
		sendErrorHint(player, "SevenDayReward", "Reward config invalid")
		return
	end

	state.Claimable[rewardDay] = nil
	state.Claimed[rewardDay] = true
	if areAllRewardsClaimed(state) then
		state.PendingReset = true
	end
	DataService:MarkDirty(player)

	local payload = self:PushState(player, { Now = now, AllowRoundReset = false, Force = true })
	if pushClaimedEvent and payload then
		pushClaimedEvent:FireClient(player, rewardDay, rewards, payload)
	end
end

function SevenDayRewardService:HandleUnlockAllRequest(player)
	if not player or not player.Parent then
		return
	end
	if not DataService:GetData(player) then
		return
	end

	local cache = getPlayerState(player)
	local nowClock = os.clock()
	if nowClock - cache.LastUnlockClock < UNLOCK_REQUEST_COOLDOWN then
		return
	end
	cache.LastUnlockClock = nowClock

	if not isFeatureUnlocked(player) then
		sendErrorHint(player, "SevenDayReward", "Feature locked")
		return
	end

	local now = os.time()
	local state = select(1, getOrCreateState(player, now, false))
	if not state then
		return
	end
	if state.PendingReset then
		sendErrorHint(player, "SevenDayReward", "Open panel to refresh next round")
		return
	end
	if not hasLockedRewards(state) then
		return
	end

	local productId = SevenDayRewardConfig.GetPrimaryUnlockAllProductId()
	if not productId or productId <= 0 then
		return
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

function SevenDayRewardService:IsUnlockAllProductId(productId)
	return SevenDayRewardConfig.IsUnlockAllProductId(productId)
end

function SevenDayRewardService:HandleUnlockAllReceipt(player, productId)
	if not self:IsUnlockAllProductId(productId) then
		return false
	end
	if not player or not player.Parent then
		return true
	end
	if not DataService:GetData(player) then
		return true
	end

	local now = os.time()
	local state = select(1, getOrCreateState(player, now, false))
	if not state then
		return true
	end
	local changed = false
	if not state.PendingReset and isFeatureUnlocked(player) then
		for _, reward in ipairs(rewardList) do
			local day = reward.Day
			if state.Claimed[day] ~= true and state.Claimable[day] ~= true then
				state.Claimable[day] = true
				changed = true
			end
		end
		local nowDayKey = getUtcDayKey(now)
		if state.LastUnlockDayKey ~= nowDayKey then
			state.LastUnlockDayKey = nowDayKey
			changed = true
		end
	end
	if changed then
		DataService:MarkDirty(player)
	end
	self:PushState(player, { Now = now, AllowRoundReset = false, Force = true })
	return true
end

function SevenDayRewardService:BindPlayer(player)
	if not player or not player.Parent then
		return
	end
	playerStates[player.UserId] = nil
	self:PushState(player, { Now = os.time(), AllowRoundReset = false, Force = true })
end

function SevenDayRewardService:UnbindPlayer(player)
	if not player then
		return
	end
	playerStates[player.UserId] = nil
end

function SevenDayRewardService:Init()
	if requestDataEvent then
		requestDataEvent.OnServerEvent:Connect(function(player, allowRoundReset)
			if not player or not player.Parent then
				return
			end
			self:PushState(player, {
				Now = os.time(),
				AllowRoundReset = allowRoundReset == true,
				Force = true,
			})
		end)
	end

	if requestClaimEvent then
		requestClaimEvent.OnServerEvent:Connect(function(player, day)
			self:HandleClaim(player, day)
		end)
	end

	if requestUnlockAllEvent then
		requestUnlockAllEvent.OnServerEvent:Connect(function(player)
			self:HandleUnlockAllRequest(player)
		end)
	end

	DataService:RegisterPlaytimeListener(function(player)
		if not player or not player.Parent then
			return
		end
		if not playerStates[player.UserId] then
			return
		end
		self:PushState(player, {
			Now = os.time(),
			AllowRoundReset = false,
			Force = false,
		})
	end)
end

return SevenDayRewardService
