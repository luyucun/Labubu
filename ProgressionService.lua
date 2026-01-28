--[[
脚本名称: ProgressionService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/ProgressionService
版本: V1.0
职责: 养成系统成就进度、领奖与加成计算
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configFolder = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(configFolder:WaitForChild("GameConfig"))
local CapsuleConfig = require(configFolder:WaitForChild("CapsuleConfig"))
local FigurineConfig = require(configFolder:WaitForChild("FigurineConfig"))
local ProgressionConfig = require(configFolder:WaitForChild("ProgressionConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local ProgressionService = {}
ProgressionService.__index = ProgressionService

local rng = Random.new()
local playerStates = {}
local initDone = false

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

local requestProgressionDataEvent = ensureRemoteEvent("RequestProgressionData")
local pushProgressionDataEvent = ensureRemoteEvent("PushProgressionData")
local requestProgressionClaimEvent = ensureRemoteEvent("RequestProgressionClaim")
local pushProgressionClaimedEvent = ensureRemoteEvent("PushProgressionClaimed")

local capsuleInfoById = {}
local function buildCapsuleIndex()
	table.clear(capsuleInfoById)
	local list = CapsuleConfig.Capsules
	if type(list) ~= "table" and type(CapsuleConfig) == "table" then
		list = CapsuleConfig
	end
	if type(list) ~= "table" then
		return
	end
	for _, info in ipairs(list) do
		if info and info.Id then
			capsuleInfoById[info.Id] = info
		end
	end
end
buildCapsuleIndex()

local figurineById = {}
local orderByQuality = {}
local orderIndexById = {}
local qualityTierMap = {}
local maxTierByQuality = {}

local function buildFigurineIndex()
	table.clear(figurineById)
	table.clear(orderByQuality)
	table.clear(orderIndexById)
	table.clear(qualityTierMap)
	table.clear(maxTierByQuality)

	local list = FigurineConfig.Figurines
	if type(list) ~= "table" then
		return
	end

	for _, info in ipairs(list) do
		if info and info.Id then
			figurineById[info.Id] = info
			local quality = tonumber(info.Quality) or 0
			if quality > 0 then
				orderByQuality[quality] = orderByQuality[quality] or {}
				table.insert(orderByQuality[quality], info)
			end
		end
	end

	for quality, entries in pairs(orderByQuality) do
		table.sort(entries, function(a, b)
			return (tonumber(a.Id) or 0) < (tonumber(b.Id) or 0)
		end)
		for index, info in ipairs(entries) do
			orderIndexById[info.Id] = index
			local tier = tonumber(info.Tier) or index
			qualityTierMap[quality] = qualityTierMap[quality] or {}
			if not qualityTierMap[quality][tier] then
				qualityTierMap[quality][tier] = info
			end
			local maxTier = maxTierByQuality[quality] or 0
			if tier > maxTier then
				maxTierByQuality[quality] = tier
			end
		end
	end
end
buildFigurineIndex()

local function getPlayerState(player)
	local state = playerStates[player.UserId]
	if state then
		return state
	end
	state = {
		Claimed = {},
		ProgressCache = {},
		CountsByQuality = {},
		CountsByRarity = {},
		OwnedByQuality = {},
		Bonuses = {
			MaxPlacedBonus = 0,
			HatchTimeReduction = 0,
			OutputBonus = 0,
			ExtraLuck = 0,
			OfflineCapMinutes = 0,
			MutationBonus = {
				[2] = 0,
				[3] = 0,
				[4] = 0,
				[5] = 0,
			},
		},
		HasClaimable = false,
	}
	playerStates[player.UserId] = state
	return state
end

local function rebuildCounts(state, data)
	state.CountsByQuality = {}
	state.CountsByRarity = {}
	if type(data.CapsuleOpenById) ~= "table" then
		return
	end
	for capsuleId, count in pairs(data.CapsuleOpenById) do
		local info = capsuleInfoById[tonumber(capsuleId) or capsuleId]
		if not info and type(CapsuleConfig.GetById) == "function" then
			info = CapsuleConfig.GetById(tonumber(capsuleId) or capsuleId)
		end
		local amount = tonumber(count) or 0
		if info and amount > 0 then
			local quality = tonumber(info.Quality) or 0
			if quality > 0 then
				state.CountsByQuality[quality] = (state.CountsByQuality[quality] or 0) + amount
			end
			local rarity = tonumber(info.Rarity) or 0
			if rarity > 0 then
				state.CountsByRarity[rarity] = (state.CountsByRarity[rarity] or 0) + amount
			end
		end
	end
end

local function rebuildOwnedByQuality(state, data)
	state.OwnedByQuality = {}
	if type(data.Figurines) ~= "table" then
		return
	end
	for figurineId, owned in pairs(data.Figurines) do
		if owned then
			local info = figurineById[tonumber(figurineId) or figurineId]
			local quality = info and tonumber(info.Quality) or 0
			if quality > 0 then
				state.OwnedByQuality[quality] = (state.OwnedByQuality[quality] or 0) + 1
			end
		end
	end
end

local function normalizePercent(value)
	local num = tonumber(value) or 0
	if num > 1 then
		num = num / 100
	end
	if num < 0 then
		num = 0
	end
	return num
end

local function computeAchievementProgress(player, achievement, state)
	local data = DataService:GetData(player)
	if not data or not achievement then
		return 0, 0, false
	end
	local target = tonumber(achievement.Target) or 0
	local typeId = tonumber(achievement.Type) or 0

	if typeId == ProgressionConfig.AchievementType.PlayTime then
		local totalSeconds = tonumber(data.TotalPlayTime) or 0
		local completed = totalSeconds >= target * 60
		local minutes = math.floor(totalSeconds / 60)
		return minutes, target, completed
	end
	if typeId == ProgressionConfig.AchievementType.TotalOpen then
		local progress = tonumber(data.CapsuleOpenTotal) or 0
		return progress, target, progress >= target
	end
	local quality = ProgressionConfig.AchievementQualityMap[typeId]
	if quality then
		local progress = tonumber(state.CountsByQuality[quality]) or 0
		return progress, target, progress >= target
	end
	local collectQuality = ProgressionConfig.CollectQualityMap[typeId]
	if collectQuality then
		local progress = tonumber(state.OwnedByQuality[collectQuality]) or 0
		return progress, target, progress >= target
	end
	local rarity = ProgressionConfig.AchievementRarityMap[typeId]
	if rarity then
		local progress = tonumber(state.CountsByRarity[rarity]) or 0
		return progress, target, progress >= target
	end
	return 0, target, false
end

local function buildAchievementState(player, achievement, state)
	local progress, target, completed = computeAchievementProgress(player, achievement, state)
	local claimed = state.Claimed and state.Claimed[achievement.Id] == true
	local canClaim = completed and not claimed
	return {
		Id = achievement.Id,
		Progress = progress,
		Target = target,
		Completed = completed,
		Claimed = claimed,
		CanClaim = canClaim,
	}
end

local function isStateChanged(prev, nextState)
	if not prev then
		return true
	end
	if prev.Progress ~= nextState.Progress then
		return true
	end
	if prev.Completed ~= nextState.Completed then
		return true
	end
	if prev.Claimed ~= nextState.Claimed then
		return true
	end
	if prev.CanClaim ~= nextState.CanClaim then
		return true
	end
	return false
end

local function updateHasClaimable(state)
	local hasClaimable = false
	for _, entry in pairs(state.ProgressCache) do
		if entry and entry.CanClaim then
			hasClaimable = true
			break
		end
	end
	state.HasClaimable = hasClaimable
	return hasClaimable
end

local function sendProgressionData(player, entries, isFull, hasClaimable)
	if not pushProgressionDataEvent or not player or not player.Parent then
		return
	end
	pushProgressionDataEvent:FireClient(player, {
		IsFull = isFull == true,
		Entries = entries,
		HasClaimable = hasClaimable == true,
	})
end

local function refreshPlayerProgress(player, state, isFull, filter)
	local updates = {}
	local completionChanged = false

	for _, achievement in ipairs(ProgressionConfig.Achievements) do
		if not filter or filter(achievement) then
			local newState = buildAchievementState(player, achievement, state)
			local prev = state.ProgressCache[achievement.Id]
			if not prev or prev.Completed ~= newState.Completed then
				completionChanged = true
			end
			if isFull or isStateChanged(prev, newState) then
				table.insert(updates, newState)
			end
			state.ProgressCache[achievement.Id] = newState
		end
	end

	local hasClaimable = updateHasClaimable(state)
	if isFull or #updates > 0 then
		sendProgressionData(player, updates, isFull, hasClaimable)
	end
	return completionChanged
end

local function computeBonusesFromCache(state)
	local bonuses = {
		MaxPlacedBonus = 0,
		HatchTimeReduction = 0,
		OutputBonus = 0,
		ExtraLuck = 0,
		OfflineCapMinutes = 0,
		MutationBonus = {
			[2] = 0,
			[3] = 0,
			[4] = 0,
			[5] = 0,
		},
	}

	for _, achievement in ipairs(ProgressionConfig.Achievements) do
		local cache = state.ProgressCache[achievement.Id]
		if cache and cache.Completed then
			local rewardType = tonumber(achievement.RewardType) or 0
			local rawValue = tonumber(achievement.RewardValue) or 0
			if rewardType == ProgressionConfig.RewardType.MaxPlacedCapsules then
				bonuses.MaxPlacedBonus = bonuses.MaxPlacedBonus + math.floor(rawValue)
			elseif rewardType == ProgressionConfig.RewardType.HatchTimeReduction then
				bonuses.HatchTimeReduction = math.max(bonuses.HatchTimeReduction, normalizePercent(rawValue))
			elseif rewardType == ProgressionConfig.RewardType.OutputBonus then
				bonuses.OutputBonus = math.max(bonuses.OutputBonus, normalizePercent(rawValue))
			elseif rewardType == ProgressionConfig.RewardType.ExtraLuck then
				bonuses.ExtraLuck = math.max(bonuses.ExtraLuck, normalizePercent(rawValue))
			elseif rewardType == ProgressionConfig.RewardType.OfflineCapMinutes then
				bonuses.OfflineCapMinutes = math.max(bonuses.OfflineCapMinutes, rawValue)
			elseif rewardType == ProgressionConfig.RewardType.MutationLight then
				bonuses.MutationBonus[2] = math.max(bonuses.MutationBonus[2] or 0, normalizePercent(rawValue))
			elseif rewardType == ProgressionConfig.RewardType.MutationGold then
				bonuses.MutationBonus[3] = math.max(bonuses.MutationBonus[3] or 0, normalizePercent(rawValue))
			elseif rewardType == ProgressionConfig.RewardType.MutationDiamond then
				bonuses.MutationBonus[4] = math.max(bonuses.MutationBonus[4] or 0, normalizePercent(rawValue))
			elseif rewardType == ProgressionConfig.RewardType.MutationRainbow then
				bonuses.MutationBonus[5] = math.max(bonuses.MutationBonus[5] or 0, normalizePercent(rawValue))
			end
		end
	end

	return bonuses
end

local function bonusesEqual(a, b)
	if not a or not b then
		return false
	end
	if a.MaxPlacedBonus ~= b.MaxPlacedBonus then
		return false
	end
	if a.HatchTimeReduction ~= b.HatchTimeReduction then
		return false
	end
	if a.OutputBonus ~= b.OutputBonus then
		return false
	end
	if a.ExtraLuck ~= b.ExtraLuck then
		return false
	end
	if a.OfflineCapMinutes ~= b.OfflineCapMinutes then
		return false
	end
	for rarity = 2, 5 do
		if (a.MutationBonus[rarity] or 0) ~= (b.MutationBonus[rarity] or 0) then
			return false
		end
	end
	return true
end

local function applyBonuses(player, state, bonuses, applyOfflineCap)
	if not bonusesEqual(state.Bonuses, bonuses) then
		state.Bonuses = bonuses
		DataService:SetProgressionOutputBonus(player, bonuses.OutputBonus)
	end
	if applyOfflineCap then
		local base = tonumber(GameConfig.OfflineCapSeconds) or 0
		local bonusMinutes = tonumber(bonuses.OfflineCapMinutes) or 0
		local totalCap = base + bonusMinutes * 60
		if totalCap > 0 then
			DataService:ApplyOfflineCap(player, totalCap)
		end
	end
end

local function getNextFigurineInfo(info)
	if not info then
		return nil
	end
	local quality = tonumber(info.Quality) or 0
	if quality <= 0 then
		return nil
	end
	local tier = tonumber(info.Tier)
	if not tier then
		tier = orderIndexById[info.Id]
	end
	if not tier then
		return nil
	end
	local maxTier = maxTierByQuality[quality] or tier
	if tier >= maxTier then
		return nil
	end
	local nextInfo = qualityTierMap[quality] and qualityTierMap[quality][tier + 1]
	if nextInfo then
		return nextInfo
	end
	local list = orderByQuality[quality]
	local index = orderIndexById[info.Id]
	if list and index and list[index + 1] then
		return list[index + 1]
	end
	return nil
end

function ProgressionService:BindPlayer(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	local state = getPlayerState(player)
	state.Claimed = DataService:GetProgressionClaimed(player)
	rebuildCounts(state, data)
	rebuildOwnedByQuality(state, data)

	refreshPlayerProgress(player, state, true)
	local bonuses = computeBonusesFromCache(state)
	applyBonuses(player, state, bonuses, true)
end

function ProgressionService:UnbindPlayer(player)
	playerStates[player.UserId] = nil
end

function ProgressionService:HandleCapsuleOpened(player, capsuleInfo)
	if not player or not capsuleInfo then
		return
	end
	local state = getPlayerState(player)
	local quality = tonumber(capsuleInfo.Quality) or 0
	if quality > 0 then
		state.CountsByQuality[quality] = (state.CountsByQuality[quality] or 0) + 1
	end
	local rarity = tonumber(capsuleInfo.Rarity) or 0
	if rarity > 0 then
		state.CountsByRarity[rarity] = (state.CountsByRarity[rarity] or 0) + 1
	end
	local completionChanged = refreshPlayerProgress(player, state, false, function(achievement)
		local typeId = tonumber(achievement.Type) or 0
		return typeId == ProgressionConfig.AchievementType.TotalOpen
			or ProgressionConfig.AchievementQualityMap[typeId]
			or ProgressionConfig.AchievementRarityMap[typeId]
	end)
	if completionChanged then
		local bonuses = computeBonusesFromCache(state)
		applyBonuses(player, state, bonuses, false)
	end
end

function ProgressionService:HandleFigurineUnlocked(player, figurineInfo)
	if not player or not figurineInfo then
		return
	end
	local state = getPlayerState(player)
	local quality = tonumber(figurineInfo.Quality) or 0
	if quality > 0 then
		state.OwnedByQuality[quality] = (state.OwnedByQuality[quality] or 0) + 1
	end
	local completionChanged = refreshPlayerProgress(player, state, false, function(achievement)
		local typeId = tonumber(achievement.Type) or 0
		return ProgressionConfig.CollectQualityMap[typeId] ~= nil
	end)
	if completionChanged then
		local bonuses = computeBonusesFromCache(state)
		applyBonuses(player, state, bonuses, false)
	end
end

function ProgressionService:HandlePlaytimeUpdated(player)
	if not player then
		return
	end
	local state = getPlayerState(player)
	local completionChanged = refreshPlayerProgress(player, state, false, function(achievement)
		local typeId = tonumber(achievement.Type) or 0
		return typeId == ProgressionConfig.AchievementType.PlayTime
	end)
	if completionChanged then
		local bonuses = computeBonusesFromCache(state)
		applyBonuses(player, state, bonuses, false)
	end
end

function ProgressionService:ClaimAchievement(player, achievementId)
	if not player or not player.Parent then
		return
	end
	local id = tonumber(achievementId) or achievementId
	if not id then
		return
	end
	local achievement = ProgressionConfig.GetById(id)
	if not achievement then
		return
	end
	local state = getPlayerState(player)
	if state.Claimed and state.Claimed[id] then
		return
	end
	local progress, target, completed = computeAchievementProgress(player, achievement, state)
	if not completed then
		return
	end

	DataService:SetAchievementClaimed(player, id, true)
	state.Claimed = DataService:GetProgressionClaimed(player)
	local reward = tonumber(achievement.DiamondReward) or 0
	if reward > 0 then
		DataService:AddDiamonds(player, reward)
	end

	local completionChanged = refreshPlayerProgress(player, state, false, function(entry)
		return entry.Id == id
	end)
	if completionChanged then
		local bonuses = computeBonusesFromCache(state)
		applyBonuses(player, state, bonuses, false)
	end

	if pushProgressionClaimedEvent and reward > 0 then
		local totalDiamonds = DataService:GetDiamonds(player)
		pushProgressionClaimedEvent:FireClient(player, id, reward, totalDiamonds)
	end
end

function ProgressionService:GetMaxPlacedCapsules(player)
	local state = playerStates[player.UserId]
	local base = tonumber(GameConfig.MaxPlacedCapsules) or 0
	local bonus = state and state.Bonuses and tonumber(state.Bonuses.MaxPlacedBonus) or 0
	return base + math.max(0, bonus)
end

function ProgressionService:GetHatchTimeReduction(player)
	local state = playerStates[player.UserId]
	local reduction = state and state.Bonuses and tonumber(state.Bonuses.HatchTimeReduction) or 0
	if reduction < 0 then
		reduction = 0
	end
	if reduction > 1 then
		reduction = 1
	end
	return reduction
end

function ProgressionService:GetExtraLuckChance(player)
	local state = playerStates[player.UserId]
	local luck = state and state.Bonuses and tonumber(state.Bonuses.ExtraLuck) or 0
	if luck < 0 then
		luck = 0
	end
	if luck > 1 then
		luck = 1
	end
	return luck
end

function ProgressionService:GetRarityUpgradeChance(player, rarity)
	local state = playerStates[player.UserId]
	if not state or not state.Bonuses then
		return 0
	end
	local baseRarity = tonumber(rarity) or 0
	if baseRarity <= 0 or baseRarity >= 5 then
		return 0
	end
	local chance = state.Bonuses.MutationBonus[baseRarity + 1] or 0
	if chance < 0 then
		chance = 0
	end
	if chance > 1 then
		chance = 1
	end
	return chance
end

function ProgressionService:ApplyExtraLuck(player, figurineId)
	local chance = self:GetExtraLuckChance(player)
	if chance <= 0 then
		return figurineId
	end
	local info = figurineById[tonumber(figurineId) or figurineId]
	if not info then
		return figurineId
	end
	local nextInfo = getNextFigurineInfo(info)
	if not nextInfo then
		return figurineId
	end
	if rng:NextNumber() <= chance then
		return nextInfo.Id
	end
	return figurineId
end

function ProgressionService:Init()
	if initDone then
		return
	end
	initDone = true

	if requestProgressionDataEvent then
		requestProgressionDataEvent.OnServerEvent:Connect(function(player)
			if not player or not player.Parent then
				return
			end
			local state = getPlayerState(player)
			refreshPlayerProgress(player, state, true)
		end)
	end

	if requestProgressionClaimEvent then
		requestProgressionClaimEvent.OnServerEvent:Connect(function(player, achievementId)
			self:ClaimAchievement(player, achievementId)
		end)
	end

	DataService:RegisterPlaytimeListener(function(player)
		self:HandlePlaytimeUpdated(player)
	end)
end

return ProgressionService
