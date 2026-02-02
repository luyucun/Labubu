--[[
脚本名称: PotionsDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/PotionsDisplay
版本: V1.0
职责: 药水界面显示、倒计时刷新与购买/使用请求
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local configFolder = ReplicatedStorage:WaitForChild("Config")
local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local PotionConfig = require(configFolder:WaitForChild("PotionConfig"))
local GuiResolver = require(modulesFolder:WaitForChild("GuiResolver"))

local function isTextObject(obj)
	return obj and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox"))
end

local function ensureLabubuEvents()
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		return nil
	end
	return eventsFolder:WaitForChild("LabubuEvents", 10)
end

local labubuEvents = ensureLabubuEvents()
if not labubuEvents then
	warn("[PotionsDisplay] LabubuEvents not found")
	return
end

local requestPotionPurchaseEvent = labubuEvents:WaitForChild("RequestPotionPurchase", 10)
local requestPotionActionEvent = labubuEvents:WaitForChild("RequestPotionAction", 10)
local pushPotionStateEvent = labubuEvents:WaitForChild("PushPotionState", 10)

if not pushPotionStateEvent then
	warn("[PotionsDisplay] PushPotionState event not found")
	return
end

local mainGui = GuiResolver.WaitForLayer(playerGui, { "MainGui", "MainGUI", "Main", "MainUI" }, {
	"Potion",
	"CoinNum",
}, 30)
if not mainGui then
	warn("[PotionsDisplay] MainGui not found")
end

local function resolvePotionButton()
	local root = mainGui or playerGui
	if not root then
		return nil
	end
	local button = GuiResolver.FindGuiButton(root, "Potion")
	if button then
		return button
	end
	local candidate = root:FindFirstChild("Potion", true)
	if candidate then
		if candidate:IsA("GuiButton") then
			return candidate
		end
		local nested = candidate:FindFirstChildWhichIsA("GuiButton", true)
		if nested then
			return nested
		end
	end
	return GuiResolver.FindGuiButton(root, "Option")
end

local optionButton = resolvePotionButton()
if not optionButton then
	warn("[PotionsDisplay] MainGui.Potion not found")
end

local potionRoot = nil
if mainGui then
	potionRoot = mainGui:FindFirstChild("Potion", true) or mainGui:FindFirstChild("Option", true)
end

local function resolveOptionTimeLabel()
	local label = nil
	if optionButton then
		label = GuiResolver.FindDescendant(optionButton, "Time", "TextLabel")
		if isTextObject(label) then
			return label
		end
	end
	if potionRoot then
		label = GuiResolver.FindDescendant(potionRoot, "Time", "TextLabel")
		if isTextObject(label) then
			return label
		end
		label = potionRoot:FindFirstChild("Time", true)
		if isTextObject(label) then
			return label
		end
	end
	if mainGui then
		local node = mainGui:FindFirstChild("Potion", true) or mainGui:FindFirstChild("Option", true)
		if node then
			label = node:FindFirstChild("Time", true)
			if isTextObject(label) then
				return label
			end
		end
		for _, obj in ipairs(mainGui:GetDescendants()) do
			if obj.Name == "Time" and isTextObject(obj) then
				return obj
			end
		end
	end
	return nil
end

local optionTimeLabel = resolveOptionTimeLabel()
local defaultOptionTimeText = optionTimeLabel and optionTimeLabel.Text or ""

local potionsGui = GuiResolver.WaitForLayer(playerGui, { "Potions", "PotionsGui", "PotionsGUI" }, {
	"Buff1Bg",
	"Buff2Bg",
	"Buff3Bg",
	"DiamondNum",
}, 30)
if not potionsGui then
	warn("[PotionsDisplay] Potions gui not found")
	return
end

local potionsBg = potionsGui:FindFirstChild("Bg", true)
if not potionsBg then
	potionsBg = potionsGui:WaitForChild("Bg", 10)
end
if not potionsBg then
	warn("[PotionsDisplay] Potions.Bg not found")
	return
end

if potionsGui:IsA("LayerCollector") then
	potionsGui.Enabled = true
end
potionsBg.Visible = false

local title = potionsBg:FindFirstChild("Title", true)
local closeButton = title and title:FindFirstChild("CloseButton", true)
if closeButton and not closeButton:IsA("GuiButton") then
	closeButton = closeButton:FindFirstChildWhichIsA("GuiButton", true)
end

local diamondNumLabel = potionsBg:FindFirstChild("DiamondNum", true)
if diamondNumLabel and not diamondNumLabel:IsA("TextLabel") then
	diamondNumLabel = nil
end

local function formatMinutesSeconds(seconds)
	local total = math.max(0, math.floor(seconds or 0))
	local minutes = math.floor(total / 60)
	local secs = total % 60
	return string.format("%d:%02d", minutes, secs)
end

local function formatHoursMinutesSeconds(seconds)
	local total = math.max(0, math.floor(seconds or 0))
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local secs = total % 60
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local potionState = {
	Counts = {},
	EndTimes = {},
	ServerTimeOffset = 0,
}

local function getServerTime()
	return os.time() + potionState.ServerTimeOffset
end

local function getRemainingSeconds(potionId)
	local endTime = tonumber(potionState.EndTimes[potionId] or potionState.EndTimes[tostring(potionId)]) or 0
	local remaining = endTime - getServerTime()
	if remaining < 0 then
		return 0
	end
	return remaining
end

local function getCount(potionId)
	local value = potionState.Counts[potionId]
	if value == nil then
		value = potionState.Counts[tostring(potionId)]
	end
	return math.max(0, tonumber(value) or 0)
end

local entries = {}

local function resolveGuiButton(node)
	if not node then
		return nil
	end
	if node:IsA("GuiButton") then
		return node
	end
	return node:FindFirstChildWhichIsA("GuiButton", true)
end

local function resolveBuffFrame(tier)
	return potionsBg:FindFirstChild(string.format("Buff%dBg", tier), true)
end

local function buildEntries()
	local list = {}
	for _, info in ipairs(PotionConfig.GetAll()) do
		table.insert(list, info)
	end
	table.sort(list, function(a, b)
		local ta = tonumber(a.Tier) or tonumber(a.Id) or 0
		local tb = tonumber(b.Tier) or tonumber(b.Id) or 0
		return ta < tb
	end)

	for _, info in ipairs(list) do
		local tier = tonumber(info.Tier) or 0
		local frame = resolveBuffFrame(tier)
		if frame then
			local countDownLabel = frame:FindFirstChild("CountDownTime", true)
			if countDownLabel and not countDownLabel:IsA("TextLabel") then
				countDownLabel = nil
			end
			local rbxButton = resolveGuiButton(frame:FindFirstChild("RbxButton", true))
			local diamondButton = resolveGuiButton(frame:FindFirstChild("DiamondButton", true))
			local diamondIcon = diamondButton and diamondButton:FindFirstChild("DiamondIcon", true) or frame:FindFirstChild("DiamondIcon", true)
			if diamondIcon and not diamondIcon:IsA("GuiObject") then
				diamondIcon = nil
			end
			local diamondPrice = diamondButton and diamondButton:FindFirstChild("DiamondPrice", true) or frame:FindFirstChild("DiamondPrice", true)
			if diamondPrice and not diamondPrice:IsA("TextLabel") then
				diamondPrice = nil
			end
			local useText = diamondButton and diamondButton:FindFirstChild("UseText", true) or frame:FindFirstChild("UseText", true)
			if useText and not useText:IsA("TextLabel") then
				useText = nil
			end

			entries[info.Id] = {
				Info = info,
				Frame = frame,
				CountDownLabel = countDownLabel,
				RbxButton = rbxButton,
				DiamondButton = diamondButton,
				DiamondIcon = diamondIcon,
				DiamondPrice = diamondPrice,
				UseText = useText,
				LastClick = 0,
			}
		end
	end
end

buildEntries()

local function setOptionTimeText(text, visible)
	if not optionTimeLabel or not optionTimeLabel.Parent then
		optionTimeLabel = resolveOptionTimeLabel()
	end
	if not optionTimeLabel then
		return
	end
	optionTimeLabel.Text = text or ""
	if visible ~= nil then
		optionTimeLabel.Visible = visible == true
	end
end

local function refreshDiamondNum()
	if not diamondNumLabel then
		return
	end
	local value = tonumber(player:GetAttribute("Diamonds")) or 0
	diamondNumLabel.Text = tostring(math.floor(value))
end

local function refreshEntry(entry)
	if not entry then
		return
	end
	local info = entry.Info
	local count = getCount(info.Id)
	local remaining = getRemainingSeconds(info.Id)

	if entry.CountDownLabel and entry.CountDownLabel:IsA("TextLabel") then
		if remaining > 0 then
			entry.CountDownLabel.Visible = true
			entry.CountDownLabel.Text = formatHoursMinutesSeconds(remaining)
		else
			entry.CountDownLabel.Visible = false
		end
	end

	if entry.DiamondPrice and entry.DiamondPrice:IsA("TextLabel") then
		entry.DiamondPrice.Text = tostring(info.DiamondPrice or 0)
	end

	local hasPotion = count >= 1
	if entry.DiamondIcon and entry.DiamondIcon:IsA("GuiObject") then
		entry.DiamondIcon.Visible = not hasPotion
	end
	if entry.DiamondPrice and entry.DiamondPrice:IsA("TextLabel") then
		entry.DiamondPrice.Visible = not hasPotion
	end
	if entry.UseText and entry.UseText:IsA("TextLabel") then
		entry.UseText.Visible = hasPotion
		if hasPotion then
			entry.UseText.Text = string.format("Use (%d)", count)
		end
	end
end

local function refreshOptionCountdown()
	local maxRemaining = 0
	for _, info in ipairs(PotionConfig.GetAll()) do
		local remaining = getRemainingSeconds(info.Id)
		if remaining > maxRemaining then
			maxRemaining = remaining
		end
	end
	if maxRemaining > 0 then
		setOptionTimeText(formatMinutesSeconds(maxRemaining), true)
	else
		setOptionTimeText("", false)
	end
end

local function refreshAll()
	for _, entry in pairs(entries) do
		refreshEntry(entry)
	end
	refreshOptionCountdown()
	refreshDiamondNum()
end

local function bindButtons()
	for _, entry in pairs(entries) do
		if entry.RbxButton and requestPotionPurchaseEvent then
			entry.RbxButton.Activated:Connect(function()
				local now = os.clock()
				if now - entry.LastClick < 0.2 then
					return
				end
				entry.LastClick = now
				requestPotionPurchaseEvent:FireServer(entry.Info.Id)
			end)
		end
		if entry.DiamondButton and requestPotionActionEvent then
			entry.DiamondButton.Activated:Connect(function()
				local now = os.clock()
				if now - entry.LastClick < 0.2 then
					return
				end
				entry.LastClick = now
				local count = getCount(entry.Info.Id)
				if count >= 1 then
					requestPotionActionEvent:FireServer(entry.Info.Id, "Use")
				else
					requestPotionActionEvent:FireServer(entry.Info.Id, "Buy")
				end
			end)
		end
	end
end

bindButtons()

if optionButton and optionButton:IsA("GuiButton") then
	optionButton.Activated:Connect(function()
		potionsBg.Visible = true
	end)
end

if closeButton and closeButton:IsA("GuiButton") then
	closeButton.Activated:Connect(function()
		potionsBg.Visible = false
	end)
end

pushPotionStateEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if type(payload.Counts) == "table" then
		potionState.Counts = payload.Counts
	end
	if type(payload.EndTimes) == "table" then
		potionState.EndTimes = payload.EndTimes
	end
	if payload.ServerTime then
		potionState.ServerTimeOffset = (tonumber(payload.ServerTime) or os.time()) - os.time()
	end
	refreshAll()
end)

refreshAll()
player:GetAttributeChangedSignal("Diamonds"):Connect(refreshDiamondNum)

task.spawn(function()
	while true do
		refreshAll()
		task.wait(1)
	end
end)
