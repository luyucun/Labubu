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

local DataService = {}
DataService.__index = DataService

local store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
local sessionData = {} -- [userId] = {Data = table, Dirty = bool, LastSave = number}
local autoSaveStarted = false
local PLAYTIME_UPDATE_INTERVAL = 1

local function defaultData()
	return {
		Coins = GameConfig.StartCoins,
		Figurines = {},
		FigurineStates = {},
		Eggs = {},
		PlacedEggs = {},
		TotalPlayTime = 0,
		CapsuleOpenTotal = 0,
		CapsuleOpenById = {},
		OutputSpeed = 0,
		AutoCollect = false,
		MusicEnabled = true,
		SfxEnabled = true,
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

local function normalizeOutputSpeed(value)
	local num = tonumber(value)
	if not num or num < 0 then
		return 0
	end
	return num
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
	local levelFactor = 1 + (level - 1) * qualityCoeff
	if levelFactor < 0 then
		levelFactor = 0
	end
	return baseRate * rarityCoeff * levelFactor
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

local function calculateOutputSpeed(figurines, figurineStates)
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
	return total
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

local function applyStatsAttributes(player, data)
	if not player or not player.Parent then
		return
	end
	player:SetAttribute("TotalPlayTime", normalizeCount(data.TotalPlayTime))
	player:SetAttribute("CapsuleOpenTotal", normalizeCount(data.CapsuleOpenTotal))
	player:SetAttribute("OutputSpeed", normalizeOutputSpeed(data.OutputSpeed))
	player:SetAttribute("AutoCollect", data.AutoCollect == true)
	player:SetAttribute("MusicEnabled", data.MusicEnabled == true)
	player:SetAttribute("SfxEnabled", data.SfxEnabled == true)
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
end

function DataService:LoadPlayer(player)
	local userId = player.UserId
	local key = tostring(userId)
	local data

	local success, result = pcall(function()
		return store:GetAsync(key)
	end)

	if success and type(result) == "table" then
		data = result
	else
		data = defaultData()
	end

	local needsSave = false

	if data.Coins == nil then
		data.Coins = GameConfig.StartCoins
		needsSave = true
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

	local recalculatedSpeed = calculateOutputSpeed(data.Figurines, data.FigurineStates)
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
		PlaytimeActive = true,
		LastPlaytimeUpdate = os.time(),
		PlaytimeLoop = false,
	}

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
	local total = calculateOutputSpeed(record.Data.Figurines, record.Data.FigurineStates)
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

function DataService:ResetPlayerData(player)
	local userId = player.UserId
	local data = defaultData()

	local record = sessionData[userId]
	if record then
		record.Data = data
		record.Dirty = true
		record.LastSave = os.clock()
		record.LastPlaytimeUpdate = os.time()
	else
		sessionData[userId] = {
			Data = data,
			Dirty = true,
			LastSave = os.clock(),
			PlaytimeActive = true,
			LastPlaytimeUpdate = os.time(),
			PlaytimeLoop = false,
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
	self:SavePlayer(player, force)
	sessionData[player.UserId] = nil
end

function DataService:SaveAll(force)
	for userId, record in pairs(sessionData) do
		saveByUserId(userId, record, force)
	end
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


