--[[
脚本名称: CoinAddDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/CoinAddDisplay
版本: V1.0
职责: 主界面付费买币按钮显示/数值刷新与购买请求
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local modules = ReplicatedStorage:WaitForChild("Modules")
local FormatHelper = require(modules:WaitForChild("FormatHelper"))
local GuiResolver = require(modules:WaitForChild("GuiResolver"))

local function getCoinPurchaseEvent()
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		return nil
	end
	local labubuEvents = eventsFolder:WaitForChild("LabubuEvents", 10)
	if not labubuEvents then
		return nil
	end
	local event = labubuEvents:WaitForChild("RequestCoinPurchase", 10)
	if event and event:IsA("RemoteEvent") then
		return event
	end
	return nil
end

local coinPurchaseEvent = getCoinPurchaseEvent()
if not coinPurchaseEvent then
	warn("[CoinAddDisplay] RequestCoinPurchase event not found")
end

local products = config.CoinAddProducts
if type(products) ~= "table" then
	warn("[CoinAddDisplay] CoinAddProducts missing in GameConfig")
	return
end

local mainGui = GuiResolver.WaitForLayer(playerGui, { "MainGui", "MainGUI", "Main", "MainUI" }, {
	"CoinNum",
	"CoinBuff",
	"Bag",
	"Index",
	"Home",
}, 30)
if not mainGui then
	warn("[CoinAddDisplay] MainGui not found")
end

local entries = {}
local CLICK_COOLDOWN = 0.5

for _, entry in ipairs(products) do
	local buttonName = entry.ButtonName
	local productId = tonumber(entry.ProductId)
	local seconds = tonumber(entry.Seconds)
	if buttonName and productId and seconds and seconds > 0 then
		local button = nil
		if mainGui then
			button = GuiResolver.FindGuiButton(mainGui, buttonName)
		end
		if not button then
			button = GuiResolver.FindGuiButton(playerGui, buttonName)
		end
		if not button or not button:IsA("GuiButton") then
			warn(string.format("[CoinAddDisplay] %s not found", tostring(buttonName)))
		else
			local numberLabel = GuiResolver.FindDescendant(button, "Number", "TextLabel")
			local record = {
				Button = button,
				NumberLabel = numberLabel,
				ProductId = productId,
				Seconds = seconds,
				LastClick = 0,
			}
			table.insert(entries, record)
			if coinPurchaseEvent then
				button.Activated:Connect(function()
					local now = os.clock()
					if now - record.LastClick < CLICK_COOLDOWN then
						return
					end
					record.LastClick = now
					coinPurchaseEvent:FireServer(productId)
				end)
			end
		end
	end
end

if #entries == 0 then
	warn("[CoinAddDisplay] No valid CoinAdd buttons configured")
end

local minSpeed = tonumber(config.CoinAddMinOutputSpeed) or 20

local function formatCoins(value)
	local num = tonumber(value) or 0
	if num < 0 then
		num = 0
	end
	return FormatHelper.FormatCoinsShort(num, true)
end

local function refresh()
	local speed = tonumber(player:GetAttribute("OutputSpeed")) or 0
	if speed < 0 then
		speed = 0
	end
	local visible = speed >= minSpeed
	for _, record in ipairs(entries) do
		if record.Button then
			record.Button.Visible = visible
		end
		if record.NumberLabel then
			record.NumberLabel.Text = formatCoins(speed * record.Seconds)
		end
	end
end

refresh()
player:GetAttributeChangedSignal("OutputSpeed"):Connect(refresh)
