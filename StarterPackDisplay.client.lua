--[[
Script Name: StarterPackDisplay
Script Type: LocalScript
Script Location: StarterPlayer/StarterPlayerScripts/UI/StarterPackDisplay
Version: V1.0
Responsibility: Starter pack UI display, purchase request, claim popup, price gradient
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local configFolder = ReplicatedStorage:WaitForChild("Config")
local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local CapsuleConfig = require(configFolder:WaitForChild("CapsuleConfig"))
local AudioManager = require(modulesFolder:WaitForChild("AudioManager"))
local GuiResolver = require(modulesFolder:WaitForChild("GuiResolver"))

local function ensureLabubuEvents()
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		return nil
	end
	return eventsFolder:WaitForChild("LabubuEvents", 10)
end

local labubuEvents = ensureLabubuEvents()
if not labubuEvents then
	warn("[StarterPackDisplay] LabubuEvents not found")
	return
end

local requestPurchaseEvent = labubuEvents:WaitForChild("RequestStarterPackPurchase", 10)
local pushStateEvent = labubuEvents:WaitForChild("PushStarterPackState", 10)
local pushRewardEvent = labubuEvents:WaitForChild("PushStarterPackReward", 10)

local mainGui = GuiResolver.WaitForLayer(playerGui, { "MainGui", "MainGUI", "Main", "MainUI" }, {
	"StarterPack",
}, 30)

local function resolveStarterPackRoot()
	if not mainGui then
		return nil
	end
	local node = mainGui:FindFirstChild("StarterPack", true)
	if node and node:IsA("GuiObject") then
		return node
	end
	return nil
end

local starterPackRoot = resolveStarterPackRoot()
local starterPackButton = nil
if starterPackRoot then
	if starterPackRoot:IsA("GuiButton") then
		starterPackButton = starterPackRoot
	else
		starterPackButton = starterPackRoot:FindFirstChildWhichIsA("GuiButton", true)
	end
end

local STARTER_PACK_GUI_NAMES = { "StarterPack", "StarterPackGui", "StarterPackGUI" }

local function resolveStarterPackGui()
	for _, name in ipairs(STARTER_PACK_GUI_NAMES) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("LayerCollector") then
			return gui
		end
	end
	local gui = GuiResolver.WaitForLayer(playerGui, STARTER_PACK_GUI_NAMES, nil, 30)
	if gui and gui:IsA("LayerCollector") then
		return gui
	end
	return nil
end

local starterPackGui = resolveStarterPackGui()
if not starterPackGui then
	warn("[StarterPackDisplay] StarterPack gui not found")
	return
end

local starterPackBg = starterPackGui:FindFirstChild("Bg", true)
if not starterPackBg then
	starterPackBg = starterPackGui:WaitForChild("Bg", 10)
end
if not starterPackBg or not starterPackBg:IsA("GuiObject") then
	warn("[StarterPackDisplay] StarterPack.Bg not found")
	return
end

if starterPackGui:IsA("LayerCollector") then
	starterPackGui.Enabled = true
end

local closeButton = starterPackBg:FindFirstChild("CloseButton", true)
if closeButton and not closeButton:IsA("GuiButton") then
	closeButton = closeButton:FindFirstChildWhichIsA("GuiButton", true)
end

local buyButton = starterPackBg:FindFirstChild("Buy", true)
if buyButton and not buyButton:IsA("GuiButton") then
	buyButton = buyButton:FindFirstChildWhichIsA("GuiButton", true)
end

starterPackBg.Visible = false

local purchased = false

local function applyPurchasedState()
	if starterPackRoot then
		starterPackRoot.Visible = not purchased
	end
	if purchased then
		starterPackBg.Visible = false
	end
end

local function connectButton(button, callback)
	if not button or not button:IsA("GuiButton") then
		return
	end
	button.Activated:Connect(callback)
end

if starterPackButton then
	connectButton(starterPackButton, function()
		if purchased then
			return
		end
		starterPackBg.Visible = true
	end)
end

if closeButton then
	connectButton(closeButton, function()
		starterPackBg.Visible = false
	end)
end

if buyButton and requestPurchaseEvent then
	connectButton(buyButton, function()
		if purchased then
			return
		end
		requestPurchaseEvent:FireServer()
	end)
end

local function getCapsuleInfo(capsuleId)
	if type(CapsuleConfig.GetById) == "function" then
		return CapsuleConfig.GetById(capsuleId)
	end
	local list = CapsuleConfig.Capsules
	if type(list) ~= "table" and type(CapsuleConfig) == "table" then
		list = CapsuleConfig
	end
	if type(list) ~= "table" then
		return nil
	end
	for _, info in ipairs(list) do
		if info.Id == capsuleId then
			return info
		end
	end
	return nil
end

local claimTipsGui
local claimSuccessful
local lightBg
local itemListFrame
local itemTemplate
local claimTipsWarned = false

local function resolveClaimTips(waitSeconds)
	if not claimTipsGui or not claimTipsGui.Parent then
		if waitSeconds and waitSeconds > 0 then
			claimTipsGui = GuiResolver.WaitForLayer(playerGui, { "ClaimTipsGui", "ClaimTipsGUI" }, {
				"ClaimSuccessful",
				"LightBg",
			}, waitSeconds)
		else
			claimTipsGui = GuiResolver.FindLayer(playerGui, { "ClaimTipsGui", "ClaimTipsGUI" }, {
				"ClaimSuccessful",
				"LightBg",
			})
		end
	end
	if claimTipsGui and claimTipsGui.Parent then
		claimSuccessful = claimTipsGui:FindFirstChild("ClaimSuccessful", true)
		lightBg = claimTipsGui:FindFirstChild("LightBg", true)
		itemListFrame = claimSuccessful and claimSuccessful:FindFirstChild("ItemListFrame", true)
		itemTemplate = itemListFrame and itemListFrame:FindFirstChild("ItemTemplate", true)
			or claimSuccessful and claimSuccessful:FindFirstChild("ItemTemplate", true)

		if claimTipsGui:IsA("LayerCollector") then
			claimTipsGui.Enabled = true
		end
		if claimSuccessful and claimSuccessful:IsA("GuiObject") then
			claimSuccessful.Visible = false
		end
		if lightBg and lightBg:IsA("GuiObject") then
			lightBg.Visible = false
		end
		if itemTemplate and itemTemplate:IsA("GuiObject") then
			itemTemplate.Visible = false
		end
		return claimSuccessful ~= nil
	end
	if not claimTipsWarned then
		warn("[StarterPackDisplay] ClaimTipsGui not found")
		claimTipsWarned = true
	end
	return false
end

resolveClaimTips(0)

local claimCloseConn = nil
local claimCloseReady = false
local lightTween = nil

local function clearClaimItems()
	if not itemListFrame then
		return
	end
	for _, child in ipairs(itemListFrame:GetChildren()) do
		if child ~= itemTemplate then
			child:Destroy()
		end
	end
end

local function closeClaimTips()
	if claimCloseConn then
		claimCloseConn:Disconnect()
		claimCloseConn = nil
	end
	claimCloseReady = false
	if lightTween then
		lightTween:Cancel()
		lightTween = nil
	end
	if lightBg and lightBg:IsA("GuiObject") then
		lightBg.Visible = false
	end
	if claimSuccessful and claimSuccessful:IsA("GuiObject") then
		claimSuccessful.Visible = false
	end
	if itemTemplate and itemTemplate:IsA("GuiObject") then
		itemTemplate.Visible = false
	end
	clearClaimItems()
end

local function playClaimTips(rewards)
	if not claimSuccessful or not claimSuccessful.Parent then
		resolveClaimTips(5)
	end
	if not claimSuccessful or not claimSuccessful:IsA("GuiObject") then
		return
	end
	closeClaimTips()
	if claimTipsGui and claimTipsGui:IsA("LayerCollector") then
		claimTipsGui.Enabled = true
	end
	if AudioManager and AudioManager.PlaySfx then
		pcall(function()
			AudioManager.PlaySfx("RewardPopup")
		end)
	end
	claimSuccessful.Visible = true
	if itemTemplate and itemTemplate:IsA("GuiObject") then
		itemTemplate.Visible = false
	end
	if lightBg and lightBg:IsA("GuiObject") then
		lightBg.Visible = false
	end

	task.wait()
	local targetPos = claimSuccessful.Position
	local width = claimSuccessful.AbsoluteSize.X
	if width <= 0 then
		task.wait()
		width = claimSuccessful.AbsoluteSize.X
	end
	claimSuccessful.Position = UDim2.new(targetPos.X.Scale, targetPos.X.Offset - width - 20, targetPos.Y.Scale, targetPos.Y.Offset)
	local tween = TweenService:Create(claimSuccessful, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = targetPos,
	})
	tween:Play()
	tween.Completed:Wait()

	clearClaimItems()
	if itemTemplate and itemTemplate:IsA("GuiObject") then
		for _, reward in ipairs(rewards) do
			local clone = itemTemplate:Clone()
			clone.Visible = true
			local icon = clone:FindFirstChild("Icon", true)
			local number = clone:FindFirstChild("Number", true)
			local info = getCapsuleInfo(tonumber(reward.Id) or reward.Id)
			if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
				icon.Image = info and info.Icon or ""
			end
			if number and number:IsA("TextLabel") then
				number.Text = tostring(reward.Count or 0)
			end
			clone.Parent = itemListFrame or claimSuccessful
		end
	end

	if lightBg and lightBg:IsA("GuiObject") then
		lightBg.Visible = true
		lightBg.Rotation = 0
		lightTween = TweenService:Create(lightBg, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 360 })
		lightTween:Play()
	end

	task.delay(0.5, function()
		claimCloseReady = true
	end)

	claimCloseConn = UserInputService.InputBegan:Connect(function(_, processed)
		if processed or not claimCloseReady then
			return
		end
		closeClaimTips()
	end)
