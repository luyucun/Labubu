--[[
脚本名称: ProgressionDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/ProgressionDisplay
版本: V1.0
职责: 养成界面显示与领奖动画
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local configFolder = ReplicatedStorage:WaitForChild("Config")
local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local ProgressionConfig = require(configFolder:WaitForChild("ProgressionConfig"))
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
	warn("[ProgressionDisplay] LabubuEvents not found")
	return
end

local requestProgressionDataEvent = labubuEvents:WaitForChild("RequestProgressionData", 10)
local pushProgressionDataEvent = labubuEvents:WaitForChild("PushProgressionData", 10)
local requestProgressionClaimEvent = labubuEvents:WaitForChild("RequestProgressionClaim", 10)
local pushProgressionClaimedEvent = labubuEvents:WaitForChild("PushProgressionClaimed", 10)

if not requestProgressionDataEvent or not pushProgressionDataEvent then
	warn("[ProgressionDisplay] Progression events missing")
	return
end

local mainGui = GuiResolver.WaitForLayer(playerGui, { "MainGui", "MainGUI", "Main", "MainUI" }, {
	"CoinNum",
	"Progression",
}, 30)

local function resolveProgressionButton()
	local root = mainGui or playerGui
	if not root then
		return nil
	end
	local button = GuiResolver.FindGuiButton(root, "Progression")
	if button then
		return button
	end
	local candidate = root:FindFirstChild("Progression", true)
	if candidate then
		if candidate:IsA("GuiButton") then
			return candidate
		end
		local nested = candidate:FindFirstChildWhichIsA("GuiButton", true)
		if nested then
			return nested
		end
	end
	return nil
end

local progressionButton = resolveProgressionButton()
if not progressionButton then
	warn("[ProgressionDisplay] MainGui.Progression not found")
end

local progressionGui = GuiResolver.WaitForLayer(playerGui, { "Progression", "ProgressionGui", "ProgressionGUI" }, {
	"ProgressionBg",
	"CapsuleTemplate",
}, 30)
if not progressionGui then
	warn("[ProgressionDisplay] Progression gui not found")
	return
end

local progressionBg = progressionGui:WaitForChild("ProgressionBg", 10)
if not progressionBg then
	warn("[ProgressionDisplay] ProgressionBg not found")
	return
end

local title = progressionBg:FindFirstChild("Title", true)
local closeButton = title and title:FindFirstChild("CloseButton", true)
if not closeButton then
	warn("[ProgressionDisplay] CloseButton not found")
end

local listFrame = progressionBg:FindFirstChild("ScrollingFrame", true)
if not listFrame then
	warn("[ProgressionDisplay] ScrollingFrame not found")
	return
end

local template = listFrame:FindFirstChild("CapsuleTemplate", true)
if not template then
	warn("[ProgressionDisplay] CapsuleTemplate not found")
	return
end

template.Visible = false
if progressionGui:IsA("LayerCollector") then
	progressionGui.Enabled = true
end
progressionBg.Visible = false

local mainRedPoint = nil
if progressionButton then
	mainRedPoint = progressionButton:FindFirstChild("RedPoint", true)
end

local entriesById = {}
local diamondIcon = nil

local function resolveImageTarget(instance)
	if not instance then
		return nil
	end
	if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		return instance
	end
	return instance:FindFirstChildWhichIsA("ImageLabel", true)
		or instance:FindFirstChildWhichIsA("ImageButton", true)
end

local function resolveButtonTarget(instance)
	if not instance then
		return nil
	end
	if instance:IsA("GuiButton") then
		return instance
	end
	return instance:FindFirstChildWhichIsA("GuiButton", true)
end

local function ensureDiamondButton(diamond)
	local button = resolveButtonTarget(diamond)
	if button then
		return button
	end
	local target = resolveImageTarget(diamond)
	local parent = nil
	if target and target:IsA("GuiObject") then
		parent = target
	elseif diamond and diamond:IsA("GuiObject") then
		parent = diamond
	end
	if not parent then
		return nil
	end
	local existing = parent:FindFirstChild("DiamondButton")
	if existing and existing:IsA("GuiButton") then
		return existing
	end
	local clickButton = Instance.new("TextButton")
	clickButton.Name = "DiamondButton"
	clickButton.BackgroundTransparency = 1
	clickButton.BorderSizePixel = 0
	clickButton.Text = ""
	clickButton.AutoButtonColor = false
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.Position = UDim2.new(0, 0, 0, 0)
	clickButton.ZIndex = parent.ZIndex + 1
	clickButton.Parent = parent
	return clickButton
end

local function updateMainRedPoint(visible)
	if mainRedPoint and mainRedPoint:IsA("GuiObject") then
		mainRedPoint.Visible = visible == true
	end
end

local function startDiamondWiggle(entry)
	if not entry or not entry.DiamondTarget then
		return
	end
	entry.WiggleToken = (entry.WiggleToken or 0) + 1
	local token = entry.WiggleToken
	local target = entry.DiamondTarget
	task.spawn(function()
		while entry.CanClaim and token == entry.WiggleToken and target.Parent do
			local tween1 = TweenService:Create(target, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Rotation = 8 })
			tween1:Play()
			tween1.Completed:Wait()
			if not entry.CanClaim or token ~= entry.WiggleToken then
				break
			end
			local tween2 = TweenService:Create(target, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Rotation = -8 })
			tween2:Play()
			tween2.Completed:Wait()
			if not entry.CanClaim or token ~= entry.WiggleToken then
				break
			end
			local tween3 = TweenService:Create(target, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Rotation = 0 })
			tween3:Play()
			tween3.Completed:Wait()
			if not entry.CanClaim or token ~= entry.WiggleToken then
				break
			end
			task.wait(1)
		end
	end)
