--[[
脚本名称: Bootstrap
脚本类型: Script
脚本位置: ServerScriptService/Server/Bootstrap
版本: V2.0
职责: 玩家进入/离开流程串联，与客户端预加载协调
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local EggService = require(script.Parent:WaitForChild("EggService"))
local FigurineService = require(script.Parent:WaitForChild("FigurineService"))
local HomeService = require(script.Parent:WaitForChild("HomeService"))
local ConveyorService = require(script.Parent:WaitForChild("ConveyorService"))
local ClaimService = require(script.Parent:WaitForChild("ClaimService"))
local PotionService = require(script.Parent:WaitForChild("PotionService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))
local FriendBonusService = require(script.Parent:WaitForChild("FriendBonusService"))
local GlobalLeaderboardService = require(script.Parent:WaitForChild("GlobalLeaderboardService"))
local GuideService = require(script.Parent:WaitForChild("GuideService"))
local StarterPackService = require(script.Parent:WaitForChild("StarterPackService"))

--------------------------------------------------------------------------------
-- RemoteEvent管理
--------------------------------------------------------------------------------
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

-- 创建所有需要的RemoteEvent
local updateAudioSettingsEvent = ensureRemoteEvent("UpdateAudioSettings")
local pushInitDataEvent = ensureRemoteEvent("PushInitData")

if updateAudioSettingsEvent then
	updateAudioSettingsEvent.OnServerEvent:Connect(function(player, musicEnabled, sfxEnabled)
		DataService:SetAudioSettings(player, musicEnabled, sfxEnabled)
	end)
end

--------------------------------------------------------------------------------
-- 服务初始化
--------------------------------------------------------------------------------
Players.CharacterAutoLoads = false

HomeService:Init()
ClaimService:Init()
DataService:StartAutoSave()
ProgressionService:Init()
PotionService:Init()
FriendBonusService:Init()
GlobalLeaderboardService:Init()
GuideService:Init()
StarterPackService:Init()

--------------------------------------------------------------------------------
-- 关服保存
--------------------------------------------------------------------------------
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataService:MarkLogoutTime(player)
	end
	DataService:SaveAll(true)
end)

--------------------------------------------------------------------------------
-- 玩家进入处理
--------------------------------------------------------------------------------
local function handlePlayerAdded(player)
	if not player or not player.Parent then
		return
	end
	if player:GetAttribute("BootstrapReady") then
		return
	end
	player:SetAttribute("BootstrapReady", true)
	player:SetAttribute("DataReady", false) -- 标记数据未就绪

	-- 检查服务器人数
	if #Players:GetPlayers() > GameConfig.MaxPlayers then
		player:Kick("Server is full")
		return
	end

	-- 分配家园
	local homeSlot = HomeService:AssignHome(player)
	if not homeSlot then
		player:Kick("Server is full")
		return
	end

	-- 加载玩家数据
	local data, loadErr, loadDetail = DataService:LoadPlayer(player)
	if not data then
		warn(string.format("[Bootstrap] DataService:LoadPlayer failed: userId=%d err=%s detail=%s", player.UserId, tostring(loadErr), tostring(loadDetail)))
		player:SetAttribute("BootstrapReady", nil)
		player:SetAttribute("DataReady", nil)
		HomeService:ReleaseHome(player)
		player:Kick("数据加载失败，请重进")
		return
	end

	-- 绑定各服务
	ProgressionService:BindPlayer(player)
	PotionService:BindPlayer(player)
	LeaderboardService:BindPlayer(player)
	GlobalLeaderboardService:BindPlayer(player)
	GuideService:BindPlayer(player)
	StarterPackService:BindPlayer(player)

	EggService:BindPlayer(player)

	FigurineService:BindPlayer(player)

	ClaimService:BindPlayer(player)

	FriendBonusService:HandlePlayerAdded(player)

	-- 启动传送带
	local success, err = pcall(function()
		ConveyorService:StartForPlayer(player, homeSlot)
	end)
	if not success then
		warn(string.format("[Bootstrap] ConveyorService:StartForPlayer ERROR: %s", tostring(err)))
	end

	-- 标记数据已就绪（客户端AssetPreload会等待这个标记）
	player:SetAttribute("DataReady", true)

	-- 推送初始数据给客户端
	if pushInitDataEvent then
		local snapshot = DataService:GetSnapshot(player)
		if snapshot then
			pushInitDataEvent:FireClient(player, snapshot, os.time(), DataService:GetVersion(player))
		end
	end

	-- 加载角色
	player:LoadCharacterAsync()
end

--------------------------------------------------------------------------------
-- 玩家离开处理
--------------------------------------------------------------------------------
local function handlePlayerRemoving(player)
	ConveyorService:StopForPlayer(player)
	EggService:UnbindPlayer(player)
	FigurineService:UnbindPlayer(player)
	ClaimService:UnbindPlayer(player)
	LeaderboardService:UnbindPlayer(player)
	GlobalLeaderboardService:UnbindPlayer(player)
	ProgressionService:UnbindPlayer(player)
	PotionService:UnbindPlayer(player)
	GuideService:UnbindPlayer(player)
	StarterPackService:UnbindPlayer(player)
	FriendBonusService:HandlePlayerRemoving(player)
	DataService:UnloadPlayer(player, true)
	HomeService:ReleaseHome(player)
end

--------------------------------------------------------------------------------
-- 事件绑定
--------------------------------------------------------------------------------
Players.PlayerAdded:Connect(handlePlayerAdded)

-- 初始化耗时可能导致错过 PlayerAdded，这里补处理已在服务器中的玩家
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(handlePlayerAdded, player)
end

Players.PlayerRemoving:Connect(handlePlayerRemoving)
