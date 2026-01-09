--[[
脚本名称: DataService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/DataService
版本: V1.1
职责: 数据加载/保存与金币管理
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))

local DataService = {}
DataService.__index = DataService

local store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
local sessionData = {} -- [userId] = {Data = table, Dirty = bool, LastSave = number}
local autoSaveStarted = false

local function defaultData()
	return {
		Coins = GameConfig.StartCoins,
	}
end

local function applyCoinsAttribute(player, coins)
	if player and player.Parent then
		player:SetAttribute("Coins", coins)
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

	if data.Coins == nil then
		data.Coins = GameConfig.StartCoins
	end

	sessionData[userId] = {
		Data = data,
		Dirty = false,
		LastSave = os.clock(),
	}

	applyCoinsAttribute(player, data.Coins)

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
