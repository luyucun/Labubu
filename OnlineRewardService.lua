--[[
脚本名称: OnlineRewardService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/OnlineRewardService
版本: V1.0
职责: 在线奖励累计、每日UTC0重置、领取与状态同步
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configFolder = ReplicatedStorage:WaitForChild("Config")
local CapsuleConfig = require(configFolder:WaitForChild("CapsuleConfig"))
local OnlineRewardConfig = require(configFolder:WaitForChild("OnlineRewardConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EggService = require(script.Parent:WaitForChild("EggService"))
local PotionService = require(script.Parent:WaitForChild("PotionService"))

local OnlineRewardService = {}
OnlineRewardService.__index = OnlineRewardService

local CLAIM_COOLDOWN = 0.3
local PLAYTIME_PUSH_INTERVAL = 5

local playerStates = {} -- [userId] = {LastPushClock, LastHasClaimable, LastDayKey, LastClaimClock}
local rewardById = {}
local rewardList = {}

local function buildRewardIndex()
	table.clear(rewardById)
	table.clear(rewardList)
	for _, info in ipairs(OnlineRewardConfig.GetAll()) do
		if info and info.Id then
			local id = tonumber(info.Id) or info.Id
			local reward = {
				Id = id,
				Seconds = math.max(0, math.floor(tonumber(info.Seconds) or 0)),
				Kind = tostring(info.Kind or ""),
				ItemId = tonumber(info.ItemId) or info.ItemId,
				Count = math.max(0, math.floor(tonumber(info.Count) or 0)),
			}
			rewardById[id] = reward
			table.insert(rewardList, reward)
		end
	end
	table.sort(rewardList, function(a, b)
		if a.Seconds == b.Seconds then
			return (tonumber(a.Id) or 0) < (tonumber(b.Id) or 0)
		end
		return a.Seconds < b.Seconds
	end)
end
buildRewardIndex()

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

local requestOnlineRewardDataEvent = ensureRemoteEvent("RequestOnlineRewardData")
local pushOnlineRewardDataEvent = ensureRemoteEvent("PushOnlineRewardData")
local requestOnlineRewardClaimEvent = ensureRemoteEvent("RequestOnlineRewardClaim")
local pushOnlineRewardClaimedEvent = ensureRemoteEvent("PushOnlineRewardClaimed")
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
		if info.Id == capsuleId then
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
		LastPushClock = 0,
		LastHasClaimable = false,
		LastDayKey = 0,
		LastClaimClock = 0,
	}
	playerStates[player.UserId] = state
	return state
end

local function buildPayload(player, now)
	DataService:ResetOnlineRewardIfNeeded(player, now)
	local snapshot = DataService:GetOnlineRewardSnapshot(player, now)
	if not snapshot then
		return nil
	end

	local onlineSeconds = math.max(0, math.floor(tonumber(snapshot.OnlineSeconds) or 0))
	local claimed = type(snapshot.Claimed) == "table" and snapshot.Claimed or {}

	local hasClaimable = false
	local nextRewardId = 0
	local nextRewardRemaining = 0

	for _, reward in ipairs(rewardList) do
		local isClaimed = claimed[reward.Id] == true
		if not isClaimed then
			if onlineSeconds >= reward.Seconds then
				hasClaimable = true
			else
				if nextRewardId == 0 then
					nextRewardId = reward.Id
					nextRewardRemaining = math.max(0, reward.Seconds - onlineSeconds)
				end
			end
		end
	end

	if nextRewardId == 0 then
		for _, reward in ipairs(rewardList) do
			if claimed[reward.Id] ~= true then
				nextRewardId = reward.Id
				nextRewardRemaining = math.max(0, reward.Seconds - onlineSeconds)
				break
			end
		end
	end

	return {
		ServerTime = now or os.time(),
		DayKey = snapshot.DayKey,
		OnlineSeconds = onlineSeconds,
		Claimed = claimed,
		HasClaimable = hasClaimable,
		NextRewardId = nextRewardId,
		NextRewardRemaining = nextRewardRemaining,
	}
end

function OnlineRewardService:PushState(player, now)
	if not player or not player.Parent or not pushOnlineRewardDataEvent then
		return nil
	end
	local payload = buildPayload(player, now or os.time())
	if not payload then
		return nil
	end
	pushOnlineRewardDataEvent:FireClient(player, payload)
	local state = getPlayerState(player)
	state.LastPushClock = os.clock()
	state.LastHasClaimable = payload.HasClaimable == true
	state.LastDayKey = tonumber(payload.DayKey) or 0
	return payload
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

function OnlineRewardService:HandleClaim(player, rewardId)
	if not player or not player.Parent then
		return
	end
	if not DataService:GetData(player) then
		return
	end
	local state = getPlayerState(player)
	local nowClock = os.clock()
	if nowClock - state.LastClaimClock < CLAIM_COOLDOWN then
		return
	end
	state.LastClaimClock = nowClock

	local id = tonumber(rewardId) or rewardId
	local reward = id and rewardById[id] or nil
	if not reward then
		return
	end

	local now = os.time()
	local payload = buildPayload(player, now)
	if not payload then
		return
	end
	if payload.Claimed[reward.Id] == true then
		sendErrorHint(player, "OnlineReward", "Already claimed")
		return
	end
	if payload.OnlineSeconds < reward.Seconds then
		sendErrorHint(player, "OnlineReward", "Not ready yet")
		return
	end

	local rewards = grantReward(player, reward)
	if not rewards then
		sendErrorHint(player, "OnlineReward", "Reward config invalid")
		return
	end

	local changed = DataService:SetOnlineRewardClaimed(player, reward.Id, true, now)
	if not changed then
		sendErrorHint(player, "OnlineReward", "Already claimed")
		return
	end

	local latestPayload = self:PushState(player, now) or buildPayload(player, now)
	if pushOnlineRewardClaimedEvent and latestPayload then
		pushOnlineRewardClaimedEvent:FireClient(player, reward.Id, rewards, latestPayload)
	end
end

function OnlineRewardService:BindPlayer(player)
	if not player or not player.Parent then
		return
	end
	playerStates[player.UserId] = nil
	self:PushState(player, os.time())
end

function OnlineRewardService:UnbindPlayer(player)
	if not player then
		return
	end
	playerStates[player.UserId] = nil
end

function OnlineRewardService:Init()
	if requestOnlineRewardDataEvent then
		requestOnlineRewardDataEvent.OnServerEvent:Connect(function(player)
			if not player or not player.Parent then
				return
			end
			self:PushState(player, os.time())
		end)
	end

	if requestOnlineRewardClaimEvent then
		requestOnlineRewardClaimEvent.OnServerEvent:Connect(function(player, rewardId)
			self:HandleClaim(player, rewardId)
		end)
	end

	DataService:RegisterPlaytimeListener(function(player)
		if not player or not player.Parent then
			return
		end
		local state = playerStates[player.UserId]
		if not state then
			return
		end
		local payload = buildPayload(player, os.time())
		if not payload then
			return
		end
		local nowClock = os.clock()
		local hasChanged = payload.HasClaimable ~= state.LastHasClaimable
			or (tonumber(payload.DayKey) or 0) ~= state.LastDayKey
		if hasChanged or (nowClock - state.LastPushClock) >= PLAYTIME_PUSH_INTERVAL then
			self:PushState(player)
		end
	end)
end

return OnlineRewardService
