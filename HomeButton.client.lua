--[[
脚本名称: HomeButton
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/HomeButton
版本: V1.0
职责: 主界面Home按钮请求传送回基地
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local modules = ReplicatedStorage:WaitForChild("Modules")
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
if mainGui then
	homeButton = GuiResolver.FindGuiButton(mainGui, "Home")
end
if not homeButton then
	homeButton = GuiResolver.FindGuiButton(playerGui, "Home")
end
if not homeButton or not homeButton:IsA("GuiButton") then
	warn("[HomeButton] MainGui.Home not found")
	return
end

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
