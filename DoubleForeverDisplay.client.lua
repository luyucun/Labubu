--[[
脚本名称: DoubleForeverDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/DoubleForeverDisplay
版本: V1.0
职责: DoubleForever按钮倍率显示与购买请求
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local modules = ReplicatedStorage:WaitForChild("Modules")
local GuiResolver = require(modules:WaitForChild("GuiResolver"))

local function getOutputMultiplierEvent()
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		return nil
	end
	local labubuEvents = eventsFolder:WaitForChild("LabubuEvents", 10)
	if not labubuEvents then
		return nil
	end
	local event = labubuEvents:WaitForChild("RequestOutputMultiplierPurchase", 10)
	if event and event:IsA("RemoteEvent") then
		return event
	end
	return nil
end

local outputMultiplierEvent = getOutputMultiplierEvent()
if not outputMultiplierEvent then
	warn("[DoubleForeverDisplay] RequestOutputMultiplierPurchase event not found")
end

local function buildProducts()
	local list = config.OutputMultiplierProducts
	if type(list) ~= "table" then
		return {}
	end
	local products = {}
	for _, entry in ipairs(list) do
		if type(entry) == "table" then
			local multiplier = tonumber(entry.Multiplier)
			local productId = tonumber(entry.ProductId)
			local price = tonumber(entry.Price)
			if multiplier and productId and price then
				table.insert(products, {
					Multiplier = multiplier,
					ProductId = productId,
					Price = price,
				})
			end
		end
	end
	table.sort(products, function(a, b)
		return a.Multiplier < b.Multiplier
	end)
	return products
end

local products = buildProducts()
if #products == 0 then
	warn("[DoubleForeverDisplay] OutputMultiplierProducts missing in GameConfig")
end

local mainGui = GuiResolver.WaitForLayer(playerGui, { "MainGui", "MainGUI", "Main", "MainUI" }, {
	"CoinNum",
	"CoinBuff",
	"Bag",
	"Index",
	"Home",
	"DoubleForever",
}, 30)
if not mainGui then
	warn("[DoubleForeverDisplay] MainGui not found")
end

local button = nil
if mainGui then
	button = GuiResolver.FindGuiButton(mainGui, "DoubleForever")
end
if not button then
	button = GuiResolver.FindGuiButton(playerGui, "DoubleForever")
end
if not button or not button:IsA("GuiButton") then
	warn("[DoubleForeverDisplay] DoubleForever button not found")
	return
end

local nameLabel = GuiResolver.FindDescendant(button, "Name", "TextLabel")
local priceLabel = GuiResolver.FindDescendant(button, "Price", "TextLabel")

local function getCurrentMultiplier()
	local value = tonumber(player:GetAttribute("OutputMultiplier")) or 1
	if value < 1 then
		value = 1
	end
	return math.floor(value)
end

local function getNextProduct(currentMultiplier)
	for _, entry in ipairs(products) do
		if entry.Multiplier > currentMultiplier then
			return entry
		end
	end
	return nil
end

local function formatPriceText(price)
	local text = tostring(math.floor(price))
	local current = priceLabel and priceLabel.Text or ""
	if current:find("R%$") then
		return "R$" .. text
	end
	if current:find("%$") then
		return "$" .. text
	end
	return text
end

local function setButtonEnabled(enabled)
	button.Active = enabled
	button.AutoButtonColor = enabled
end

local function refresh()
	local currentMultiplier = getCurrentMultiplier()
	local nextProduct = getNextProduct(currentMultiplier)
	if nextProduct then
		if nameLabel then
			nameLabel.Text = "CashX" .. tostring(nextProduct.Multiplier)
		end
		if priceLabel then
			priceLabel.Text = formatPriceText(nextProduct.Price)
		end
		setButtonEnabled(true)
	else
		if nameLabel then
			nameLabel.Text = "CashX" .. tostring(currentMultiplier)
		end
		if priceLabel then
			priceLabel.Text = "MAX"
		end
		setButtonEnabled(false)
	end
end

local lastClick = 0
local CLICK_COOLDOWN = 0.5

button.Activated:Connect(function()
	if not outputMultiplierEvent then
		return
	end
	if not button.Active then
		return
	end
	local now = os.clock()
	if now - lastClick < CLICK_COOLDOWN then
		return
	end
	lastClick = now
	outputMultiplierEvent:FireServer()
end)

refresh()
player:GetAttributeChangedSignal("OutputMultiplier"):Connect(refresh)