end

local function stopDiamondWiggle(entry)
	if not entry or not entry.DiamondTarget then
		return
	end
	entry.WiggleToken = (entry.WiggleToken or 0) + 1
	entry.DiamondTarget.Rotation = 0
end

local function applyEntryVisual(entry, state)
	if not entry or not state then
		return
	end
	entry.Progress = state.Progress
	entry.Target = state.Target
	entry.Claimed = state.Claimed == true
	entry.CanClaim = state.CanClaim == true

	local progressText = ""
	if entry.Claimed then
		progressText = "Active"
	else
		local typeId = entry.Type
		if typeId == ProgressionConfig.AchievementType.PlayTime then
			progressText = state.Completed and "1/1" or "0/1"
		else
			progressText = string.format("%d/%d", tonumber(state.Progress) or 0, tonumber(state.Target) or 0)
		end
	end
	if entry.ProgressLabel and entry.ProgressLabel:IsA("TextLabel") then
		entry.ProgressLabel.Text = progressText
	end

	local highlight = entry.CanClaim
	if entry.Bg and entry.Bg:IsA("GuiObject") then
		entry.Bg.Visible = highlight
	end
	if entry.Diamond and entry.Diamond:IsA("GuiObject") then
		entry.Diamond.Visible = highlight
	end
	if entry.RedPoint and entry.RedPoint:IsA("GuiObject") then
		entry.RedPoint.Visible = highlight
	end

	if highlight then
		startDiamondWiggle(entry)
	else
		stopDiamondWiggle(entry)
	end
end

local function buildEntries()
	local iconsToPreload = {}
	local seenIcons = {}

	for index, info in ipairs(ProgressionConfig.Achievements) do
		local clone = template:Clone()
		clone.Name = string.format("Achievement_%s", tostring(info.Id))
		clone.Visible = true
		clone.LayoutOrder = index
		clone:SetAttribute("AchievementId", info.Id)

		local icon = clone:FindFirstChild("Icon", true)
		if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
			icon.Image = info.Icon or ""
		end
		if icon and icon.Image and icon.Image ~= "" and not seenIcons[icon.Image] then
			seenIcons[icon.Image] = true
			table.insert(iconsToPreload, icon.Image)
		end

		local nameLabel = clone:FindFirstChild("Name", true)
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = info.NameText or ""
		end

		local rewardLabel = clone:FindFirstChild("Reward", true)
		if rewardLabel and rewardLabel:IsA("TextLabel") then
			rewardLabel.Text = info.RewardText or ""
		end

		local progressLabel = clone:FindFirstChild("Progress", true)
		if progressLabel and progressLabel:IsA("TextLabel") then
			progressLabel.Text = "0/0"
		end

		local bg = clone:FindFirstChild("Bg", true)
		if bg and bg:IsA("GuiObject") then
			bg.Visible = false
		end

		local diamond = clone:FindFirstChild("Diamond", true)
		if diamond and diamond:IsA("GuiObject") then
			diamond.Visible = false
		end

		local redPoint = clone:FindFirstChild("RedPoint", true)
		if redPoint and redPoint:IsA("GuiObject") then
			redPoint.Visible = false
		end

		local diamondTarget = resolveImageTarget(diamond)
		if not diamondIcon and diamondTarget and diamondTarget.Image and diamondTarget.Image ~= "" then
			diamondIcon = diamondTarget.Image
		end

		local diamondButton = ensureDiamondButton(diamond)

		local entry = {
			Id = info.Id,
			Type = info.Type,
			Frame = clone,
			ProgressLabel = progressLabel,
			Bg = bg,
			Diamond = diamond,
			DiamondTarget = diamondTarget,
			RedPoint = redPoint,
			CanClaim = false,
			Claimed = false,
			WiggleToken = 0,
		}
		entriesById[info.Id] = entry

		if diamondButton then
			diamondButton.Activated:Connect(function()
				if entry.CanClaim and requestProgressionClaimEvent then
					requestProgressionClaimEvent:FireServer(info.Id)
				end
			end)
		end

		clone.Parent = listFrame
	end

	if #iconsToPreload > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(iconsToPreload)
		end)
	end
