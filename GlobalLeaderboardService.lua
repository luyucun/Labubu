--[[
脚本名称: GlobalLeaderboardService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/GlobalLeaderboardService
版本: V1.1
职责: 全局产速排行榜的数据维护与刷新推送
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalLeaderboardService = {}
GlobalLeaderboardService.__index = GlobalLeaderboardService

local ORDERED_STORE_NAME = "Labubu_GlobalOutputSpeed_V1"
local REFRESH_INTERVAL = 120
local INITIAL_REFRESH_DELAY = 20
local FETCH_LIMIT = 30
local DISPLAY_LIMIT = 20
local ORDERED_WRITE_INTERVAL = 20
local ORDERED_WRITE_FLUSH_INTERVAL = 5
local ORDERED_WRITE_FLUSH_BATCH = 8

local orderedStore = DataStoreService:GetOrderedDataStore(ORDERED_STORE_NAME)

local playerStates = {} -- [userId] = {Speed, AchievedAt, Name}
local connections = {} -- [player] = {Connection}
local orderedWriteStates = {} -- [userId] = {LastWrite, PendingSpeed}
local cache = {
	List = {},
	NextRefresh = 0,
	LastRefresh = 0,
}
local refreshing = false
local closeBound = false

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

local function saveOrdered(userId, speed)
	local key = tostring(userId)
	local success, err = pcall(function()
		orderedStore:SetAsync(key, speed)
	end)
	if not success then
		warn(string.format("[GlobalLeaderboardService] orderedStore:SetAsync failed: userId=%s err=%s", key, tostring(err)))
	end
	return success
end

local function flushOrderedWrite(userId, state, force)
	if not state or state.PendingSpeed == nil then
		return false
	end
	local now = nowSeconds()
	if not force and now - (state.LastWrite or 0) < ORDERED_WRITE_INTERVAL then
		return false
	end
	local speed = normalizeSpeed(state.PendingSpeed)
	if saveOrdered(userId, speed) then
		state.LastWrite = now
		if state.PendingSpeed == speed then
			state.PendingSpeed = nil
		end
		return true
	end
	return false
end

local function queueOrderedWrite(userId, speed, force)
	local state = orderedWriteStates[userId]
	if not state then
		state = {
			LastWrite = 0,
			PendingSpeed = nil,
		}
		orderedWriteStates[userId] = state
	end
	state.PendingSpeed = normalizeSpeed(speed)
	flushOrderedWrite(userId, state, force == true)
end

local function flushOrderedWrites(force)
	local flushed = 0
	for userId, state in pairs(orderedWriteStates) do
		if flushOrderedWrite(userId, state, force) then
			flushed += 1
		end
		if not force and flushed >= ORDERED_WRITE_FLUSH_BATCH then
			break
		end
	end
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
		queueOrderedWrite(player.UserId, state.Speed, force == true)
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
			local state = playerStates[userId]
			local name = state and state.Name or tostring(userId)
			local achievedAt = state and state.AchievedAt or 0
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
	task.delay(INITIAL_REFRESH_DELAY, function()
		self:Refresh()
	end)

	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			self:Refresh()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(ORDERED_WRITE_FLUSH_INTERVAL)
			flushOrderedWrites(false)
		end
	end)

	if not closeBound then
		closeBound = true
		game:BindToClose(function()
			flushOrderedWrites(true)
		end)
	end

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
	local writeState = orderedWriteStates[player.UserId]
	if writeState then
		flushOrderedWrite(player.UserId, writeState, true)
	end
	orderedWriteStates[player.UserId] = nil
	playerStates[player.UserId] = nil
end

return GlobalLeaderboardService

