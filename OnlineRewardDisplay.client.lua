--[[
脚本名称: OnlineRewardDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/OnlineRewardDisplay
版本: V1.0
职责: 在线奖励界面显示、倒计时刷新、领取请求与领奖弹框
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
local OnlineRewardConfig = require(configFolder:WaitForChild("OnlineRewardConfig"))
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
	warn("[OnlineRewardDisplay] LabubuEvents not found")
	return
end

local requestDataEvent = labubuEvents:WaitForChild("RequestOnlineRewardData", 10)
local pushDataEvent = labubuEvents:WaitForChild("PushOnlineRewardData", 10)
local requestClaimEvent = labubuEvents:WaitForChild("RequestOnlineRewardClaim", 10)
local pushClaimedEvent = labubuEvents:WaitForChild("PushOnlineRewardClaimed", 10)

if not requestDataEvent or not pushDataEvent then
	warn("[OnlineRewardDisplay] OnlineReward events missing")
	return
end

local rewardPathMap = {
	[1] = { Group = "Bg01", Reward = "Reward01" },
	[2] = { Group = "Bg01", Reward = "Reward02" },
	[3] = { Group = "Bg01", Reward = "Reward03" },
	[4] = { Group = "Bg01", Reward = "Reward04" },
	[5] = { Group = "Bg01", Reward = "Reward05" },
	[6] = { Group = "Bg02", Reward = "Reward01" },
	[7] = { Group = "Bg02", Reward = "Reward02" },
	[8] = { Group = "Bg03", Reward = "Reward03" },
	[9] = { Group = "Bg04", Reward = "Reward04" },
	[10] = { Group = "Bg05", Reward = "Reward05" },
}

local function sortRewards()
	local list = {}
	for _, info in ipairs(OnlineRewardConfig.GetAll()) do
		if info and info.Id then
			table.insert(list, {
				Id = tonumber(info.Id) or info.Id,
				Seconds = math.max(0, math.floor(tonumber(info.Seconds) or 0)),
				Kind = tostring(info.Kind or ""),
				ItemId = tonumber(info.ItemId) or info.ItemId,
				Count = math.max(0, math.floor(tonumber(info.Count) or 0)),
			})
		end
	end
	table.sort(list, function(a, b)
		if a.Seconds == b.Seconds then
			return (tonumber(a.Id) or 0) < (tonumber(b.Id) or 0)
		end
		return a.Seconds < b.Seconds
	end)
	return list
end

local rewards = sortRewards()
local rewardById = {}
for _, info in ipairs(rewards) do
	rewardById[info.Id] = info
end

local function normalizeClaimed(raw)
	local normalized = {}
	if type(raw) ~= "table" then
		return normalized
	end
	for key, claimed in pairs(raw) do
		local id = tonumber(key) or key
		if id and claimed == true then
			normalized[id] = true
		end
	end
	return normalized
end

local state = {
	DayKey = 0,
	BaseOnlineSeconds = 0,
	BaseServerTime = os.time(),
	ServerTimeOffset = 0,
	Claimed = {},
	HasClaimable = false,
}

local mainTopRight = GuiResolver.WaitForLayer(playerGui, { "TopRightGui", "TopRightGUI", "TopRight", "TopRightUI" }, {
	"Online",
	"GroupReward",
	"Invite",
}, 30)
if not mainTopRight then
	warn("[OnlineRewardDisplay] TopRightGui not found")
end

local function resolveOnlineButton(root)
	if not root then
		return nil, nil
	end
	local node = root:FindFirstChild("Online", true)
	if not node then
		return nil, nil
	end
	if node:IsA("GuiButton") then
		return node, node
	end
	local btn = node:FindFirstChildWhichIsA("GuiButton", true)
	return btn, node
end

local topButton = nil
local topOnlineRoot = nil
if mainTopRight then
	topButton, topOnlineRoot = resolveOnlineButton(mainTopRight)
end
if not topButton then
	topButton = GuiResolver.FindGuiButton(playerGui, "Online")
end
if not topOnlineRoot and topButton then
	topOnlineRoot = topButton:FindFirstAncestorWhichIsA("GuiObject") or topButton
end

local topRedPoint = topOnlineRoot and topOnlineRoot:FindFirstChild("RedPoint", true) or nil
if topRedPoint and not topRedPoint:IsA("GuiObject") then
	topRedPoint = nil
end
local topTimeLabel = topOnlineRoot and topOnlineRoot:FindFirstChild("Time", true) or nil
if topTimeLabel and not topTimeLabel:IsA("TextLabel") then
	topTimeLabel = nil
end

local onlineRewardGui = GuiResolver.WaitForLayer(playerGui, { "OnlineReward", "OnlineRewardGui", "OnlineRewardGUI" }, {
	"OnlineReward",
	"NextReward",
	"Bg01",
}, 30)
if not onlineRewardGui then
	warn("[OnlineRewardDisplay] OnlineReward gui not found")
	return
end

if onlineRewardGui:IsA("LayerCollector") then
	onlineRewardGui.Enabled = true
end

local onlineBg = onlineRewardGui:FindFirstChild("Bg", true)
if not onlineBg then
	onlineBg = onlineRewardGui:WaitForChild("Bg", 10)
end
if not onlineBg or not onlineBg:IsA("GuiObject") then
	warn("[OnlineRewardDisplay] OnlineReward.Bg not found")
	return
end
onlineBg.Visible = false

local title = onlineBg:FindFirstChild("Title", true)
local closeButton = title and title:FindFirstChild("CloseButton", true) or onlineBg:FindFirstChild("CloseButton", true)
if closeButton and not closeButton:IsA("GuiButton") then
	closeButton = closeButton:FindFirstChildWhichIsA("GuiButton", true)
end

local nextRewardLabel = onlineBg:FindFirstChild("NextReward", true)
if nextRewardLabel and not nextRewardLabel:IsA("TextLabel") then
	nextRewardLabel = nil
end

local rewardEntries = {}

local function resolveRewardRoot(pathInfo)
	if not pathInfo then
		return nil
	end
	local groupNode = onlineBg:FindFirstChild(pathInfo.Group, true)
	if not groupNode then
		return nil
	end
	local rewardNode = groupNode:FindFirstChild(pathInfo.Reward, true)
	if rewardNode and rewardNode:IsA("GuiObject") then
		return rewardNode
	end
	return nil
end

local function resolveGuiButton(node)
	if not node then
		return nil
	end
	if node:IsA("GuiButton") then
		return node
	end
	return node:FindFirstChildWhichIsA("GuiButton", true)
end

for id, pathInfo in pairs(rewardPathMap) do
	local root = resolveRewardRoot(pathInfo)
	if root then
		local timeLabel = root:FindFirstChild("Time", true)
		if timeLabel and not timeLabel:IsA("TextLabel") then
			timeLabel = nil
		end
		local claimButton = resolveGuiButton(root:FindFirstChild("Claim", true))
		local claimedNode = root:FindFirstChild("Claimed", true)
		if claimedNode and not claimedNode:IsA("GuiObject") then
			claimedNode = nil
		end

		rewardEntries[id] = {
			Id = id,
			Root = root,
			TimeLabel = timeLabel,
			ClaimButton = claimButton,
			ClaimedNode = claimedNode,
			DefaultTimeText = timeLabel and timeLabel.Text or "",
			DefaultTimeVisible = timeLabel and timeLabel.Visible or true,
			DefaultClaimVisible = claimButton and claimButton.Visible or false,
			DefaultClaimedVisible = claimedNode and claimedNode.Visible or false,
			LastClick = 0,
		}
	end
end

local function formatMinutesSeconds(totalSeconds)
	local seconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))
	local minutes = math.floor(seconds / 60)
	local remain = seconds % 60
	return string.format("%02d:%02d", minutes, remain)
