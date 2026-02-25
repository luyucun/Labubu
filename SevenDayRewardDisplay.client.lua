--[[
脚本名称: SevenDayRewardDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/SevenDayRewardDisplay
版本: V1.0
职责: 七日登录奖励界面显示、领取请求、红点提示与领奖弹框
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
local SevenDayRewardConfig = require(configFolder:WaitForChild("SevenDayRewardConfig"))
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
	warn("[SevenDayRewardDisplay] LabubuEvents not found")
	return
end

local requestDataEvent = labubuEvents:WaitForChild("RequestSevenDayRewardData", 10)
local pushDataEvent = labubuEvents:WaitForChild("PushSevenDayRewardData", 10)
local requestClaimEvent = labubuEvents:WaitForChild("RequestSevenDayRewardClaim", 10)
local pushClaimedEvent = labubuEvents:WaitForChild("PushSevenDayRewardClaimed", 10)
local requestUnlockAllEvent = labubuEvents:WaitForChild("RequestSevenDayUnlockAll", 10)

if not requestDataEvent or not pushDataEvent or not requestClaimEvent then
	warn("[SevenDayRewardDisplay] seven-day events missing")
	return
end

local DAY_COUNT = math.max(1, tonumber(SevenDayRewardConfig.GetDayCount()) or 7)
local UTC_DAY_SECONDS = 86400

local function getUnlockThreshold()
	return math.max(0, math.floor(tonumber(SevenDayRewardConfig.UnlockCapsuleOpenTotal) or 0))
end

local function getOpenedCapsules()
	local total = tonumber(player:GetAttribute("CapsuleOpenTotal")) or 0
	if total < 0 then
		total = 0
	end
	return math.floor(total)
end

local state = {
	ServerTime = os.time(),
	ServerOffset = 0,
	DayKey = 0,
	Round = 1,
	PendingReset = false,
	IsFeatureUnlocked = false,
	UnlockNeedCapsules = getUnlockThreshold(),
	OpenedCapsules = getOpenedCapsules(),
	HasClaimable = false,
	HasLockedRewards = true,
	Rewards = {}, -- [day] = {Kind, ItemId, Count, Claimed, Claimable}
}

local function isFeatureUnlockedByAttr()
	local threshold = math.max(0, state.UnlockNeedCapsules)
	if threshold <= 0 then
		return true
	end
	return getOpenedCapsules() >= threshold
end

local topRightGui = GuiResolver.WaitForLayer(playerGui, { "TopRightGui", "TopRightGUI", "TopRight", "TopRightUI" }, {
	"Online",
	"SevenDays",
	"GroupReward",
}, 30)

local topButton = nil
local topRoot = nil
local topRedPoint = nil
local topTimeLabel = nil
local topButtonConn = nil

local function resolveGuiButton(node)
	if not node then
		return nil
	end
	if node:IsA("GuiButton") then
		return node
	end
	return node:FindFirstChildWhichIsA("GuiButton", true)
end

local function resolveTopButton(root)
	if not root then
		return nil, nil, nil, nil
	end
	local sevenDaysNode = root:FindFirstChild("SevenDays", true)
	if not sevenDaysNode then
		return nil, nil, nil, nil
	end
	local resolvedRoot = sevenDaysNode:IsA("GuiObject") and sevenDaysNode or sevenDaysNode:FindFirstChildWhichIsA("GuiObject", true)
	local buttonNode = sevenDaysNode:FindFirstChild("Button", true)
	local button = resolveGuiButton(buttonNode)
	if not button then
		button = resolveGuiButton(sevenDaysNode)
	end
	if not resolvedRoot and button then
		resolvedRoot = button:FindFirstAncestorWhichIsA("GuiObject") or button
	end
	local redPoint = sevenDaysNode:FindFirstChild("RedPoint", true)
	if redPoint and not redPoint:IsA("GuiObject") then
		redPoint = nil
	end
	local timeLabel = sevenDaysNode:FindFirstChild("Time", true)
	if timeLabel and not timeLabel:IsA("TextLabel") then
		timeLabel = nil
	end
	return button, resolvedRoot or button, redPoint, timeLabel
end

local function setPanelVisible(visible)
	-- 前置声明，稍后赋值
end

local function refreshTopNodes()
	local button, root, redPoint, timeLabel = resolveTopButton(topRightGui)
	if not button then
		button = GuiResolver.FindGuiButton(playerGui, "SevenDays")
	end
	if button then
		topButton = button
	end
	if root then
		topRoot = root
	elseif topButton then
		topRoot = topButton:FindFirstAncestorWhichIsA("GuiObject") or topButton
	end
	if redPoint then
		topRedPoint = redPoint
	elseif topRoot then
		local node = topRoot:FindFirstChild("RedPoint", true)
		if node and node:IsA("GuiObject") then
			topRedPoint = node
		end
	end
	if timeLabel then
		topTimeLabel = timeLabel
	elseif topRoot then
		local node = topRoot:FindFirstChild("Time", true)
		if node and node:IsA("TextLabel") then
			topTimeLabel = node
		end
	end
end

refreshTopNodes()

local sevenDaysGui = GuiResolver.WaitForLayer(playerGui, { "SevenDays", "SevenDaysGui", "SevenDaysGUI" }, {
	"UnlockAll",
	"Reward01",
	"Reward1",
}, 30)
if not sevenDaysGui then
	warn("[SevenDayRewardDisplay] SevenDays gui not found")
	return
end

if sevenDaysGui:IsA("LayerCollector") then
	sevenDaysGui.Enabled = true
end

local sevenDaysBg = sevenDaysGui:FindFirstChild("Bg", true)
if not sevenDaysBg then
	sevenDaysBg = sevenDaysGui:WaitForChild("Bg", 10)
end
if not sevenDaysBg or not sevenDaysBg:IsA("GuiObject") then
	warn("[SevenDayRewardDisplay] SevenDays.Bg not found")
	return
end

local blackBg = sevenDaysGui:FindFirstChild("BlackBg", true)
if blackBg and not blackBg:IsA("GuiObject") then
	blackBg = nil
end

local title = sevenDaysBg:FindFirstChild("Title", true)
local closeButton = title and title:FindFirstChild("CloseButton", true) or sevenDaysBg:FindFirstChild("CloseButton", true)
closeButton = resolveGuiButton(closeButton)

local unlockAllButton = resolveGuiButton(sevenDaysBg:FindFirstChild("UnlockAll", true))
local nextRewardLabel = sevenDaysBg:FindFirstChild("NextReward", true)
if nextRewardLabel and not nextRewardLabel:IsA("TextLabel") then
	nextRewardLabel = nil
end

local rewardEntries = {} -- [day] = {Root, DayNum, ClaimButton, ClaimedNode, ClaimedBg, LastClick}

local function findRewardRoot(day)
	local names = {
		string.format("Reward%02d", day),
		string.format("Reward%d", day),
	}
	for _, name in ipairs(names) do
		local node = sevenDaysBg:FindFirstChild(name, true)
		if node and node:IsA("GuiObject") then
			return node
		end
	end
	return nil
end

for day = 1, DAY_COUNT do
	local rootNode = findRewardRoot(day)
	if rootNode then
		local dayNumNode = rootNode:FindFirstChild("DayNum", true)
		if dayNumNode and not dayNumNode:IsA("GuiObject") then
			dayNumNode = nil
		end
		local claimNode = resolveGuiButton(rootNode:FindFirstChild("Claim", true))
		local claimedNode = rootNode:FindFirstChild("Claimed", true)
		if claimedNode and not claimedNode:IsA("GuiObject") then
			claimedNode = nil
		end
		local claimedBgNode = rootNode:FindFirstChild("Bg", true)
		if claimedBgNode and not claimedBgNode:IsA("GuiObject") then
			claimedBgNode = nil
		end
		if claimedBgNode == sevenDaysBg then
			claimedBgNode = nil
		end
		rewardEntries[day] = {
			Day = day,
			Root = rootNode,
			DayNum = dayNumNode,
			ClaimButton = claimNode,
			ClaimedNode = claimedNode,
			ClaimedBg = claimedBgNode,
			LastClick = 0,
		}
	end
end

local panelVisible = false

setPanelVisible = function(visible)
	panelVisible = visible == true
	if sevenDaysBg and sevenDaysBg:IsA("GuiObject") then
		sevenDaysBg.Visible = panelVisible
	end
	if blackBg and blackBg:IsA("GuiObject") then
		blackBg.Visible = panelVisible
	end
end

setPanelVisible(false)

local redPointWiggleToken = 0
local redPointWiggleRunning = false

local function stopTopRedPointWiggle()
	redPointWiggleToken += 1
	redPointWiggleRunning = false
	if topRedPoint and topRedPoint:IsA("GuiObject") then
		topRedPoint.Rotation = 0
	end
end

local function startTopRedPointWiggle()
	if redPointWiggleRunning then
		return
	end
	if not topRedPoint or not topRedPoint:IsA("GuiObject") then
		return
	end
	redPointWiggleRunning = true
	redPointWiggleToken += 1
	local token = redPointWiggleToken
	task.spawn(function()
		while token == redPointWiggleToken and topRedPoint.Parent and topRedPoint.Visible do
			local tween1 = TweenService:Create(topRedPoint, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Rotation = 8 })
			tween1:Play()
			tween1.Completed:Wait()
			if token ~= redPointWiggleToken or not topRedPoint.Visible then
				break
			end
			local tween2 = TweenService:Create(topRedPoint, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Rotation = -8 })
			tween2:Play()
			tween2.Completed:Wait()
			if token ~= redPointWiggleToken or not topRedPoint.Visible then
				break
			end
			local tween3 = TweenService:Create(topRedPoint, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Rotation = 0 })
			tween3:Play()
			tween3.Completed:Wait()
			if token ~= redPointWiggleToken or not topRedPoint.Visible then
				break
			end
			task.wait(1.76)
		end
		if token == redPointWiggleToken and topRedPoint then
			topRedPoint.Rotation = 0
			redPointWiggleRunning = false
		end
	end)
