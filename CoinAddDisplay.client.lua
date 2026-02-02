--[[
脚本名称: CoinAddDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/CoinAddDisplay
版本: V1.0
职责: CoinAdd按钮显示/数值刷新/购买请求
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

local function buildCoinAddEntries()
	local list = config.CoinAddProducts
	if type(list) ~= "table" then
		return {}
	end
	local entries = {}
	for _, entry in ipairs(list) do
		if type(entry) == "table" then
			local buttonName = entry.ButtonName
			local productId = tonumber(entry.ProductId)
			local seconds = tonumber(entry.Seconds)
			if buttonName and buttonName ~= "" and productId and seconds and seconds > 0 then
				table.insert(entries, {
					ButtonName = buttonName,
					ProductId = productId,
					Seconds = seconds,
				})
			end
		end
	end
	return entries
end

local function resolveButton(root, name)
	if not root or type(name) ~= "string" then
		return nil
	end
	local button = GuiResolver.FindGuiButton(root, name)
	if button then
		return button
	end
	local node = root:FindFirstChild(name, true)
	if not node then
		return nil
	end
	if node:IsA("GuiButton") then
		return node
	end
	local childButton = node:FindFirstChildWhichIsA("GuiButton", true)
	if childButton and childButton:IsA("GuiButton") then
		return childButton
	end
	return nil
end

local function resolveNumberLabel(button)
	if not button then
		return nil
	end
	local node = button:FindFirstChild("Number", true)
	if not node then
		return nil
	end
	if node:IsA("TextLabel") then
		return node
	end
	local label = node:FindFirstChildWhichIsA("TextLabel", true)
	if label and label:IsA("TextLabel") then
		return label
	end
	return nil
end

local entries = buildCoinAddEntries()
if #entries == 0 then
	warn("[CoinAddDisplay] CoinAddProducts missing in GameConfig")
end

local buttons = {}
for _, entry in ipairs(entries) do
	local button = nil
	if mainGui then
		button = resolveButton(mainGui, entry.ButtonName)
	end
	if not button then
		button = resolveButton(playerGui, entry.ButtonName)
	end
	if not button then
		warn(string.format("[CoinAddDisplay] %s button not found", tostring(entry.ButtonName)))
	else
		local numberLabel = resolveNumberLabel(button)
		if not numberLabel then
			warn(string.format("[CoinAddDisplay] %s Number label not found", tostring(entry.ButtonName)))
		end
		table.insert(buttons, {
			ButtonName = entry.ButtonName,
			Button = button,
			NumberLabel = numberLabel,
			ProductId = entry.ProductId,
			Seconds = entry.Seconds,
			LastClick = 0,
		})
	end
end

if #buttons == 0 then
	warn("[CoinAddDisplay] No CoinAdd buttons found")
	return
end

local function getOutputSpeed()
	local speed = tonumber(player:GetAttribute("OutputSpeed")) or 0
	if speed < 0 then
		speed = 0
	end
	return speed
end

local function calcReward(speed, seconds)
	local coins = (tonumber(speed) or 0) * (tonumber(seconds) or 0)
	if coins < 0 then
		coins = 0
	end
	return math.ceil(coins - 1e-9)
end

local function formatCoins(value)
	return FormatHelper.FormatCoinsShort(tonumber(value) or 0, true)
end

local function setButtonVisible(button, visible)
	if not button or not button:IsA("GuiObject") then
		return
	end
	button.Visible = visible
	if button:IsA("GuiButton") then
		button.Active = visible
		button.AutoButtonColor = visible
	end
end

local minSpeed = tonumber(config.CoinAddMinOutputSpeed)
if not minSpeed or minSpeed < 0 then
	minSpeed = 0
end

local function refresh()
	local speed = getOutputSpeed()
	local canShow = speed >= minSpeed
	for _, item in ipairs(buttons) do
		setButtonVisible(item.Button, canShow)
		if item.NumberLabel then
			local reward = calcReward(speed, item.Seconds)
			item.NumberLabel.Text = formatCoins(reward)
		end
	end
end

local CLICK_COOLDOWN = 0.5

for _, item in ipairs(buttons) do
	if item.Button and item.Button:IsA("GuiButton") then
		item.Button.Activated:Connect(function()
			if not coinPurchaseEvent then
				return
			end
			if not item.Button.Visible or not item.Button.Active then
				return
			end
			local now = os.clock()
			if now - (item.LastClick or 0) < CLICK_COOLDOWN then
				return
			end
			item.LastClick = now
			coinPurchaseEvent:FireServer(item.ProductId)
		end)
	end
end

refresh()
player:GetAttributeChangedSignal("OutputSpeed"):Connect(refresh)