end

local function updateState(payload)
	if type(payload) ~= "table" then
		return
	end
	purchased = payload.Purchased == true
	applyPurchasedState()
end

if pushStateEvent then
	pushStateEvent.OnClientEvent:Connect(updateState)
end

if pushRewardEvent then
	pushRewardEvent.OnClientEvent:Connect(function(rewards)
		purchased = true
		applyPurchasedState()
		if type(rewards) ~= "table" then
			rewards = {}
		end
		playClaimTips(rewards)
	end)
end

player:GetAttributeChangedSignal("StarterPackPurchased"):Connect(function()
	purchased = player:GetAttribute("StarterPackPurchased") == true
	applyPurchasedState()
end)

purchased = player:GetAttribute("StarterPackPurchased") == true
applyPurchasedState()

local function setupPriceGradient()
	if not starterPackRoot then
		return
	end
	local priceLabel = starterPackRoot:FindFirstChild("Price", true)
	if not priceLabel or not priceLabel:IsA("GuiObject") then
		return
	end
	local gradient = priceLabel:FindFirstChildWhichIsA("UIGradient", true)
	if not gradient then
		return
	end
	gradient.Rotation = 0
	local tween = TweenService:Create(gradient, TweenInfo.new(2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
		Rotation = 360,
	})
	tween:Play()
end

setupPriceGradient()

local function setupLightRotation()
	if not starterPackRoot then
		return
	end
	local lightNode = starterPackRoot:FindFirstChild("Light", true)
	if not lightNode or not lightNode:IsA("GuiObject") then
		return
	end
	lightNode.Rotation = 0
	local tween = TweenService:Create(lightNode, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
		Rotation = 360,
	})
	tween:Play()
end

setupLightRotation()




