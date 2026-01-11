--[[
脚本名称: CoinDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/CoinDisplay
版本: V1.7
职责: 显示玩家金币数值
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local modules = ReplicatedStorage:WaitForChild("Modules")
local FormatHelper = require(modules:WaitForChild("FormatHelper"))

local mainGui = playerGui:WaitForChild("MainGui", 10)
if not mainGui then
	warn("[CoinDisplay] MainGui not found")
	return
end

local coinLabel = mainGui:WaitForChild("CoinNum", 10)
if not coinLabel then
	warn("[CoinDisplay] CoinNum not found")
	return
end

local function formatCoins(value)
	local num = tonumber(value) or 0
	return FormatHelper.FormatCoinsShort(num, true)
end

local function refresh()
	coinLabel.Text = formatCoins(player:GetAttribute("Coins"))
end

refresh()
player:GetAttributeChangedSignal("Coins"):Connect(refresh)
