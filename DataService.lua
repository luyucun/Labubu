--[[
脚本名称: DataService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/DataService
版本: V2.0
职责: 数据加载/保存与金币与手办管理与统计与升级
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local FigurineConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FigurineConfig"))
local FigurineRateConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FigurineRateConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UpgradeConfig"))
local PotionConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PotionConfig"))

local DataService = {}
DataService.__index = DataService

local store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
local sessionData = {} -- [userId] = {Data = table, Dirty = bool, LastSave = number}
local playtimeListeners = {}
local autoSaveStarted = false
local PLAYTIME_UPDATE_INTERVAL = 1
local LOAD_RETRY_COUNT = 3
local LOAD_RETRY_BASE_DELAY = 1.0

local function fetchPlayerData(key)
	local lastErr
	for attempt = 1, LOAD_RETRY_COUNT do
		local success, result = pcall(function()
			return store:GetAsync(key)
		end)
		if success then
			if result == nil or type(result) == "table" then
				return true, result, nil, nil
			end
			return false, nil, "corrupt", result
		end
		lastErr = result
		task.wait(LOAD_RETRY_BASE_DELAY * attempt)
	end
	return false, nil, "error", lastErr
end

local function defaultData()
	return {
		Coins = GameConfig.StartCoins,
		Diamonds = 0,
		Figurines = {},
		FigurineStates = {},
		Eggs = {},
		PlacedEggs = {},
		TotalPlayTime = 0,
		CapsuleOpenTotal = 0,
		CapsuleOpenById = {},
		OutputSpeed = 0,
		OutputMultiplier = 1,
		AutoCollect = false,
		MusicEnabled = true,
		SfxEnabled = true,
		ProgressionClaimed = {},
		PotionCounts = {},
		PotionEndTimes = {},
		LastLogoutTime = 0,
		GuideStep = 1,
		StarterPackPurchased = false,
		GroupRewardClaimed = false,
	}
end

local function normalizeFigurines(figurines)
	if type(figurines) ~= "table" then
		return {}
	end

	local normalized = {}
	for key, value in pairs(figurines) do
		if type(value) == "boolean" then
			local id = tonumber(key) or key
			if id then
				normalized[id] = value
			end
		elseif type(value) == "number" then
			local id = tonumber(value)
			if id then
				normalized[id] = true
			end
		end
	end

	return normalized
end

local function normalizeRarity(value)
	local num = tonumber(value)
	if not num then
		return 1
	end
	num = math.floor(num)
	if num < 1 then
		return 1
	end
	local maxRarity = FigurineRateConfig.GetMaxRarity()
	if num > maxRarity then
		return maxRarity
	end
	return num
end

local function normalizeFigurineStates(states)
	if type(states) ~= "table" then
		return {}
	end

	local normalized = {}
	for key, value in pairs(states) do
		local id = tonumber(key) or key
		if id then
			local baseInfo = FigurineConfig.GetById(id)
			local defaultRarity = normalizeRarity(baseInfo and baseInfo.Rarity or 1)
			if type(value) == "table" then
				local state = {}
				for k, v in pairs(value) do
					state[k] = v
				end
				if state.LastCollectTime == nil and state.LastClaimTime ~= nil then
					state.LastCollectTime = tonumber(state.LastClaimTime)
				end
				local level = tonumber(state.Level)
				if not level or level < 1 then
					level = 1
				end
				level = math.floor(level)
				local maxLevel = UpgradeConfig.GetMaxLevel()
				if level > maxLevel then
					level = maxLevel
				end
				state.Level = level
				if state.Exp == nil then
					state.Exp = 0
				else
					local exp = tonumber(state.Exp)
					if not exp or exp < 0 then
						exp = 0
					end
					state.Exp = math.floor(exp)
				end
				if state.Rarity == nil then
					state.Rarity = defaultRarity
				else
					state.Rarity = normalizeRarity(state.Rarity)
				end
				normalized[id] = state
			elseif type(value) == "number" then
				normalized[id] = { LastCollectTime = value, Level = 1, Exp = 0, Rarity = defaultRarity }
			end
		end
	end

	return normalized
end

local function normalizeEggs(eggs)
	if type(eggs) ~= "table" then
		return {}, true
	end

	local normalized = {}
	local changed = false

	local function addEntry(eggId, uid)
		local id = tonumber(eggId)
		if not id then
			changed = true
			return
		end
		local finalUid = uid
		if type(finalUid) ~= "string" or finalUid == "" then
			finalUid = HttpService:GenerateGUID(false)
			changed = true
		end
		if id ~= eggId or finalUid ~= uid then
			changed = true
		end
		table.insert(normalized, { Uid = finalUid, EggId = id })
	end

	local usedKeys = {}
	if #eggs > 0 then
		for index, value in ipairs(eggs) do
			usedKeys[index] = true
			if type(value) == "table" then
				addEntry(value.EggId or value.Id or value.eggId, value.Uid or value.uid)
			elseif type(value) == "number" or tonumber(value) then
				addEntry(value, nil)
			else
				changed = true
			end
		end
	end

	for key, value in pairs(eggs) do
		if not usedKeys[key] then
			if type(value) == "table" then
				local uid = value.Uid or value.uid or (type(key) == "string" and key or nil)
				addEntry(value.EggId or value.Id or value.eggId, uid)
			elseif type(value) == "number" or tonumber(value) then
				local uid = type(key) == "string" and key or nil
				addEntry(value, uid)
			else
				changed = true
			end
		end
	end

	return normalized, changed
end

local function normalizeCount(value)
	local num = tonumber(value)
	if not num or num < 0 then
		return 0
	end
	return math.floor(num)
end

local function normalizeDiamonds(value)
	local num = tonumber(value)
	if not num or num < 0 then
		return 0
	end
	return math.floor(num)
end

local function normalizeStarterPackPurchased(value)
	return value == true
end

local function normalizeGroupRewardClaimed(value)
	return value == true
end

local function normalizeGuideStep(value)
	local num = tonumber(value)
	if not num then
		return 1
	end
	num = math.floor(num)
	if num < 0 then
		return 0
	end
	if num > 5 then
		return 5
	end
	return num
end

local function normalizeProgressionClaimed(value)
	if type(value) ~= "table" then
		return {}
	end
	local normalized = {}
	for key, claimed in pairs(value) do
		local id = tonumber(key) or key
		if id and claimed == true then
			normalized[id] = true
		end
	end
	return normalized
end

local function normalizePotionCounts(value)
	local changed = false
	local source = value
	if type(source) ~= "table" then
		source = {}
		changed = true
	end

	local normalized = {}
	for _, info in ipairs(PotionConfig.GetAll()) do
		if info and info.Id then
			local id = tonumber(info.Id) or info.Id
			local raw = source[id]
			if raw == nil then
				raw = source[tostring(id)]
			end
			local count = normalizeCount(raw)
			if raw ~= nil and count ~= raw then
				changed = true
			end
			normalized[id] = count
		end
	end

	for key, _ in pairs(source) do
		local id = tonumber(key) or key
		if id and not PotionConfig.GetById(id) then
			changed = true
			break
		end
	end

	return normalized, changed
end

local function normalizePotionEndTimes(value)
	local changed = false
	local source = value
	if type(source) ~= "table" then
		source = {}
		changed = true
	end

	local normalized = {}
	for _, info in ipairs(PotionConfig.GetAll()) do
		if info and info.Id then
			local id = tonumber(info.Id) or info.Id
			local raw = source[id]
			if raw == nil then
				raw = source[tostring(id)]
			end
			local timeValue = tonumber(raw) or 0
			if timeValue < 0 then
				timeValue = 0
			end
			timeValue = math.floor(timeValue)
			if raw ~= nil and timeValue ~= raw then
				changed = true
			end
			normalized[id] = timeValue
		end
	end

	for key, _ in pairs(source) do
		local id = tonumber(key) or key
		if id and not PotionConfig.GetById(id) then
			changed = true
			break
		end
	end

	return normalized, changed
end

local function normalizeLogoutTime(value)
	local num = tonumber(value)
	if not num or num < 0 then
		return 0
	end
	return math.floor(num)
end

local function normalizeOutputSpeed(value)
	local num = tonumber(value)
	if not num or num < 0 then
		return 0
	end
	return num
end

local function normalizeOutputMultiplier(value)
	local num = tonumber(value)
	if not num or num < 1 then
		return 1
	end
	return math.floor(num)
end

local function normalizeLevel(value)
	local num = tonumber(value)
	if not num or num < 1 then
		return 1
	end
	return math.floor(num)
end

local function normalizeExp(value)
	local num = tonumber(value)
	if not num or num < 0 then
		return 0
	end
	return math.floor(num)
end

local function calculateFigurineRate(figurineInfo, state)
	if not figurineInfo then
		return 0
	end
	local baseRate = tonumber(figurineInfo.BaseRate) or 0
	if baseRate <= 0 then
		return 0
	end
	local level = normalizeLevel(state and state.Level)
	local rarity = normalizeRarity((state and state.Rarity) or figurineInfo.Rarity)
	local quality = tonumber(figurineInfo.Quality) or 1
	local qualityCoeff = FigurineRateConfig.GetQualityCoeff(quality)
	local rarityCoeff = FigurineRateConfig.GetRarityCoeff(rarity)
	local baseValue = baseRate * rarityCoeff
	if baseValue <= 0 then
		return 0
	end
	if level <= 1 then
		return baseValue
	end
	local perLevel = baseValue * qualityCoeff
	if perLevel > 0 and perLevel < 1 then
		perLevel = 1
	end
	local upgradeDelta = perLevel * (level - 1)
	local rate = baseValue + upgradeDelta
	if rate < 0 then
		rate = 0
	end
	return rate
end

local function normalizeCapsuleOpenById(stats)
	if type(stats) ~= "table" then
		return {}, 0, true
	end

	local normalized = {}
	local total = 0
	local changed = false

	for key, value in pairs(stats) do
		local id = tonumber(key) or key
		local count = normalizeCount(value)
		if id and count > 0 then
			normalized[id] = count
			total += count
			if id ~= key or count ~= value then
				changed = true
			end
		else
			changed = true
		end
	end

	return normalized, total, changed
end

local function calculateOutputSpeed(figurines, figurineStates, bonusAdd)
	if type(figurines) ~= "table" then
		return 0
	end
	local total = 0
	for figurineId, owned in pairs(figurines) do
		if owned then
			local info = FigurineConfig.GetById(tonumber(figurineId) or figurineId)
			if info then
				local state = figurineStates and figurineStates[tonumber(figurineId) or figurineId]
				local rate = calculateFigurineRate(info, state)
				if rate > 0 then
					total += rate
				end
			end
		end
	end
	local bonusFactor = 1 + (tonumber(bonusAdd) or 0)
	if bonusFactor < 0 then
		bonusFactor = 0
	end
	return total * bonusFactor
end

local function normalizeBonusAdd(value)
	local num = tonumber(value) or 0
	if num < 0 then
		return 0
	end
	return num
end

local function getPurchaseBonusAdd(multiplier)
	local normalized = normalizeOutputMultiplier(multiplier)
	local add = normalized - 1
	if add < 0 then
		add = 0
	end
	return add
end

local function getPotionBonusFromEndTimes(endTimes, now)
	if type(endTimes) ~= "table" then
		return 0
	end
	local total = 0
	local timestamp = now or os.time()
	for _, info in ipairs(PotionConfig.GetAll()) do
		if info and info.Id then
			local endTime = tonumber(endTimes[info.Id]) or tonumber(endTimes[tostring(info.Id)]) or 0
			if endTime > timestamp then
				local bonus = tonumber(info.Bonus) or 0
				if bonus > 0 then
					total += bonus
				end
			end
		end
	end
	return normalizeBonusAdd(total)
end

local function getTotalBonusAddFromData(data, progressionBonus, now)
	if not data then
		return normalizeBonusAdd(progressionBonus)
	end
	local total = normalizeBonusAdd(progressionBonus)
	total += getPurchaseBonusAdd(data.OutputMultiplier)
	total += getPotionBonusFromEndTimes(data.PotionEndTimes, now)
	return normalizeBonusAdd(total)
end

local function adjustCollectTimesForOutputBonusChange(player, oldFactor, newFactor)
	if not player or oldFactor == newFactor then
		return
	end
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	local figurines = record.Data.Figurines
	if type(figurines) ~= "table" then
		return
	end
	local now = os.time()
	local capSeconds = tonumber(GameConfig.FigurineCoinCapSeconds) or 0
	for figurineId, owned in pairs(figurines) do
		if owned then
			local info = FigurineConfig.GetById(tonumber(figurineId) or figurineId)
			if info then
				local state = DataService:EnsureFigurineState(player, figurineId)
				local lastCollect = tonumber(state and state.LastCollectTime) or now
				local elapsed = math.max(0, now - lastCollect)
				if capSeconds > 0 then
					elapsed = math.min(elapsed, capSeconds)
				end
				local baseRate = calculateFigurineRate(info, state)
				if baseRate > 0 then
					local oldRate = baseRate * oldFactor
					local newRate = baseRate * newFactor
					if newRate > 0 then
						local pending = oldRate * elapsed
						local targetElapsed = pending / newRate
						if capSeconds > 0 then
							targetElapsed = math.min(targetElapsed, capSeconds)
						end
						local newLastCollect = now - targetElapsed
						DataService:SetFigurineLastCollectTime(player, figurineId, newLastCollect)
					end
				end
			end
		end
	end
end

function DataService:CalculateFigurineRate(figurineInfo, state)
	return calculateFigurineRate(figurineInfo, state)
end

local function applyLevelExp(level, exp)
	local maxLevel = UpgradeConfig.GetMaxLevel()
	local currentLevel = normalizeLevel(level)
	local currentExp = normalizeExp(exp)
	local leveledUp = false
	if currentLevel >= maxLevel then
		return maxLevel, currentExp, false, true
	end
	while currentLevel < maxLevel do
		local required = UpgradeConfig.GetRequiredExp(currentLevel)
		if not required or required <= 0 then
			break
		end
		if currentExp < required then
			break
		end
		currentExp -= required
		currentLevel += 1
		leveledUp = true
	end
	local isMax = currentLevel >= maxLevel
	if isMax then
		currentLevel = maxLevel
	end
	return currentLevel, currentExp, leveledUp, isMax
end

local function applyCoinsAttribute(player, coins)
	if player and player.Parent then
		player:SetAttribute("Coins", coins)
	end
end

local function applyDiamondsAttribute(player, diamonds)
	if player and player.Parent then
		player:SetAttribute("Diamonds", diamonds)
	end
end

local function applyStatsAttributes(player, data)
	if not player or not player.Parent then
		return
	end
	player:SetAttribute("TotalPlayTime", normalizeCount(data.TotalPlayTime))
	player:SetAttribute("CapsuleOpenTotal", normalizeCount(data.CapsuleOpenTotal))
	player:SetAttribute("OutputSpeed", normalizeOutputSpeed(data.OutputSpeed))
	player:SetAttribute("OutputMultiplier", normalizeOutputMultiplier(data.OutputMultiplier))
	player:SetAttribute("AutoCollect", data.AutoCollect == true)
	player:SetAttribute("MusicEnabled", data.MusicEnabled == true)
	player:SetAttribute("SfxEnabled", data.SfxEnabled == true)
	player:SetAttribute("Diamonds", normalizeDiamonds(data.Diamonds))
	player:SetAttribute("GuideStep", normalizeGuideStep(data.GuideStep))
	player:SetAttribute("StarterPackPurchased", normalizeStarterPackPurchased(data.StarterPackPurchased))
	player:SetAttribute("GroupRewardClaimed", normalizeGroupRewardClaimed(data.GroupRewardClaimed))
end

local function ensureFigurineOwnedFolder(player)
	if not player or not player.Parent then
		return nil
	end
	local folder = player:FindFirstChild("FigurineOwned")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "FigurineOwned"
		folder.Parent = player
	end
	return folder
end

local function setFigurineOwnedValue(player, figurineId, owned)
	local folder = ensureFigurineOwnedFolder(player)
	if not folder then
		return
	end
	local name = tostring(figurineId)
	local value = folder:FindFirstChild(name)
	if owned then
		if not value then
			value = Instance.new("BoolValue")
			value.Name = name
			value.Parent = folder
		end
		value.Value = true
	else
		if value then
			value:Destroy()
		end
	end
end

local function syncFigurineOwnedFolder(player, figurines)
	local folder = ensureFigurineOwnedFolder(player)
	if not folder then
		return
	end
	local keep = {}
	if type(figurines) == "table" then
		for id, owned in pairs(figurines) do
			if owned then
				keep[tostring(id)] = true
			end
		end
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BoolValue") and not keep[child.Name] then
			child:Destroy()
		end
	end
	if type(figurines) == "table" then
		for id, owned in pairs(figurines) do
			if owned then
				setFigurineOwnedValue(player, id, true)
			end
		end
	end
end

local function updatePlaytimeRecord(record, player)
	if not record then
		return
	end
	local now = os.time()
	local last = record.LastPlaytimeUpdate or now
	if now <= last then
		record.LastPlaytimeUpdate = now
		return
	end
	local delta = now - last
	record.LastPlaytimeUpdate = now
	local total = normalizeCount(record.Data.TotalPlayTime) + delta
	record.Data.TotalPlayTime = total
	record.Dirty = true
	if player and player.Parent then
		player:SetAttribute("TotalPlayTime", total)
	end
	if #playtimeListeners > 0 and player and player.Parent then
		for _, callback in ipairs(playtimeListeners) do
			local ok, err = pcall(callback, player, total)
			if not ok then
				warn(string.format("[DataService] Playtime listener error: %s", tostring(err)))
			end
		end
	end
end

function DataService:LoadPlayer(player)
	local userId = player.UserId
	local key = tostring(userId)
	local data
	local success, result, errType, errDetail = fetchPlayerData(key)
	if not success then
		warn(string.format("[DataService] Load failed: userId=%s type=%s err=%s", key, tostring(errType), tostring(errDetail)))
		return nil, errType, errDetail
	end

	if result == nil then
		data = defaultData()
	else
		data = result
	end

	local needsSave = result == nil

	if data.Coins == nil then
		data.Coins = GameConfig.StartCoins
		needsSave = true
	end
	if data.Diamonds == nil then
		data.Diamonds = 0
		needsSave = true
	else
		local normalizedDiamonds = normalizeDiamonds(data.Diamonds)
		if data.Diamonds ~= normalizedDiamonds then
			data.Diamonds = normalizedDiamonds
			needsSave = true
		end
	end
	if type(data.Figurines) ~= "table" then
		data.Figurines = {}
		needsSave = true
	end
	data.Figurines = normalizeFigurines(data.Figurines)
	if type(data.FigurineStates) ~= "table" then
		data.FigurineStates = {}
		needsSave = true
	end
	data.FigurineStates = normalizeFigurineStates(data.FigurineStates)
	local normalizedEggs, eggsChanged = normalizeEggs(data.Eggs)
	data.Eggs = normalizedEggs
	if eggsChanged then
		needsSave = true
	end
	if type(data.PlacedEggs) ~= "table" then
		data.PlacedEggs = {}
		needsSave = true
	end

	if data.AutoCollect == nil then
		data.AutoCollect = false
		needsSave = true
	else
		data.AutoCollect = data.AutoCollect == true
	end

	if data.MusicEnabled == nil then
		data.MusicEnabled = true
		needsSave = true
	else
		data.MusicEnabled = data.MusicEnabled == true
	end

	if data.SfxEnabled == nil then
		data.SfxEnabled = true
		needsSave = true
	else
		data.SfxEnabled = data.SfxEnabled == true
	end

	if data.OutputMultiplier == nil then
		data.OutputMultiplier = 1
		needsSave = true
	else
		local normalizedMultiplier = normalizeOutputMultiplier(data.OutputMultiplier)
		if data.OutputMultiplier ~= normalizedMultiplier then
			data.OutputMultiplier = normalizedMultiplier
			needsSave = true
		end
	end

	if type(data.ProgressionClaimed) ~= "table" then
		data.ProgressionClaimed = {}
		needsSave = true
	else
		data.ProgressionClaimed = normalizeProgressionClaimed(data.ProgressionClaimed)
	end

	local normalizedPotionCounts, potionCountsChanged = normalizePotionCounts(data.PotionCounts)
	data.PotionCounts = normalizedPotionCounts
	if potionCountsChanged then
		needsSave = true
	end

	local normalizedPotionEndTimes, potionEndTimesChanged = normalizePotionEndTimes(data.PotionEndTimes)
	data.PotionEndTimes = normalizedPotionEndTimes
	if potionEndTimesChanged then
		needsSave = true
	end

	if data.LastLogoutTime == nil then
		data.LastLogoutTime = 0
		needsSave = true
	else
		local normalizedLogout = normalizeLogoutTime(data.LastLogoutTime)
		if data.LastLogoutTime ~= normalizedLogout then
			data.LastLogoutTime = normalizedLogout
			needsSave = true
		end
	end

	if data.GuideStep == nil then
		data.GuideStep = 1
		needsSave = true
	else
		local normalizedGuideStep = normalizeGuideStep(data.GuideStep)
		if data.GuideStep ~= normalizedGuideStep then
			data.GuideStep = normalizedGuideStep
			needsSave = true
		end
	end

	if data.StarterPackPurchased == nil then
		data.StarterPackPurchased = false
		needsSave = true
	else
		local normalizedStarterPack = normalizeStarterPackPurchased(data.StarterPackPurchased)
		if data.StarterPackPurchased ~= normalizedStarterPack then
			data.StarterPackPurchased = normalizedStarterPack
			needsSave = true
		end
	end

	if data.GroupRewardClaimed == nil then
		data.GroupRewardClaimed = false
		needsSave = true
	else
		local normalizedGroupReward = normalizeGroupRewardClaimed(data.GroupRewardClaimed)
		if data.GroupRewardClaimed ~= normalizedGroupReward then
			data.GroupRewardClaimed = normalizedGroupReward
			needsSave = true
		end
	end


	local normalizedPlaytime = normalizeCount(data.TotalPlayTime)
	if data.TotalPlayTime ~= normalizedPlaytime then
		data.TotalPlayTime = normalizedPlaytime
		needsSave = true
	end

	local normalizedCapsuleTotal = normalizeCount(data.CapsuleOpenTotal)
	if data.CapsuleOpenTotal ~= normalizedCapsuleTotal then
		data.CapsuleOpenTotal = normalizedCapsuleTotal
		needsSave = true
	end

	local normalizedById, totalById, changedById = normalizeCapsuleOpenById(data.CapsuleOpenById)
	if changedById then
		data.CapsuleOpenById = normalizedById
		needsSave = true
	end
	if data.CapsuleOpenTotal < totalById then
		data.CapsuleOpenTotal = totalById
		needsSave = true
	end

	local totalBonusAdd = getTotalBonusAddFromData(data, 0, os.time())
	local recalculatedSpeed = calculateOutputSpeed(data.Figurines, data.FigurineStates, totalBonusAdd)
	local normalizedSpeed = normalizeOutputSpeed(data.OutputSpeed)
	if normalizedSpeed ~= recalculatedSpeed then
		data.OutputSpeed = recalculatedSpeed
		needsSave = true
	else
		data.OutputSpeed = normalizedSpeed
	end

	sessionData[userId] = {
		Data = data,
		Dirty = needsSave,
		LastSave = os.clock(),
		ProgressionOutputBonus = 0,
		PlaytimeActive = true,
		LastPlaytimeUpdate = os.time(),
		PlaytimeLoop = false,
		DataVersion = 1,
	}

	self:RefreshAllFigurineStates(player)
	self:RecalculateOutputSpeed(player)

	applyCoinsAttribute(player, data.Coins)
	applyStatsAttributes(player, data)
	syncFigurineOwnedFolder(player, data.Figurines)
	self:StartPlaytimeTracker(player)

	return data
end

function DataService:GetData(player)
	local record = sessionData[player.UserId]
	return record and record.Data or nil
end

function DataService:GetCoins(player)
	local record = sessionData[player.UserId]
	return record and record.Data.Coins or 0
end

function DataService:GetDiamonds(player)
	local record = sessionData[player.UserId]
	return record and record.Data.Diamonds or 0
end

function DataService:GetGuideStep(player)
	local record = sessionData[player.UserId]
	return record and normalizeGuideStep(record.Data.GuideStep) or 0
end

function DataService:SetGuideStep(player, step)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	local normalized = normalizeGuideStep(step)
	if record.Data.GuideStep == normalized then
		return
	end
	record.Data.GuideStep = normalized
	record.Dirty = true
	if player and player.Parent then
		player:SetAttribute("GuideStep", normalized)
	end
end

function DataService:HasStarterPackPurchased(player)
	local record = sessionData[player.UserId]
	return record and record.Data.StarterPackPurchased == true
end

function DataService:SetStarterPackPurchased(player, purchased)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	local normalized = normalizeStarterPackPurchased(purchased)
	if record.Data.StarterPackPurchased == normalized then
		return
	end
	record.Data.StarterPackPurchased = normalized
	record.Dirty = true
	if player and player.Parent then
		player:SetAttribute("StarterPackPurchased", normalized)
	end
end

function DataService:HasGroupRewardClaimed(player)
	local record = sessionData[player.UserId]
	return record and record.Data.GroupRewardClaimed == true
end

function DataService:SetGroupRewardClaimed(player, claimed)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	local normalized = normalizeGroupRewardClaimed(claimed)
	if record.Data.GroupRewardClaimed == normalized then
		return
	end
	record.Data.GroupRewardClaimed = normalized
	record.Dirty = true
	if player and player.Parent then
		player:SetAttribute("GroupRewardClaimed", normalized)
	end
end

function DataService:GetProgressionClaimed(player)
	local record = sessionData[player.UserId]
	if not record then
		return {}
	end
	if type(record.Data.ProgressionClaimed) ~= "table" then
		record.Data.ProgressionClaimed = {}
	end
	return record.Data.ProgressionClaimed
end

function DataService:IsAchievementClaimed(player, achievementId)
	local record = sessionData[player.UserId]
	if not record then
		return false
	end
	local id = tonumber(achievementId) or achievementId
	if not id then
		return false
	end
	if type(record.Data.ProgressionClaimed) ~= "table" then
		return false
	end
	return record.Data.ProgressionClaimed[id] == true
end

function DataService:SetAchievementClaimed(player, achievementId, claimed)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	if type(record.Data.ProgressionClaimed) ~= "table" then
		record.Data.ProgressionClaimed = {}
	end
	local id = tonumber(achievementId) or achievementId
	if not id then
		return
	end
	if claimed then
		record.Data.ProgressionClaimed[id] = true
	else
		record.Data.ProgressionClaimed[id] = nil
	end
	record.Dirty = true
end

function DataService:GetOutputMultiplier(player)
	local record = sessionData[player.UserId]
	if not record then
		return 1
	end
	return normalizeOutputMultiplier(record.Data.OutputMultiplier)
end

function DataService:GetFigurines(player)
	local record = sessionData[player.UserId]
	return record and record.Data.Figurines or nil
end

function DataService:GetFigurineStates(player)
	local record = sessionData[player.UserId]
	return record and record.Data.FigurineStates or nil
end

function DataService:GetFigurineRate(player, figurineId)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	local id = tonumber(figurineId) or figurineId
	local info = FigurineConfig.GetById(id)
	if not info then
		return 0
	end
	local state = record.Data.FigurineStates and record.Data.FigurineStates[id]
	return calculateFigurineRate(info, state)
end

function DataService:GetEggs(player)
	local record = sessionData[player.UserId]
	return record and record.Data.Eggs or nil
end

function DataService:GetPlacedEggs(player)
	local record = sessionData[player.UserId]
	return record and record.Data.PlacedEggs or nil
end

function DataService:HasAutoCollect(player)
	local record = sessionData[player.UserId]
	return record and record.Data.AutoCollect == true
end

function DataService:SetAutoCollect(player, enabled)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	record.Data.AutoCollect = enabled == true
	record.Dirty = true
	if player and player.Parent then
		player:SetAttribute("AutoCollect", record.Data.AutoCollect)
	end
end

function DataService:RegisterPlaytimeListener(callback)
	if type(callback) ~= "function" then
		return
	end
	table.insert(playtimeListeners, callback)
end

function DataService:SetAudioSettings(player, musicEnabled, sfxEnabled)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	local dirty = false
	if musicEnabled ~= nil then
		record.Data.MusicEnabled = musicEnabled == true
		dirty = true
	end
	if sfxEnabled ~= nil then
		record.Data.SfxEnabled = sfxEnabled == true
		dirty = true
	end
	if not dirty then
		return
	end
	record.Dirty = true
	if player and player.Parent then
		if musicEnabled ~= nil then
			player:SetAttribute("MusicEnabled", record.Data.MusicEnabled)
		end
		if sfxEnabled ~= nil then
			player:SetAttribute("SfxEnabled", record.Data.SfxEnabled)
		end
	end
end

function DataService:SetOutputMultiplier(player, multiplier)
	local record = sessionData[player.UserId]
	if not record then
		return 1
	end
	local normalized = normalizeOutputMultiplier(multiplier)
	local current = normalizeOutputMultiplier(record.Data.OutputMultiplier)
	if normalized == current then
		if player and player.Parent then
			player:SetAttribute("OutputMultiplier", current)
		end
		return current
	end
	local oldFactor = self:GetOutputBonusFactor(player)
	record.Data.OutputMultiplier = normalized
	local newFactor = self:GetOutputBonusFactor(player)
	adjustCollectTimesForOutputBonusChange(player, oldFactor, newFactor)
	record.Dirty = true
	if player and player.Parent then
		player:SetAttribute("OutputMultiplier", normalized)
	end
	self:RecalculateOutputSpeed(player)
	return normalized
end

function DataService:GetProgressionOutputBonus(player)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	return tonumber(record.ProgressionOutputBonus) or 0
end

function DataService:SetProgressionOutputBonus(player, bonus)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	local normalized = tonumber(bonus) or 0
	if normalized < 0 then
		normalized = 0
	end
	if record.ProgressionOutputBonus == normalized then
		return normalized
	end
	local oldFactor = self:GetOutputBonusFactor(player)
	record.ProgressionOutputBonus = normalized
	local newFactor = self:GetOutputBonusFactor(player)
	adjustCollectTimesForOutputBonusChange(player, oldFactor, newFactor)
	self:RecalculateOutputSpeed(player)
	return normalized
end

function DataService:GetPotionCounts(player)
	local record = sessionData[player.UserId]
	return record and record.Data.PotionCounts or nil
end

function DataService:GetPotionEndTimes(player)
	local record = sessionData[player.UserId]
	return record and record.Data.PotionEndTimes or nil
end

function DataService:GetPotionCount(player, potionId)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	if type(record.Data.PotionCounts) ~= "table" then
		record.Data.PotionCounts = {}
	end
	local id = tonumber(potionId) or potionId
	local value = record.Data.PotionCounts[id] or record.Data.PotionCounts[tostring(id)] or 0
	return normalizeCount(value)
end

function DataService:GetPotionEndTime(player, potionId)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	if type(record.Data.PotionEndTimes) ~= "table" then
		record.Data.PotionEndTimes = {}
	end
	local id = tonumber(potionId) or potionId
	local value = record.Data.PotionEndTimes[id] or record.Data.PotionEndTimes[tostring(id)] or 0
	local timeValue = tonumber(value) or 0
	if timeValue < 0 then
		timeValue = 0
	end
	return math.floor(timeValue)
end

function DataService:GetPotionRemainingSeconds(player, potionId, now)
	local endTime = self:GetPotionEndTime(player, potionId)
	local timestamp = now or os.time()
	local remaining = endTime - timestamp
	if remaining < 0 then
		return 0
	end
	return math.floor(remaining)
end

function DataService:SetPotionCount(player, potionId, count)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	if type(record.Data.PotionCounts) ~= "table" then
		record.Data.PotionCounts = {}
	end
	local id = tonumber(potionId) or potionId
	local value = normalizeCount(count)
	record.Data.PotionCounts[id] = value
	record.Dirty = true
	return value
end

function DataService:AddPotionCount(player, potionId, delta)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	if type(record.Data.PotionCounts) ~= "table" then
		record.Data.PotionCounts = {}
	end
	local id = tonumber(potionId) or potionId
	local current = normalizeCount(record.Data.PotionCounts[id])
	local nextValue = normalizeCount(current + (tonumber(delta) or 0))
	record.Data.PotionCounts[id] = nextValue
	record.Dirty = true
	return nextValue
end

function DataService:SetPotionEndTime(player, potionId, endTime)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	if type(record.Data.PotionEndTimes) ~= "table" then
		record.Data.PotionEndTimes = {}
	end
	local id = tonumber(potionId) or potionId
	local timeValue = tonumber(endTime) or 0
	if timeValue < 0 then
		timeValue = 0
	end
	timeValue = math.floor(timeValue)
	record.Data.PotionEndTimes[id] = timeValue
	record.Dirty = true
	return timeValue
end

function DataService:GetPotionBonus(player, now)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	return getPotionBonusFromEndTimes(record.Data.PotionEndTimes, now)
end

function DataService:GetPurchaseBonusAdd(player)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	return getPurchaseBonusAdd(record.Data.OutputMultiplier)
end

function DataService:GetTotalOutputBonusAdd(player, now)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	local progressionBonus = normalizeBonusAdd(record.ProgressionOutputBonus)
	return getTotalBonusAddFromData(record.Data, progressionBonus, now)
end

function DataService:GetOutputBonusFactor(player, now)
	local totalAdd = self:GetTotalOutputBonusAdd(player, now)
	local factor = 1 + totalAdd
	if factor < 0 then
		factor = 0
	end
	return factor
end

function DataService:ApplyPotionDuration(player, potionId, addSeconds)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	local added = tonumber(addSeconds) or 0
	if added <= 0 then
		return self:GetPotionEndTime(player, potionId)
	end
	local oldFactor = self:GetOutputBonusFactor(player)
	local now = os.time()
	local currentEnd = self:GetPotionEndTime(player, potionId)
	local baseTime = currentEnd > now and currentEnd or now
	local newEnd = baseTime + math.floor(added)
	self:SetPotionEndTime(player, potionId, newEnd)
	local newFactor = self:GetOutputBonusFactor(player)
	adjustCollectTimesForOutputBonusChange(player, oldFactor, newFactor)
	self:RecalculateOutputSpeed(player)
	return newEnd
end

function DataService:ClearExpiredPotions(player, now)
	local record = sessionData[player.UserId]
	if not record then
		return false
	end
	if type(record.Data.PotionEndTimes) ~= "table" then
		record.Data.PotionEndTimes = {}
	end
	local timestamp = now or os.time()
	local changed = false
	local expiredBonusAdd = 0
	for _, info in ipairs(PotionConfig.GetAll()) do
		if info and info.Id then
			local endTime = tonumber(record.Data.PotionEndTimes[info.Id]) or 0
			if endTime > 0 and endTime <= timestamp then
				expiredBonusAdd += tonumber(info.Bonus) or 0
				record.Data.PotionEndTimes[info.Id] = 0
				changed = true
			end
		end
	end
	if not changed then
		return false
	end
	record.Dirty = true
	local currentFactor = self:GetOutputBonusFactor(player, timestamp)
	local oldFactor = currentFactor + normalizeBonusAdd(expiredBonusAdd)
	local newFactor = currentFactor
	adjustCollectTimesForOutputBonusChange(player, oldFactor, newFactor)
	self:RecalculateOutputSpeed(player)
	return true
end


function DataService:GenerateUid()
	return HttpService:GenerateGUID(false)
end

function DataService:MarkDirty(player)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	record.Dirty = true
end

function DataService:HasFigurine(player, figurineId)
	local record = sessionData[player.UserId]
	if not record or type(record.Data.Figurines) ~= "table" then
		return false
	end
	local id = tonumber(figurineId) or figurineId
	return record.Data.Figurines[id] == true
end

function DataService:AddFigurine(player, figurineId, capsuleRarity)
	local record = sessionData[player.UserId]
	if not record then
		return nil
	end
	if type(record.Data.Figurines) ~= "table" then
		record.Data.Figurines = {}
	end
	if type(record.Data.FigurineStates) ~= "table" then
		record.Data.FigurineStates = {}
	end
	local id = tonumber(figurineId) or figurineId
	local info = FigurineConfig.GetById(id)
	local defaultRarity = normalizeRarity(info and info.Rarity or 1)
	local incomingRarity = normalizeRarity(capsuleRarity or defaultRarity)
	local isNew = record.Data.Figurines[id] ~= true
	if isNew then
		record.Data.Figurines[id] = true
	end

	local state = record.Data.FigurineStates[id]
	if type(state) ~= "table" then
		state = {}
		record.Data.FigurineStates[id] = state
	end

	if isNew then
		state.Level = 1
		state.Exp = 0
		state.Rarity = incomingRarity
		state.LastCollectTime = os.time()
	end

	local rarityUpgraded = false
	if not isNew then
		local currentRarity = normalizeRarity(state.Rarity or defaultRarity)
		if incomingRarity > currentRarity then
			state.Rarity = incomingRarity
			rarityUpgraded = true
		elseif state.Rarity ~= currentRarity then
			state.Rarity = currentRarity
		end
	end

	if state.LastCollectTime == nil or tonumber(state.LastCollectTime) == nil or state.LastCollectTime <= 0 then
		state.LastCollectTime = os.time()
	end

	local beforeLevel = normalizeLevel(state.Level)
	local beforeExp = normalizeExp(state.Exp)
	local addedExp = isNew and 0 or 1
	local currentExp = beforeExp + addedExp
	local currentLevel, remainingExp, leveledUp, isMax = applyLevelExp(beforeLevel, currentExp)

	state.Level = currentLevel
	state.Exp = remainingExp
	record.Dirty = true
	setFigurineOwnedValue(player, id, true)
	if isNew or leveledUp or rarityUpgraded then
		self:RecalculateOutputSpeed(player)
	end
	return {
		IsNew = isNew,
		LeveledUp = leveledUp,
		MaxLevel = isMax,
		Level = currentLevel,
		Exp = remainingExp,
		Rarity = state.Rarity,
		PrevLevel = beforeLevel,
		PrevExp = beforeExp,
		AddedExp = addedExp,
	}
end

function DataService:EnsureFigurineState(player, figurineId)
	local record = sessionData[player.UserId]
	if not record then
		return nil
	end
	if type(record.Data.FigurineStates) ~= "table" then
		record.Data.FigurineStates = {}
	end
	if type(record.Data.Figurines) ~= "table" then
		record.Data.Figurines = {}
	end
	local id = tonumber(figurineId) or figurineId
	local info = FigurineConfig.GetById(id)
	local defaultRarity = normalizeRarity(info and info.Rarity or 1)
	local state = record.Data.FigurineStates[id]
	if type(state) ~= "table" then
		state = { LastCollectTime = os.time() }
		record.Data.FigurineStates[id] = state
		record.Dirty = true
	elseif state.LastCollectTime == nil or tonumber(state.LastCollectTime) == nil or state.LastCollectTime <= 0 then
		state.LastCollectTime = os.time()
		record.Dirty = true
	end
	local maxLevel = UpgradeConfig.GetMaxLevel()
	local normalizedLevel = normalizeLevel(state.Level)
	if normalizedLevel > maxLevel then
		normalizedLevel = maxLevel
	end
	if state.Level ~= normalizedLevel then
		state.Level = normalizedLevel
		record.Dirty = true
	end
	local normalizedExp
	if state.Exp == nil then
		normalizedExp = 0
	else
		normalizedExp = normalizeExp(state.Exp)
	end
	if state.Exp ~= normalizedExp then
		state.Exp = normalizedExp
		record.Dirty = true
	end
	local normalizedRarity
	if state.Rarity == nil then
		normalizedRarity = defaultRarity
	else
		normalizedRarity = normalizeRarity(state.Rarity)
	end
	if state.Rarity ~= normalizedRarity then
		state.Rarity = normalizedRarity
		record.Dirty = true
	end
	return state
end

function DataService:RefreshAllFigurineStates(player)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	local figurines = record.Data.Figurines
	if type(figurines) ~= "table" then
		return 0
	end
	local count = 0
	for figurineId, owned in pairs(figurines) do
		if owned then
			if self:EnsureFigurineState(player, figurineId) then
				count += 1
			end
		end
	end
	return count
end

function DataService:SetFigurineLastCollectTime(player, figurineId, timestamp)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	if type(record.Data.FigurineStates) ~= "table" then
		record.Data.FigurineStates = {}
	end
	local id = tonumber(figurineId) or figurineId
	local state = record.Data.FigurineStates[id]
	if type(state) ~= "table" then
		state = {}
		record.Data.FigurineStates[id] = state
	end
	state.LastCollectTime = timestamp
	record.Dirty = true
end

function DataService:AddEgg(player, eggId, uid)
	local record = sessionData[player.UserId]
	if not record then
		return nil
	end
	if type(record.Data.Eggs) ~= "table" then
		record.Data.Eggs = {}
	end
	local newUid = uid or self:GenerateUid()
	table.insert(record.Data.Eggs, { Uid = newUid, EggId = eggId })
	record.Dirty = true
	return newUid
end

local function removeEggByUid(list, uid)
	for i = #list, 1, -1 do
		if list[i].Uid == uid then
			return table.remove(list, i)
		end
	end
	return nil
end

local function removeEggById(list, eggId)
	for i = #list, 1, -1 do
		if list[i].EggId == eggId then
			return table.remove(list, i)
		end
	end
	return nil
end

function DataService:RemoveEgg(player, uid, eggId)
	local record = sessionData[player.UserId]
	if not record or type(record.Data.Eggs) ~= "table" then
		return nil
	end

	local removed
	if uid then
		removed = removeEggByUid(record.Data.Eggs, uid)
	end
	if not removed and eggId then
		removed = removeEggById(record.Data.Eggs, eggId)
	end

	if removed then
		record.Dirty = true
	end
	return removed
end

function DataService:AddPlacedEgg(player, entry)
	local record = sessionData[player.UserId]
	if not record or type(entry) ~= "table" then
		return false
	end
	if type(record.Data.PlacedEggs) ~= "table" then
		record.Data.PlacedEggs = {}
	end
	table.insert(record.Data.PlacedEggs, entry)
	record.Dirty = true
	return true
end

function DataService:RemovePlacedEgg(player, uid)
	local record = sessionData[player.UserId]
	if not record or type(record.Data.PlacedEggs) ~= "table" then
		return false
	end

	for i = #record.Data.PlacedEggs, 1, -1 do
		if record.Data.PlacedEggs[i].Uid == uid then
			table.remove(record.Data.PlacedEggs, i)
			record.Dirty = true
			return true
		end
	end

	return false
end

function DataService:SetCoins(player, amount)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	record.Data.Coins = amount
	record.Dirty = true
	applyCoinsAttribute(player, amount)
end

function DataService:SetDiamonds(player, amount)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	local normalized = normalizeDiamonds(amount)
	record.Data.Diamonds = normalized
	record.Dirty = true
	applyDiamondsAttribute(player, normalized)
end

function DataService:AddCoins(player, delta)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	local newValue = record.Data.Coins + delta
	record.Data.Coins = newValue
	record.Dirty = true
	applyCoinsAttribute(player, newValue)
	return newValue
end

function DataService:AddDiamonds(player, delta)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	local newValue = normalizeDiamonds(record.Data.Diamonds + (tonumber(delta) or 0))
	record.Data.Diamonds = newValue
	record.Dirty = true
	applyDiamondsAttribute(player, newValue)
	return newValue
end

function DataService:GetCapsuleOpenTotal(player)
	local record = sessionData[player.UserId]
	return record and record.Data.CapsuleOpenTotal or 0
end

function DataService:GetCapsuleOpenById(player)
	local record = sessionData[player.UserId]
	return record and record.Data.CapsuleOpenById or nil
end

function DataService:AddCapsuleOpen(player, capsuleId)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	local data = record.Data
	data.CapsuleOpenTotal = normalizeCount(data.CapsuleOpenTotal) + 1

	if type(data.CapsuleOpenById) ~= "table" then
		data.CapsuleOpenById = {}
	end
	local id = tonumber(capsuleId) or capsuleId
	data.CapsuleOpenById[id] = normalizeCount(data.CapsuleOpenById[id]) + 1

	record.Dirty = true
	if player and player.Parent then
		player:SetAttribute("CapsuleOpenTotal", data.CapsuleOpenTotal)
	end
end

function DataService:GetTotalPlayTime(player)
	local record = sessionData[player.UserId]
	return record and record.Data.TotalPlayTime or 0
end

function DataService:RecalculateOutputSpeed(player)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	local totalBonusAdd = self:GetTotalOutputBonusAdd(player, os.time())
	local total = calculateOutputSpeed(record.Data.Figurines, record.Data.FigurineStates, totalBonusAdd)
	if record.Data.OutputSpeed ~= total then
		record.Data.OutputSpeed = total
		record.Dirty = true
	end
	if player and player.Parent then
		player:SetAttribute("OutputSpeed", total)
	end
	return total
end

function DataService:StartPlaytimeTracker(player)
	local record = sessionData[player.UserId]
	if not record or record.PlaytimeLoop then
		return
	end
	record.PlaytimeActive = true
	record.LastPlaytimeUpdate = os.time()
	record.PlaytimeLoop = true

	task.spawn(function()
		while record.PlaytimeActive and player.Parent do
			task.wait(PLAYTIME_UPDATE_INTERVAL)
			if not record.PlaytimeActive or not player.Parent then
				break
			end
			updatePlaytimeRecord(record, player)
		end
		record.PlaytimeLoop = false
	end)
end

function DataService:StopPlaytimeTracker(player)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	record.PlaytimeActive = false
	updatePlaytimeRecord(record, player)
end

function DataService:ApplyOfflineCap(player, capSeconds)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	local data = record.Data
	local lastLogout = normalizeLogoutTime(data.LastLogoutTime)
	if lastLogout <= 0 then
		return
	end
	local limit = tonumber(capSeconds) or 0
	if limit <= 0 then
		return
	end
	local now = os.time()
	local offlineSeconds = now - lastLogout
	if offlineSeconds <= limit then
		return
	end
	local excess = offlineSeconds - limit
	if excess <= 0 then
		return
	end
	if type(data.FigurineStates) ~= "table" then
		return
	end
	local changed = false
	for _, state in pairs(data.FigurineStates) do
		if type(state) == "table" then
			local lastCollect = tonumber(state.LastCollectTime)
			if lastCollect and lastCollect > 0 and lastCollect <= lastLogout then
				local adjusted = lastCollect + excess
				if adjusted > now then
					adjusted = now
				end
				if adjusted ~= lastCollect then
					state.LastCollectTime = adjusted
					changed = true
				end
			end
		end
	end
	if changed then
		record.Dirty = true
	end
end

function DataService:MarkLogoutTime(player)
	local record = sessionData[player.UserId]
	if not record then
		return
	end
	record.Data.LastLogoutTime = os.time()
	record.Dirty = true
end

function DataService:ResetPlayerData(player)
	local userId = player.UserId
	local data = defaultData()

	local record = sessionData[userId]
	if record then
		record.Data = data
		record.Dirty = true
		record.LastSave = os.clock()
		record.LastPlaytimeUpdate = os.time()
		record.ProgressionOutputBonus = 0
	else
		sessionData[userId] = {
			Data = data,
			Dirty = true,
			LastSave = os.clock(),
			ProgressionOutputBonus = 0,
			PlaytimeActive = true,
			LastPlaytimeUpdate = os.time(),
			PlaytimeLoop = false,
			DataVersion = 1,
		}
	end

	applyCoinsAttribute(player, data.Coins)
	applyStatsAttributes(player, data)
	syncFigurineOwnedFolder(player, data.Figurines)
	self:StartPlaytimeTracker(player)
	self:SavePlayer(player, true)
	return data
end

local function saveByUserId(userId, record, force)
	if not record then
		return true
	end
	if not force and not record.Dirty then
		return true
	end

	local key = tostring(userId)
	local data = record.Data
	local success, err = pcall(function()
		store:UpdateAsync(key, function()
			return data
		end)
	end)

	if success then
		record.Dirty = false
		record.LastSave = os.clock()
	else
		warn(string.format("DataService save failed: userId=%s err=%s", key, tostring(err)))
	end

	return success
end

function DataService:SavePlayer(player, force)
	local userId = player.UserId
	local record = sessionData[userId]
	return saveByUserId(userId, record, force)
end

function DataService:UnloadPlayer(player, force)
	self:StopPlaytimeTracker(player)
	self:MarkLogoutTime(player)
	self:SavePlayer(player, force)
	sessionData[player.UserId] = nil
end

function DataService:SaveAll(force)
	for userId, record in pairs(sessionData) do
		saveByUserId(userId, record, force)
	end
end

function DataService:GetSnapshot(player)
	local record = sessionData[player.UserId]
	if not record then
		return nil
	end
	-- 返回玩家数据的浅拷贝用于客户端同步
	local snapshot = {}
	for key, value in pairs(record.Data) do
		snapshot[key] = value
	end
	return snapshot
end

function DataService:GetVersion(player)
	local record = sessionData[player.UserId]
	if not record then
		return 0
	end
	return record.DataVersion or 1
end

function DataService:StartAutoSave()
	if autoSaveStarted then
		return
	end
	autoSaveStarted = true

	task.spawn(function()
		while true do
			task.wait(GameConfig.AutoSaveInterval)
			self:SaveAll(false)
		end
	end)
end

return DataService