end

buildEntries()

local function connectButton(button, callback)
	if not button or not button:IsA("GuiButton") then
		return
	end
	button.Activated:Connect(callback)
end

if progressionButton then
	connectButton(progressionButton, function()
		progressionBg.Visible = true
	end)
end

if closeButton and closeButton:IsA("GuiButton") then
	connectButton(closeButton, function()
		progressionBg.Visible = false
	end)
end

local claimTipsGui = GuiResolver.FindLayer(playerGui, { "ClaimTipsGui", "ClaimTipsGUI" }, {
	"ClaimSuccessful",
	"LightBg",
})
local claimSuccessful = claimTipsGui and claimTipsGui:FindFirstChild("ClaimSuccessful", true)
local lightBg = claimTipsGui and claimTipsGui:FindFirstChild("LightBg", true)
local itemTemplate = claimSuccessful and claimSuccessful:FindFirstChild("ItemTemplate", true)
local itemIcon = itemTemplate and itemTemplate:FindFirstChild("Icon", true)
local itemNumber = itemTemplate and itemTemplate:FindFirstChild("Number", true)

if claimTipsGui and claimTipsGui:IsA("LayerCollector") then
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

local claimCloseConn = nil
local claimCloseReady = false
local lightTween = nil
local progressionWasVisible = nil

local function restoreProgressionAfterClaim()
	if progressionWasVisible and progressionBg and progressionBg:IsA("GuiObject") then
		progressionBg.Visible = true
	end
	progressionWasVisible = nil
end

local function closeClaimTips(restoreProgression)
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
	if restoreProgression ~= false then
		restoreProgressionAfterClaim()
	end
end

local function playClaimTips(rewardCount)
	if not claimSuccessful or not claimSuccessful:IsA("GuiObject") then
		return
	end
	closeClaimTips(false)
	if progressionBg and progressionBg:IsA("GuiObject") then
		progressionWasVisible = progressionBg.Visible
		progressionBg.Visible = false
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

	if itemTemplate and itemTemplate:IsA("GuiObject") then
		itemTemplate.Visible = true
	end
	if itemIcon and (itemIcon:IsA("ImageLabel") or itemIcon:IsA("ImageButton")) then
		if diamondIcon then
			itemIcon.Image = diamondIcon
		end
	end
	if itemNumber and itemNumber:IsA("TextLabel") then
		itemNumber.Text = tostring(rewardCount or 0)
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

pushProgressionDataEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	local entries = payload.Entries
	if type(entries) ~= "table" then
		return
	end
	for _, state in ipairs(entries) do
		local entry = entriesById[state.Id]
		if entry then
			applyEntryVisual(entry, state)
		end
	end
	if payload.HasClaimable ~= nil then
		updateMainRedPoint(payload.HasClaimable)
	end
end)

if pushProgressionClaimedEvent then
	pushProgressionClaimedEvent.OnClientEvent:Connect(function(_, rewardCount)
		playClaimTips(rewardCount)
	end)
end

task.defer(function()
	requestProgressionDataEvent:FireServer()
end)