end

local function getNowOnlineSeconds()
	local nowServer = os.time() + state.ServerTimeOffset
	local elapsed = math.max(0, nowServer - (tonumber(state.BaseServerTime) or 0))
	return math.max(0, math.floor(tonumber(state.BaseOnlineSeconds) or 0) + elapsed)
end

local function getNextUnclaimedReward(onlineSeconds)
	local hasClaimable = false
	local nextReward = nil
	for _, reward in ipairs(rewards) do
		if state.Claimed[reward.Id] ~= true then
			if onlineSeconds >= reward.Seconds then
				hasClaimable = true
			else
				if not nextReward then
					nextReward = reward
				end
			end
		end
	end
	if not nextReward then
		for _, reward in ipairs(rewards) do
			if state.Claimed[reward.Id] ~= true then
				nextReward = reward
				break
			end
		end
	end
	return nextReward, hasClaimable
end

local function updateTopRedPoint(visible)
	if topRedPoint and topRedPoint:IsA("GuiObject") then
		topRedPoint.Visible = visible == true
	end
end

local function refreshView()
	local onlineSeconds = getNowOnlineSeconds()
	local nextReward, hasClaimable = getNextUnclaimedReward(onlineSeconds)
	state.HasClaimable = hasClaimable

	local nextRemaining = 0
	if nextReward then
		nextRemaining = math.max(0, nextReward.Seconds - onlineSeconds)
	end

	if nextRewardLabel then
		nextRewardLabel.Text = string.format("Next Reward:%s", formatMinutesSeconds(nextRemaining))
	end
	if topTimeLabel then
		topTimeLabel.Text = formatMinutesSeconds(nextRemaining)
	end

	updateTopRedPoint(hasClaimable)

	local nextUnclaimedId = nextReward and nextReward.Id or nil
	for id, entry in pairs(rewardEntries) do
		local reward = rewardById[id]
		if reward then
			local claimed = state.Claimed[id] == true
			local canClaim = not claimed and onlineSeconds >= reward.Seconds
			local isCurrentCountdown = not claimed and not canClaim and nextUnclaimedId == id

			if entry.TimeLabel and entry.TimeLabel:IsA("TextLabel") then
				if claimed or canClaim then
					entry.TimeLabel.Visible = false
				elseif isCurrentCountdown then
					entry.TimeLabel.Visible = true
					entry.TimeLabel.Text = formatMinutesSeconds(math.max(0, reward.Seconds - onlineSeconds))
				else
					entry.TimeLabel.Visible = entry.DefaultTimeVisible
					entry.TimeLabel.Text = entry.DefaultTimeText
				end
			end

			if entry.ClaimButton and entry.ClaimButton:IsA("GuiButton") then
				entry.ClaimButton.Visible = canClaim
			end
			if entry.ClaimedNode and entry.ClaimedNode:IsA("GuiObject") then
				entry.ClaimedNode.Visible = claimed
			end
		end
	end
