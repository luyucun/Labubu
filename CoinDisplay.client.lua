--[[
脚本名称: CoinDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/CoinDisplay
版本: V1.2
职责: 显示玩家金币数值
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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
	local sign = ""
	if num < 0 then
		sign = "-"
		num = math.abs(num)
	end

	local str = tostring(math.floor(num))
	local formatted = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	formatted = formatted:gsub("^,", "")
	return "$" .. sign .. formatted
end

local function refresh()
	coinLabel.Text = formatCoins(player:GetAttribute("Coins"))
end

refresh()
player:GetAttributeChangedSignal("Coins"):Connect(refresh)
