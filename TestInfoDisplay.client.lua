--[[
脚本名称: TestInfoDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/TestInfoDisplay
版本: V1.7
职责: 测试UI显示统计数据
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local modules = ReplicatedStorage:WaitForChild("Modules")
local FormatHelper = require(modules:WaitForChild("FormatHelper"))

local testGui = playerGui:WaitForChild("TestInfo", 10)
if not testGui then
	warn("[TestInfoDisplay] TestInfo not found")
	return
end

local frame = testGui:WaitForChild("Frame", 10)
if not frame then
	warn("[TestInfoDisplay] Frame not found")
	return
end

local capsuleLabel = frame:WaitForChild("CapsuleTotal", 10)
local speedLabel = frame:WaitForChild("OutoutSpeed", 10)
local timeLabel = frame:WaitForChild("TimeTotal", 10)
if not capsuleLabel or not speedLabel or not timeLabel then
	warn("[TestInfoDisplay] Label missing")
	return
end

local function formatTime(seconds)
	local total = math.max(0, tonumber(seconds) or 0)
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local secs = math.floor(total % 60)
	return string.format("%d:%02d:%02d", hours, minutes, secs)
end

local function refreshCapsuleTotal()
	local total = tonumber(player:GetAttribute("CapsuleOpenTotal")) or 0
	capsuleLabel.Text = tostring(math.floor(total))
end

local function refreshOutputSpeed()
	local speed = tonumber(player:GetAttribute("OutputSpeed")) or 0
	local speedText = FormatHelper.FormatCoinsShort(speed, true)
	speedLabel.Text = string.format("%s/S", speedText)
end

local function refreshTimeTotal()
	timeLabel.Text = formatTime(player:GetAttribute("TotalPlayTime"))
end

refreshCapsuleTotal()
refreshOutputSpeed()
refreshTimeTotal()

player:GetAttributeChangedSignal("CapsuleOpenTotal"):Connect(refreshCapsuleTotal)
player:GetAttributeChangedSignal("OutputSpeed"):Connect(refreshOutputSpeed)
player:GetAttributeChangedSignal("TotalPlayTime"):Connect(refreshTimeTotal)
