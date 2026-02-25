--[[
脚本名称: HomeButton
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/HomeButton
版本: V1.0
职责: 主界面Home按钮请求传送回基地
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local configFolder = ReplicatedStorage:WaitForChild("Config")
local modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(configFolder:WaitForChild("GameConfig"))
local GuiResolver = require(modules:WaitForChild("GuiResolver"))

local mainGui = GuiResolver.WaitForLayer(playerGui, { "MainGui", "MainGUI", "Main", "MainUI" }, {
	"CoinNum",
	"CoinBuff",
	"Bag",
	"Index",
	"Home",
}, 30)
if not mainGui then
	warn("[HomeButton] MainGui not found")
end

local homeButton = nil
local homeRoot = nil
if mainGui then
	homeButton = GuiResolver.FindGuiButton(mainGui, "Home")
	local node = mainGui:FindFirstChild("Home", true)
	if node and node:IsA("GuiObject") then
		homeRoot = node
	end
end
if not homeButton then
	homeButton = GuiResolver.FindGuiButton(playerGui, "Home")
end
if not homeRoot then
	local node = playerGui:FindFirstChild("Home", true)
	if node and node:IsA("GuiObject") then
		homeRoot = node
	end
end
if not homeButton or not homeButton:IsA("GuiButton") then
	warn("[HomeButton] MainGui.Home not found")
	return
end
local homeVisibleTarget = homeRoot or homeButton

local function getGoHomeEvent()
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		return nil
	end
	local labubuEvents = eventsFolder:WaitForChild("LabubuEvents", 10)
	if not labubuEvents then
		return nil
	end
	local event = labubuEvents:WaitForChild("GoHome", 10)
	if event and event:IsA("RemoteEvent") then
		return event
	end
	return nil
end

local goHomeEvent = getGoHomeEvent()
if not goHomeEvent then
	warn("[HomeButton] GoHome event not found")
	return
end

local lastRequest = 0
local REQUEST_COOLDOWN = 0.5

homeButton.Activated:Connect(function()
	local now = os.clock()
	if now - lastRequest < REQUEST_COOLDOWN then
		return
	end
	lastRequest = now
	goHomeEvent:FireServer()
end)

local idleFloor = nil
local HOME_CHECK_INTERVAL = 0.2
local HOME_Y_PADDING = 8
local lastInHome = nil

local function formatHomeName(index)
	return string.format("%s%02d", GameConfig.HomeSlotPrefix, index)
end

local function getHomeFolder()
	local homeRootFolder = Workspace:FindFirstChild(GameConfig.HomeFolderName)
	if not homeRootFolder then
		return nil
	end
	local slotIndex = player:GetAttribute("HomeSlot")
	if not slotIndex then
		return nil
	end
	return homeRootFolder:FindFirstChild(formatHomeName(slotIndex))
end

local function resolveIdleFloor()
	if idleFloor and idleFloor.Parent then
		return idleFloor
	end
	local homeFolder = getHomeFolder()
	if not homeFolder then
		idleFloor = nil
		return nil
	end
	local base = homeFolder:FindFirstChild("Base") or homeFolder:FindFirstChild("Base", true)
	local floor = nil
	if base then
		floor = base:FindFirstChild("IdleFloor", true)
	end
	if not floor then
		floor = homeFolder:FindFirstChild("IdleFloor", true)
	end
	if floor and (floor:IsA("BasePart") or floor:IsA("Model")) then
		idleFloor = floor
		return idleFloor
	end
	idleFloor = nil
	return nil
end

local function isPlayerInIdleFloor()
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local floor = resolveIdleFloor()
	if not floor then
		return false
	end
	local cf, size
	if floor:IsA("BasePart") then
		cf = floor.CFrame
		size = floor.Size
	else
		local ok, cframe, extents = pcall(function()
			return floor:GetBoundingBox()
		end)
		if not ok then
			return false
		end
		cf = cframe
		size = extents
	end
	if not cf or not size then
		return false
	end
	local localPos = cf:PointToObjectSpace(root.Position)
	local half = size * 0.5
	local withinX = math.abs(localPos.X) <= half.X
	local withinZ = math.abs(localPos.Z) <= half.Z
	local withinY = math.abs(localPos.Y) <= (half.Y + HOME_Y_PADDING)
	return withinX and withinZ and withinY
end

local function updateHomeVisibility()
	local inHome = isPlayerInIdleFloor()
	if inHome == lastInHome then
		return
	end
	lastInHome = inHome
	if homeVisibleTarget and homeVisibleTarget:IsA("GuiObject") then
		homeVisibleTarget.Visible = not inHome
	end
end

player:GetAttributeChangedSignal("HomeSlot"):Connect(function()
	idleFloor = nil
	lastInHome = nil
end)

task.spawn(function()
	while true do
		updateHomeVisibility()
		task.wait(HOME_CHECK_INTERVAL)
	end
end)
