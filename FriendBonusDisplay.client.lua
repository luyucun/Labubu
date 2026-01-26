--[[
脚本名称: FriendBonusDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/FriendBonusDisplay
版本: V1.0
职责: 好友加成文本显示与更新
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
	warn("[FriendBonusDisplay] MainGui not found")
end

local buffLabel = nil
if mainGui then
	buffLabel = GuiResolver.FindDescendant(mainGui, "CoinBuff", "TextLabel")
end
if not buffLabel then
	buffLabel = GuiResolver.FindDescendant(playerGui, "CoinBuff", "TextLabel")
end
if not buffLabel or not buffLabel:IsA("TextLabel") then
	warn("[FriendBonusDisplay] CoinBuff not found")
	return
end

buffLabel.RichText = true

local function getPercent()
	local value = tonumber(player:GetAttribute("FriendBonusPercent")) or 0
	if value < 0 then
		value = 0
	end
	return math.floor(value + 0.0001)
end

local function refresh()
	local percent = getPercent()
	buffLabel.Text = string.format("Friends Bonus: <font color=\"#FFFF00\">+%d%%</font>", percent)
end

refresh()
player:GetAttributeChangedSignal("FriendBonusPercent"):Connect(refresh)