end

local function normalizeRewards(raw)
	local normalized = {}
	if type(raw) ~= "table" then
		return normalized
	end
	for _, info in ipairs(raw) do
		if type(info) == "table" then
			local day = tonumber(info.Day) or info.Day
			if day then
				normalized[day] = {
					Day = day,
					Kind = tostring(info.Kind or ""),
					ItemId = tonumber(info.ItemId) or info.ItemId,
					Count = math.max(0, math.floor(tonumber(info.Count) or 0)),
					Claimed = info.Claimed == true,
					Claimable = info.Claimable == true,
				}
			end
		end
	end
	return normalized
end

local function formatHourMinute(totalSeconds)
	local seconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	return string.format("%02d:%02d", hours, minutes)
end

local function getServerNow()
	return os.time() + state.ServerOffset
end

local function getSecondsToNextUtc()
	local now = math.max(0, math.floor(getServerNow()))
	local dayKey = math.floor(now / UTC_DAY_SECONDS)
	local nextBoundary = (dayKey + 1) * UTC_DAY_SECONDS
	return math.max(0, nextBoundary - now)
end

local function applyTopVisibility(unlocked)
	local visible = unlocked == true
	if topRoot and topRoot:IsA("GuiObject") then
		topRoot.Visible = visible
	end
	if topButton and topButton:IsA("GuiObject") and topButton ~= topRoot then
		topButton.Visible = visible
	end
	if not visible then
		setPanelVisible(false)
	end
