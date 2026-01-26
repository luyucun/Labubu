--[[
脚本名称: GlobalLeaderboardService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/GlobalLeaderboardService
版本: V1.0
职责: 全局产速排行榜的数据维护与刷新推送
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalLeaderboardService = {}
GlobalLeaderboardService.__index = GlobalLeaderboardService

local ORDERED_STORE_NAME = "Labubu_GlobalOutputSpeed_V1"
local META_STORE_NAME = "Labubu_GlobalOutputSpeedMeta_V1"
local REFRESH_INTERVAL = 60
local FETCH_LIMIT = 60
local DISPLAY_LIMIT = 20

local orderedStore = DataStoreService:GetOrderedDataStore(ORDERED_STORE_NAME)
local metaStore = DataStoreService:GetDataStore(META_STORE_NAME)

local playerStates = {} -- [userId] = {Speed, AchievedAt, Name}
local connections = {} -- [player] = {Connection}
local cache = {
	List = {},
	NextRefresh = 0,
	LastRefresh = 0,
}
local refreshing = false

local function normalizeSpeed(value)
	local num = tonumber(value)
	if not num or num < 0 then
		return 0
	end
	return math.ceil(num - 1e-9)
end

local function nowSeconds()
	return os.time()
end

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

local requestEvent = ensureRemoteEvent("RequestGlobalLeaderboard")
local pushEvent = ensureRemoteEvent("PushGlobalLeaderboard")

local function loadMeta(userId)
	local key = tostring(userId)
	local ok, data = pcall(function()
		return metaStore:GetAsync(key)
	end)
	if ok and type(data) == "table" then
		return data
	end
	return nil
end

local function saveMeta(userId, name, speed, achievedAt)
	local key = tostring(userId)
	pcall(function()
		metaStore:SetAsync(key, {
			Name = name,
			Speed = speed,
			AchievedAt = achievedAt,
		})
	end)
end

local function saveOrdered(userId, speed)
	local key = tostring(userId)
	pcall(function()
		orderedStore:SetAsync(key, speed)
	end)
end

local function getPlayerState(player)
	if not player or not player.Parent then
		return nil
	end
	local userId = player.UserId
	local state = playerStates[userId]
	if state then
		return state
	end
	state = {
		Speed = 0,
		AchievedAt = nowSeconds(),
		Name = player.Name,
	}
	local meta = loadMeta(userId)
	if meta then
		state.Speed = normalizeSpeed(meta.Speed)
		state.AchievedAt = tonumber(meta.AchievedAt) or state.AchievedAt
		if type(meta.Name) == "string" and meta.Name ~= "" then
			state.Name = meta.Name
		end
	end
	playerStates[userId] = state
	return state
end

local function updatePlayerEntry(player, speed, force)
	if not player or not player.Parent then
		return
	end
	local state = getPlayerState(player)
	if not state then
		return
	end
	local newSpeed = normalizeSpeed(speed)
	local now = nowSeconds()
	local dirty = force == true

	if newSpeed ~= state.Speed then
		state.Speed = newSpeed
		state.AchievedAt = now
		dirty = true
	end

	if state.Name ~= player.Name then
		state.Name = player.Name
		dirty = true
	end

	if dirty then
		saveMeta(player.UserId, state.Name, state.Speed, state.AchievedAt)
		saveOrdered(player.UserId, state.Speed)
	end
end

local function formatEntry(userId, name, speed, achievedAt)
	return {
		UserId = userId,
		Name = name,
		Speed = speed,
		AchievedAt = achievedAt,
	}
end

local function fetchTopEntries()
	local ok, pages = pcall(function()
		return orderedStore:GetSortedAsync(false, FETCH_LIMIT)
	end)
	if not ok or not pages then
		return {}
	end
	local page = pages:GetCurrentPage()
	local results = {}
	for _, entry in ipairs(page) do
		local userId = tonumber(entry.key)
		if userId then
			local speed = normalizeSpeed(entry.value)
			local name
			local achievedAt
			local state = playerStates[userId]
			if state then
				name = state.Name
				achievedAt = state.AchievedAt
			else
				local meta = loadMeta(userId)
				if meta then
					name = type(meta.Name) == "string" and meta.Name or nil
					achievedAt = tonumber(meta.AchievedAt)
				end
			end
			if not name or name == "" then
				name = tostring(userId)
			end
			achievedAt = achievedAt or nowSeconds()
			table.insert(results, formatEntry(userId, name, speed, achievedAt))
		end
	end
	table.sort(results, function(a, b)
		if a.Speed == b.Speed then
			if a.AchievedAt == b.AchievedAt then
				return a.UserId < b.UserId
			end
			return a.AchievedAt < b.AchievedAt
		end
		return a.Speed > b.Speed
	end)
	local top = {}
	for index = 1, math.min(DISPLAY_LIMIT, #results) do
		local entry = results[index]
		table.insert(top, {
			UserId = entry.UserId,
			Name = entry.Name,
			Speed = entry.Speed,
			Rank = index,
		})
	end
	return top
end

function GlobalLeaderboardService:Refresh()
	if refreshing then
		return
	end
	refreshing = true
	local list = fetchTopEntries()
	cache.List = list
	cache.LastRefresh = nowSeconds()
	cache.NextRefresh = cache.LastRefresh + REFRESH_INTERVAL
	if pushEvent then
		pushEvent:FireAllClients(cache.List, cache.NextRefresh)
	end
	refreshing = false
end

function GlobalLeaderboardService:Init()
	self:Refresh()
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			self:Refresh()
		end
	end)

	if requestEvent then
		requestEvent.OnServerEvent:Connect(function(player)
			if not player or not player.Parent then
				return
			end
			local now = nowSeconds()
			if cache.NextRefresh == 0 or now >= cache.NextRefresh then
				self:Refresh()
			end
			if pushEvent then
				pushEvent:FireClient(player, cache.List, cache.NextRefresh)
			end
		end)
	end
end

function GlobalLeaderboardService:BindPlayer(player)
	if not player or not player.Parent then
		return
	end
	self:UnbindPlayer(player)
	local connection = player:GetAttributeChangedSignal("OutputSpeed"):Connect(function()
		updatePlayerEntry(player, player:GetAttribute("OutputSpeed"))
	end)
	connections[player] = connection
	updatePlayerEntry(player, player:GetAttribute("OutputSpeed"), true)
end

function GlobalLeaderboardService:UnbindPlayer(player)
	local connection = connections[player]
	if connection then
		connection:Disconnect()
	end
	connections[player] = nil
	playerStates[player.UserId] = nil
end

return GlobalLeaderboardService
