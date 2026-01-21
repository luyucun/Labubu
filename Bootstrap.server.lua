--[[
脚本名称: Bootstrap
脚本类型: Script
脚本位置: ServerScriptService/Server/Bootstrap
版本: V1.5
职责: 玩家进入/离开流程串联
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EggService = require(script.Parent:WaitForChild("EggService"))
local FigurineService = require(script.Parent:WaitForChild("FigurineService"))
local HomeService = require(script.Parent:WaitForChild("HomeService"))
local ConveyorService = require(script.Parent:WaitForChild("ConveyorService"))
local ClaimService = require(script.Parent:WaitForChild("ClaimService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))

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

local updateAudioSettingsEvent = ensureRemoteEvent("UpdateAudioSettings")
if updateAudioSettingsEvent then
	updateAudioSettingsEvent.OnServerEvent:Connect(function(player, musicEnabled, sfxEnabled)
		DataService:SetAudioSettings(player, musicEnabled, sfxEnabled)
	end)
end

Players.CharacterAutoLoads = false

HomeService:Init()
ClaimService:Init()
DataService:StartAutoSave()

game:BindToClose(function()
	DataService:SaveAll(true)
end)

Players.PlayerAdded:Connect(function(player)
	print(string.format("[Bootstrap] PlayerAdded: %s (userId=%d)", player.Name, player.UserId))

	if #Players:GetPlayers() > GameConfig.MaxPlayers then
		player:Kick("Server is full")
		return
	end

	local homeSlot = HomeService:AssignHome(player)
	print(string.format("[Bootstrap] AssignHome returned: %s", tostring(homeSlot)))
	if not homeSlot then
		player:Kick("Server is full")
		return
	end
	print(string.format("[Bootstrap] homeSlot.Folder = %s", tostring(homeSlot.Folder)))

	DataService:LoadPlayer(player)
	print("[Bootstrap] DataService:LoadPlayer done")
	LeaderboardService:BindPlayer(player)

	EggService:BindPlayer(player)
	print("[Bootstrap] EggService:BindPlayer done")

	FigurineService:BindPlayer(player)

	ClaimService:BindPlayer(player)
	print("[Bootstrap] ClaimService:BindPlayer done")
	print("[Bootstrap] FigurineService:BindPlayer done")

	print("[Bootstrap] Calling ConveyorService:StartForPlayer...")
	local success, err = pcall(function()
		ConveyorService:StartForPlayer(player, homeSlot)
	end)
	if not success then
		warn(string.format("[Bootstrap] ConveyorService:StartForPlayer ERROR: %s", tostring(err)))
	else
		print("[Bootstrap] ConveyorService:StartForPlayer done")
	end

	player:LoadCharacterAsync()
end)

Players.PlayerRemoving:Connect(function(player)
	ConveyorService:StopForPlayer(player)
	EggService:UnbindPlayer(player)
	FigurineService:UnbindPlayer(player)
	ClaimService:UnbindPlayer(player)
	LeaderboardService:UnbindPlayer(player)
	DataService:UnloadPlayer(player, true)
	HomeService:ReleaseHome(player)
end)