end

local function updateTopRedPoint()
	local visible = (state.IsFeatureUnlocked or isFeatureUnlockedByAttr()) and state.HasClaimable
	if topRedPoint and topRedPoint:IsA("GuiObject") then
		topRedPoint.Visible = visible
		if visible then
			startTopRedPointWiggle()
		else
			stopTopRedPointWiggle()
		end
	else
		stopTopRedPointWiggle()
	end
end

local function refreshView()
	local unlocked = state.IsFeatureUnlocked or isFeatureUnlockedByAttr()
	applyTopVisibility(unlocked)

	local refreshSeconds = getSecondsToNextUtc()
	if nextRewardLabel then
		nextRewardLabel.Text = string.format("Refresh In:%s", formatHourMinute(refreshSeconds))
	end
	if topTimeLabel then
		topTimeLabel.Text = formatHourMinute(refreshSeconds)
	end

	for day, entry in pairs(rewardEntries) do
		local info = state.Rewards[day] or nil
		local claimed = info and info.Claimed == true or false
		local claimable = unlocked and info and info.Claimable == true or false
		local locked = not claimed and not claimable

		if entry.DayNum and entry.DayNum:IsA("GuiObject") then
			entry.DayNum.Visible = locked
		end
		if entry.ClaimButton and entry.ClaimButton:IsA("GuiButton") then
			entry.ClaimButton.Visible = claimable
		end
		if entry.ClaimedNode and entry.ClaimedNode:IsA("GuiObject") then
			entry.ClaimedNode.Visible = claimed
		end
		if entry.ClaimedBg and entry.ClaimedBg:IsA("GuiObject") then
			entry.ClaimedBg.Visible = claimed
		end
	end

	updateTopRedPoint()
