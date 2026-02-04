--[[
脚本名称: GroupRewardDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/GroupRewardDisplay
版本: V1.0
职责: 群组奖励界面显示与领取请求
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
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
	warn("[GroupRewardDisplay] LabubuEvents not found")
	return
end

local requestGroupRewardEvent = labubuEvents:WaitForChild("RequestGroupReward", 10)
if requestGroupRewardEvent and not requestGroupRewardEvent:IsA("RemoteEvent") then
	requestGroupRewardEvent = nil
end
if not requestGroupRewardEvent then
	warn("[GroupRewardDisplay] RequestGroupReward event not found")
end

local topRightGui = GuiResolver.WaitForLayer(playerGui, { "TopRightGui", "TopRightGUI", "TopRight", "TopRightUI" }, {
	"GroupReward",
	"Options",
	"Invite",
	"Leaderboard",
}, 30)
if not topRightGui then
	warn("[GroupRewardDisplay] TopRightGui not found")
end

local function resolveTopButton(root)
	if not root then
		return nil, nil
	end
	local groupRoot = root:FindFirstChild("GroupReward", true)
	if groupRoot then
		local rootGui = groupRoot:IsA("GuiObject") and groupRoot or groupRoot:FindFirstChildWhichIsA("GuiObject", true)
		if groupRoot:IsA("GuiButton") then
			return groupRoot, rootGui
		end
		local buttonNode = groupRoot:FindFirstChild("Button", true)
		if buttonNode and buttonNode:IsA("GuiButton") then
			return buttonNode, rootGui
		end
		local nested = groupRoot:FindFirstChildWhichIsA("GuiButton", true)
		if nested then
			return nested, rootGui
		end
		return nil, rootGui
	end
	return nil, nil
end

local topButton, topGroupRoot = topRightGui and resolveTopButton(topRightGui) or nil
if not topButton then
	topButton = GuiResolver.FindGuiButton(playerGui, "GroupReward")
end

local groupRewardGui = GuiResolver.WaitForLayer(playerGui, { "GroupReward" }, {
	"GroupReward",
	"Claim",
	"Claimed",
}, 30)
if not groupRewardGui then
	warn("[GroupRewardDisplay] GroupReward gui not found")
	return
end

if groupRewardGui:IsA("LayerCollector") then
	groupRewardGui.Enabled = true
end

local groupBg = groupRewardGui:FindFirstChild("Bg", true)
if not groupBg then
	groupBg = groupRewardGui:WaitForChild("Bg", 10)
end
if not groupBg or not groupBg:IsA("GuiObject") then
	warn("[GroupRewardDisplay] GroupReward.Bg not found")
	return
end

local closeButton = groupBg:FindFirstChild("CloseButton", true)
if closeButton and not closeButton:IsA("GuiButton") then
	closeButton = closeButton:FindFirstChildWhichIsA("GuiButton", true)
end

local claimButton = groupBg:FindFirstChild("Claim", true)
if claimButton and not claimButton:IsA("GuiButton") then
	claimButton = claimButton:FindFirstChildWhichIsA("GuiButton", true)
end

local claimedLabel = groupBg:FindFirstChild("Claimed", true)

groupBg.Visible = false

local claimed = player:GetAttribute("GroupRewardClaimed") == true

local function applyClaimedState()
	if topButton then
		topButton.Visible = not claimed
	end
	if topGroupRoot and topGroupRoot:IsA("GuiObject") then
		topGroupRoot.Visible = not claimed
	end
	if claimButton then
		claimButton.Visible = not claimed
	end
	if claimedLabel and claimedLabel:IsA("GuiObject") then
		claimedLabel.Visible = claimed
	end
end

local function connectButton(button, callback)
	if not button or not button:IsA("GuiButton") then
		return
	end
	button.Activated:Connect(callback)
end

if topButton then
	connectButton(topButton, function()
		if claimed then
			return
		end
		groupBg.Visible = true
	end)
end

if closeButton then
	connectButton(closeButton, function()
		groupBg.Visible = false
	end)
end

local claimCooling = false
if claimButton then
	connectButton(claimButton, function()
		if claimed or claimCooling then
			return
		end
		claimCooling = true
		if requestGroupRewardEvent then
			requestGroupRewardEvent:FireServer()
		end
		task.delay(0.6, function()
			claimCooling = false
		end)
	end)
end

player:GetAttributeChangedSignal("GroupRewardClaimed"):Connect(function()
	claimed = player:GetAttribute("GroupRewardClaimed") == true
	applyClaimedState()
end)

applyClaimedState()
