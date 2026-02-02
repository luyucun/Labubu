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
local GuiResolver = require(modules:WaitForChild("GuiResolver"))

local function resolveCoinLabel()
	local mainGui = GuiResolver.FindLayer(playerGui, { "MainGui", "MainGUI", "Main", "MainUI" }, {
		"CoinNum",
		"CoinBuff",
		"Bag",
		"Index",
		"Home",
	})
	if mainGui then
		local label = GuiResolver.FindDescendant(mainGui, "CoinNum", "TextLabel")
		if label then
			return label
		end
	end
	return GuiResolver.FindDescendant(playerGui, "CoinNum", "TextLabel")
end

-- 角色生成后StarterGui才会复制到PlayerGui，先等待避免误报
if not player.Character then
	player.CharacterAdded:Wait()
end

GuiResolver.WaitForLayer(playerGui, { "MainGui", "MainGUI", "Main", "MainUI" }, {
	"CoinNum",
	"CoinBuff",
	"Bag",
	"Index",
	"Home",
}, 60)

local coinLabel = resolveCoinLabel()
local deadline = os.clock() + 30
while not coinLabel and os.clock() < deadline do
	task.wait(0.2)
	coinLabel = resolveCoinLabel()
end
if not coinLabel then
	warn("[CoinDisplay] CoinNum not found after waiting for UI")
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