end

local function applyPayload(payload)
	if type(payload) ~= "table" then
		return
	end
	state.ServerTime = tonumber(payload.ServerTime) or os.time()
	state.ServerOffset = state.ServerTime - os.time()
	state.DayKey = math.max(0, math.floor(tonumber(payload.DayKey) or state.DayKey or 0))
	state.Round = math.max(1, math.floor(tonumber(payload.Round) or state.Round or 1))
	state.PendingReset = payload.PendingReset == true
	state.UnlockNeedCapsules = math.max(0, math.floor(tonumber(payload.UnlockNeedCapsules) or state.UnlockNeedCapsules or getUnlockThreshold()))
	state.OpenedCapsules = math.max(0, math.floor(tonumber(payload.OpenedCapsules) or getOpenedCapsules()))
	state.IsFeatureUnlocked = payload.IsFeatureUnlocked == true or isFeatureUnlockedByAttr()
	state.HasClaimable = payload.HasClaimable == true
	state.HasLockedRewards = payload.HasLockedRewards ~= false
	state.Rewards = normalizeRewards(payload.Rewards)
	refreshView()
end

local claimTipsGui = nil
local claimSuccessful = nil
local lightBg = nil
local itemListFrame = nil
local itemTemplate = nil
local claimMessageLabel = nil
local claimMessageDefaultText = nil
local claimMessageDefaultColor = nil
local claimTipsWarned = false

local claimCloseConn = nil
local claimCloseReady = false
local lightTween = nil

local function resolveImageNode(node)
	if not node then
		return nil
	end
	if node:IsA("ImageLabel") or node:IsA("ImageButton") then
		return node
	end
	return node:FindFirstChildWhichIsA("ImageLabel", true) or node:FindFirstChildWhichIsA("ImageButton", true)
end

local function isDescendantOf(node, ancestor)
	if not node or not ancestor then
		return false
	end
	local current = node.Parent
	while current do
		if current == ancestor then
			return true
		end
		current = current.Parent
	end
	return false
end

local function resolveClaimMessageLabel(root, template)
	if not root then
		return nil
	end
	for _, name in ipairs({ "Title", "Text", "Tip", "Tips", "Hint" }) do
		local node = root:FindFirstChild(name, true)
		if node and node:IsA("TextLabel") and (not template or not isDescendantOf(node, template)) then
			return node
		end
	end
	for _, node in ipairs(root:GetDescendants()) do
		if node:IsA("TextLabel") and node.Name ~= "Number" then
			if not template or not isDescendantOf(node, template) then
				return node
			end
		end
	end
	return nil
end

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

