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

local MAIN_GUI_NAMES = { "MainGui", "MainGUI", "Main", "MainUI" }
local MAIN_GUI_DESC = { "CoinNum", "Progression" }
local PROGRESSION_GUI_NAMES = { "Progression", "ProgressionGui", "ProgressionGUI" }
local PROGRESSION_GUI_DESC = { "ProgressionBg", "CapsuleTemplate" }

local mainGui = nil
local progressionButton = nil
local progressionButtonConn = nil
local closeButtonConn = nil
local mainRedPoint = nil

local progressionGui = nil
local progressionBg = nil
local listFrame = nil
local template = nil
local closeButton = nil

local function ensureMainGui(timeout)
	if mainGui and mainGui.Parent then
		return mainGui
	end
	local gui = GuiResolver.WaitForLayer(playerGui, MAIN_GUI_NAMES, MAIN_GUI_DESC, timeout or 0)
	if gui then
		mainGui = gui
	end
	return mainGui
end

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

local pendingPayload = nil
local pendingHasClaimable = nil

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
	pendingHasClaimable = visible
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

local function clearEntries()
	entriesById = {}
	diamondIcon = nil
	if not listFrame then
		return
	end
	for _, child in ipairs(listFrame:GetChildren()) do
		if child ~= template and child:GetAttribute("AchievementId") then
			child:Destroy()
		end
	end
end

local function buildEntries()
	if not listFrame or not template then
		return
	end
	clearEntries()
	template.Visible = false
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

local function applyPayload(payload)
	if type(payload) ~= "table" then
		return
	end
	local entries = payload.Entries
	if type(entries) == "table" then
		for _, state in ipairs(entries) do
			local entry = entriesById[state.Id]
			if entry then
				applyEntryVisual(entry, state)
			end
		end
	end
	if payload.HasClaimable ~= nil then
		updateMainRedPoint(payload.HasClaimable)
	end
end

local function setupProgressionGui(gui)
	if not gui or not gui.Parent then
		return false
	end
	if gui == progressionGui and progressionBg and progressionBg.Parent then
		return true
	end
	progressionGui = gui
	progressionBg = gui:FindFirstChild("ProgressionBg", true)
	if not progressionBg then
		return false
	end
	listFrame = progressionBg:FindFirstChild("ScrollingFrame", true)
	template = listFrame and listFrame:FindFirstChild("CapsuleTemplate", true)

	local title = progressionBg:FindFirstChild("Title", true)
	closeButton = title and title:FindFirstChild("CloseButton", true)

	if progressionGui:IsA("LayerCollector") then
		progressionGui.Enabled = true
	end
	progressionBg.Visible = false

	if closeButtonConn then
		closeButtonConn:Disconnect()
		closeButtonConn = nil
	end
	if closeButton and closeButton:IsA("GuiButton") then
		closeButtonConn = closeButton.Activated:Connect(function()
			if progressionBg then
				progressionBg.Visible = false
			end
		end)
	end

	buildEntries()
	if pendingPayload then
		applyPayload(pendingPayload)
	end
	return true
end

local function ensureProgressionGui(timeout)
	if progressionGui and progressionGui.Parent and progressionBg and progressionBg.Parent then
		return true
	end
	local gui = GuiResolver.WaitForLayer(playerGui, PROGRESSION_GUI_NAMES, PROGRESSION_GUI_DESC, timeout or 0)
	if gui then
		return setupProgressionGui(gui)
	end
	return false
end

local function bindProgressionButton(button)
	if button == progressionButton and progressionButtonConn then
		return
	end
	if progressionButtonConn then
		progressionButtonConn:Disconnect()
		progressionButtonConn = nil
	end
	progressionButton = button
	mainRedPoint = nil
	if progressionButton then
		mainRedPoint = progressionButton:FindFirstChild("RedPoint", true)
		if pendingHasClaimable ~= nil then
			updateMainRedPoint(pendingHasClaimable)
		end
		progressionButtonConn = progressionButton.Activated:Connect(function()
			if ensureProgressionGui(30) and progressionBg then
				progressionBg.Visible = true
			end
		end)
	end
end

local function refreshBindings()
	if not mainGui or not mainGui.Parent then
		mainGui = GuiResolver.FindLayer(playerGui, MAIN_GUI_NAMES, MAIN_GUI_DESC)
	end
	bindProgressionButton(resolveProgressionButton())
	ensureProgressionGui(0)
end

task.spawn(function()
	ensureMainGui(60)
	bindProgressionButton(resolveProgressionButton())
end)

task.spawn(function()
	ensureProgressionGui(60)
end)

playerGui.DescendantAdded:Connect(function(child)
	local name = child.Name
	if name == "Progression" or name == "ProgressionBg" or name == "ProgressionGui" or name == "ProgressionGUI"
		or name == "MainGui" or name == "MainGUI" or name == "Main" or name == "MainUI" then
		task.defer(refreshBindings)
	end
end)

local claimTipsGui
local claimSuccessful
local lightBg
local itemTemplate
local itemIcon
local itemNumber
local claimTipsWarned = false
local pendingClaimReward = nil

local function bindClaimTipsNodes(searchRoot)
	if not searchRoot then
		return false
	end
	claimSuccessful = searchRoot:FindFirstChild("ClaimSuccessful", true)
	lightBg = searchRoot:FindFirstChild("LightBg", true)
	itemTemplate = claimSuccessful and claimSuccessful:FindFirstChild("ItemTemplate", true)
		or searchRoot:FindFirstChild("ItemTemplate", true)
	itemIcon = itemTemplate and itemTemplate:FindFirstChild("Icon", true)
	itemNumber = itemTemplate and itemTemplate:FindFirstChild("Number", true)

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
	return claimSuccessful ~= nil
end

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
		local ok = bindClaimTipsNodes(claimTipsGui)
		if ok and pendingClaimReward ~= nil then
			local reward = pendingClaimReward
			pendingClaimReward = nil
			task.defer(function()
				playClaimTips(reward)
			end)
		end
		return ok
	end
	local fallback = playerGui:FindFirstChild("ClaimSuccessful", true)
	if fallback and fallback:IsA("GuiObject") then
		claimTipsGui = fallback:FindFirstAncestorWhichIsA("LayerCollector")
		local searchRoot = claimTipsGui or fallback.Parent or playerGui
		local ok = bindClaimTipsNodes(searchRoot)
		if ok and pendingClaimReward ~= nil then
			local reward = pendingClaimReward
			pendingClaimReward = nil
			task.defer(function()
				playClaimTips(reward)
			end)
		end
		return ok
	end
	if not claimTipsWarned then
		warn("[ProgressionDisplay] ClaimTipsGui not found")
		claimTipsWarned = true
	end
	return false
end

resolveClaimTips(0)

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
	if not claimSuccessful or not claimSuccessful.Parent then
		resolveClaimTips(5)
	end
	if not claimSuccessful or not claimSuccessful:IsA("GuiObject") then
		pendingClaimReward = rewardCount
		return
	end
	closeClaimTips(false)
	if claimTipsGui and claimTipsGui:IsA("LayerCollector") then
		claimTipsGui.Enabled = true
	end
	if AudioManager and AudioManager.PlaySfx then
		pcall(function()
			AudioManager.PlaySfx("RewardPopup")
		end)
	end
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
	pendingPayload = payload
	applyPayload(payload)
end)

if pushProgressionClaimedEvent then
	pushProgressionClaimedEvent.OnClientEvent:Connect(function(_, rewardCount)
		playClaimTips(rewardCount)
	end)
end

task.defer(function()
	requestProgressionDataEvent:FireServer()
end)