end

local function applyPayload(payload)
	if type(payload) ~= "table" then
		return
	end
	state.DayKey = tonumber(payload.DayKey) or state.DayKey
	state.BaseOnlineSeconds = math.max(0, math.floor(tonumber(payload.OnlineSeconds) or 0))
	state.BaseServerTime = tonumber(payload.ServerTime) or os.time()
	state.ServerTimeOffset = state.BaseServerTime - os.time()
	state.Claimed = normalizeClaimed(payload.Claimed)
	state.HasClaimable = payload.HasClaimable == true
	refreshView()
end

local claimTipsGui = nil
local claimSuccessful = nil
local lightBg = nil
local itemListFrame = nil
local itemTemplate = nil
local itemIcon = nil
local itemNumber = nil
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
	itemListFrame = claimSuccessful and claimSuccessful:FindFirstChild("ItemList", true) or nil
	if itemListFrame and not itemListFrame:IsA("GuiObject") then
		itemListFrame = nil
	end
	itemTemplate = itemListFrame and itemListFrame:FindFirstChild("ItemTemplate", true) or nil
	if itemTemplate and not itemTemplate:IsA("GuiObject") then
		itemTemplate = nil
	end
	itemIcon = itemTemplate and itemTemplate:FindFirstChild("Icon", true) or nil
	itemIcon = resolveImageNode(itemIcon)
	itemNumber = itemTemplate and itemTemplate:FindFirstChild("Number", true) or nil
	if itemNumber and not itemNumber:IsA("TextLabel") then
		itemNumber = nil
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
		warn("[OnlineRewardDisplay] ClaimTipsGui not found")
		claimTipsWarned = true
	end
	return false
end

resolveClaimTips(0)

local onlinePanelWasVisibleBeforeClaim = false

local function closeClaimTips(restoreOnlinePanel)
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
	if restoreOnlinePanel ~= false and onlinePanelWasVisibleBeforeClaim and onlineBg and onlineBg:IsA("GuiObject") then
		onlineBg.Visible = true
	end
	onlinePanelWasVisibleBeforeClaim = false
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

local function findRewardCellIcon(rewardId)
	local id = tonumber(rewardId) or rewardId
	local entry = id and rewardEntries[id] or nil
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

local function getRewardIcon(reward)
	if type(reward) ~= "table" then
		return nil
	end
	if reward.Kind == "Capsule" then
		return getCapsuleIcon(tonumber(reward.ItemId) or reward.ItemId)
	end
	return nil
end

local function playClaimPopup(rewardId, rewardsPayload)
	if not claimSuccessful or not claimSuccessful.Parent then
		resolveClaimTips(5)
	end
	if not claimSuccessful or not claimSuccessful:IsA("GuiObject") then
		return
	end

	closeClaimTips(false)
	if onlineBg and onlineBg:IsA("GuiObject") then
		onlinePanelWasVisibleBeforeClaim = onlineBg.Visible == true
		onlineBg.Visible = false
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
			local icon = getRewardIcon(reward)
			if not icon then
				icon = findRewardCellIcon(rewardId)
			end
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

local function bindClaimButtons()
	for _, entry in pairs(rewardEntries) do
		if entry.ClaimButton then
			entry.ClaimButton.Activated:Connect(function()
				local now = os.clock()
				if now - entry.LastClick < 0.2 then
					return
				end
				entry.LastClick = now
				if requestClaimEvent then
					requestClaimEvent:FireServer(entry.Id)
				end
			end)
		end
	end
end

bindClaimButtons()

if topButton and topButton:IsA("GuiButton") then
	topButton.Activated:Connect(function()
		onlineBg.Visible = true
		requestDataEvent:FireServer()
	end)
end

if closeButton and closeButton:IsA("GuiButton") then
	closeButton.Activated:Connect(function()
		onlineBg.Visible = false
	end)
end

pushDataEvent.OnClientEvent:Connect(function(payload)
	applyPayload(payload)
end)

if pushClaimedEvent then
	pushClaimedEvent.OnClientEvent:Connect(function(rewardId, rewardsPayload, payload)
		if type(payload) == "table" then
			applyPayload(payload)
		else
			requestDataEvent:FireServer()
		end
		if type(rewardsPayload) ~= "table" then
			rewardsPayload = {}
		end
		playClaimPopup(rewardId, rewardsPayload)
	end)
end

requestDataEvent:FireServer()
refreshView()

task.spawn(function()
	while true do
		refreshView()
		task.wait(1)
	end
end)