local function bindClaimTipsNodes(root)
	if not root then
		return false
	end
	claimSuccessful = root:FindFirstChild("ClaimSuccessful", true)
	if claimSuccessful and not claimSuccessful:IsA("GuiObject") then
		claimSuccessful = nil
	end
	lightBg = root:FindFirstChild("LightBg", true)
	if lightBg and not lightBg:IsA("GuiObject") then
		lightBg = nil
	end
	itemListFrame = claimSuccessful and (claimSuccessful:FindFirstChild("ItemList", true) or claimSuccessful:FindFirstChild("ItemListFrame", true)) or nil
	if itemListFrame and not itemListFrame:IsA("GuiObject") then
		itemListFrame = nil
	end
	itemTemplate = itemListFrame and itemListFrame:FindFirstChild("ItemTemplate", true) or nil
	if not itemTemplate and claimSuccessful then
		itemTemplate = claimSuccessful:FindFirstChild("ItemTemplate", true)
	end
	if itemTemplate and not itemTemplate:IsA("GuiObject") then
		itemTemplate = nil
	end
	claimMessageLabel = claimSuccessful and resolveClaimMessageLabel(claimSuccessful, itemTemplate) or nil
	if claimMessageLabel then
		claimMessageDefaultText = claimMessageLabel.Text
		claimMessageDefaultColor = claimMessageLabel.TextColor3
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
		return bindClaimTipsNodes(claimTipsGui)
	end
	if not claimTipsWarned then
		warn("[SevenDayRewardDisplay] ClaimTipsGui not found")
		claimTipsWarned = true
	end
	return false
end

resolveClaimTips(0)

local sevenPanelWasVisibleBeforeClaim = false

local function resetClaimMessageStyle()
	if claimMessageLabel and claimMessageLabel:IsA("TextLabel") then
		if claimMessageDefaultText ~= nil then
			claimMessageLabel.Text = claimMessageDefaultText
		end
		if claimMessageDefaultColor then
			claimMessageLabel.TextColor3 = claimMessageDefaultColor
		end
	end
end

local function applyClaimMessageStyle()
	if claimMessageLabel and claimMessageLabel:IsA("TextLabel") then
		claimMessageLabel.Text = "Reward Claimed!"
		claimMessageLabel.TextColor3 = Color3.fromRGB(80, 225, 120)
	end
end

local function closeClaimTips(restoreSevenDaysPanel)
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
	resetClaimMessageStyle()
	if restoreSevenDaysPanel ~= false and sevenPanelWasVisibleBeforeClaim then
		local unlocked = state.IsFeatureUnlocked or isFeatureUnlockedByAttr()
		if unlocked then
			setPanelVisible(true)
		end
	end
	sevenPanelWasVisibleBeforeClaim = false
end

local function getCapsuleIcon(capsuleId)
	if type(CapsuleConfig.GetById) == "function" then
		local info = CapsuleConfig.GetById(capsuleId)
		return info and info.Icon or nil
	end
	local list = CapsuleConfig.Capsules
	if type(list) ~= "table" and type(CapsuleConfig) == "table" then
		list = CapsuleConfig
	end
	if type(list) ~= "table" then
		return nil
	end
	for _, info in ipairs(list) do
		if info and info.Id == capsuleId then
			return info.Icon
		end
	end
	return nil
end

local function findRewardCellIcon(day)
	local entry = rewardEntries[day]
	if not entry or not entry.Root then
		return nil
	end
	local direct = resolveImageNode(entry.Root:FindFirstChild("Icon", true))
	if direct and direct.Image and direct.Image ~= "" then
		return direct.Image
	end
	for _, obj in ipairs(entry.Root:GetDescendants()) do
		if (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) and obj.Image and obj.Image ~= "" then
			return obj.Image
		end
	end
	return nil
end

local function getRewardIcon(reward, day)
	if type(reward) == "table" and reward.Kind == "Capsule" then
		local icon = getCapsuleIcon(tonumber(reward.ItemId) or reward.ItemId)
		if icon and icon ~= "" then
			return icon
		end
	end
	return findRewardCellIcon(day)
end

local function playClaimPopup(day, rewardsPayload)
	if not claimSuccessful or not claimSuccessful.Parent then
		resolveClaimTips(5)
	end
	if not claimSuccessful or not claimSuccessful:IsA("GuiObject") then
		return
	end

	closeClaimTips(false)
	sevenPanelWasVisibleBeforeClaim = panelVisible == true
	if sevenPanelWasVisibleBeforeClaim then
		setPanelVisible(false)
	end
	if claimTipsGui and claimTipsGui:IsA("LayerCollector") then
		claimTipsGui.Enabled = true
	end
	if AudioManager and AudioManager.PlaySfx then
		pcall(function()
			AudioManager.PlaySfx("RewardPopup")
		end)
	end

	claimSuccessful.Visible = true
	applyClaimMessageStyle()
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
	if itemTemplate and itemTemplate:IsA("GuiObject") and type(rewardsPayload) == "table" then
		for _, reward in ipairs(rewardsPayload) do
			local clone = itemTemplate:Clone()
			clone.Visible = true
			local iconNode = resolveImageNode(clone:FindFirstChild("Icon", true))
			local numberNode = clone:FindFirstChild("Number", true)
			if numberNode and not numberNode:IsA("TextLabel") then
				numberNode = nil
			end
			local icon = getRewardIcon(reward, day)
			if iconNode and icon then
				iconNode.Image = icon
			end
			if numberNode then
				numberNode.Text = tostring(math.max(0, math.floor(tonumber(reward.Count) or 0)))
			end
			clone.Parent = itemListFrame or claimSuccessful
		end
	end

	if lightBg and lightBg:IsA("GuiObject") then
		lightBg.Visible = true
		lightBg.Rotation = 0
		lightTween = TweenService:Create(lightBg, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
			Rotation = 360,
		})
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

local function onTopButtonActivated()
	local unlocked = state.IsFeatureUnlocked or isFeatureUnlockedByAttr()
	if not unlocked then
		return
	end
	setPanelVisible(true)
	requestDataEvent:FireServer(true)
end

local function bindTopButton()
	if topButtonConn then
		topButtonConn:Disconnect()
		topButtonConn = nil
	end
	if topButton and topButton:IsA("GuiButton") then
		topButtonConn = topButton.Activated:Connect(onTopButtonActivated)
	end
end

bindTopButton()

if closeButton and closeButton:IsA("GuiButton") then
	closeButton.Activated:Connect(function()
		setPanelVisible(false)
	end)
end

local lastUnlockAllClick = 0
if unlockAllButton and unlockAllButton:IsA("GuiButton") and requestUnlockAllEvent then
	unlockAllButton.Activated:Connect(function()
		local unlocked = state.IsFeatureUnlocked or isFeatureUnlockedByAttr()
		if not unlocked then
			return
		end
		local now = os.clock()
		if now - lastUnlockAllClick < 0.3 then
			return
		end
		lastUnlockAllClick = now
		requestUnlockAllEvent:FireServer()
	end)
end

for day, entry in pairs(rewardEntries) do
	if entry.ClaimButton and entry.ClaimButton:IsA("GuiButton") then
		entry.ClaimButton.Activated:Connect(function()
			local unlocked = state.IsFeatureUnlocked or isFeatureUnlockedByAttr()
			if not unlocked then
				return
			end
			local reward = state.Rewards[day]
			if not reward or reward.Claimable ~= true then
				return
			end
			local now = os.clock()
			if now - entry.LastClick < 0.2 then
				return
			end
			entry.LastClick = now
			requestClaimEvent:FireServer(day)
		end)
	end
end

if pushDataEvent then
	pushDataEvent.OnClientEvent:Connect(function(payload)
		applyPayload(payload)
	end)
end

if pushClaimedEvent then
	pushClaimedEvent.OnClientEvent:Connect(function(day, rewardsPayload, payload)
		if type(payload) == "table" then
			applyPayload(payload)
		else
			requestDataEvent:FireServer(false)
		end
		if type(rewardsPayload) ~= "table" then
			rewardsPayload = {}
			local reward = state.Rewards[tonumber(day) or day]
			if reward then
				table.insert(rewardsPayload, {
					Kind = reward.Kind,
					ItemId = reward.ItemId,
					Count = reward.Count,
				})
			end
		end
		playClaimPopup(tonumber(day) or day, rewardsPayload)
	end)
end

player:GetAttributeChangedSignal("CapsuleOpenTotal"):Connect(function()
	state.OpenedCapsules = getOpenedCapsules()
	local unlockedByAttr = isFeatureUnlockedByAttr()
	if unlockedByAttr and not state.IsFeatureUnlocked then
		requestDataEvent:FireServer(false)
	end
	refreshView()
end)

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "SevenDays" or descendant.Name == "TopRightGui" or descendant.Name == "TopRight" then
		refreshTopNodes()
		bindTopButton()
		refreshView()
	end
end)

requestDataEvent:FireServer(false)
refreshView()

task.spawn(function()
	while true do
		refreshView()
		task.wait(1)
	end
end)
