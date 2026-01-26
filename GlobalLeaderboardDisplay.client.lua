--[[
脚本名称: GlobalLeaderboardDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/GlobalLeaderboardDisplay
版本: V1.0
职责: 全局排行榜界面展示与刷新倒计时
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local modules = ReplicatedStorage:WaitForChild("Modules")
local FormatHelper = require(modules:WaitForChild("FormatHelper"))
local GuiResolver = require(modules:WaitForChild("GuiResolver"))

local function getEvent(name)
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		return nil
	end
	local labubuEvents = eventsFolder:WaitForChild("LabubuEvents", 10)
	if not labubuEvents then
		return nil
	end
	local event = labubuEvents:WaitForChild(name, 10)
	if event and event:IsA("RemoteEvent") then
		return event
	end
	return nil
end

local requestEvent = getEvent("RequestGlobalLeaderboard")
local pushEvent = getEvent("PushGlobalLeaderboard")

if not requestEvent then
	warn("[GlobalLeaderboardDisplay] RequestGlobalLeaderboard not found")
end
if not pushEvent then
	warn("[GlobalLeaderboardDisplay] PushGlobalLeaderboard not found")
end

local function resolveOpenButton()
	local function findButton(container)
		if not container then
			return nil
		end
		local button = container:FindFirstChild("Button")
		if button and not button:IsA("GuiButton") then
			button = button:FindFirstChildWhichIsA("GuiButton", true)
		end
		if not button then
			button = container:FindFirstChildWhichIsA("GuiButton", true)
		end
		if button and button:IsA("GuiButton") then
			return button
		end
		return nil
	end

	local topRightGui = GuiResolver.WaitForLayer(playerGui, { "TopRightGui", "TopRightGUI", "TopRight", "TopRightUI" }, {
		"Options",
		"Invite",
		"Learderboard",
		"Leaderboard",
	}, 30)
	if topRightGui then
		local bg = topRightGui:FindFirstChild("Bg")
		local container = bg and (bg:FindFirstChild("Learderboard") or bg:FindFirstChild("Leaderboard")) or nil
		if not container then
			container = topRightGui:FindFirstChild("Learderboard", true) or topRightGui:FindFirstChild("Leaderboard", true)
		end
		local button = findButton(container)
		if button then
			return button
		end
	end

	local fallbackContainer = playerGui:FindFirstChild("Learderboard", true) or playerGui:FindFirstChild("Leaderboard", true)
	return findButton(fallbackContainer)
end

local openButton = resolveOpenButton()
if not openButton then
	warn("[GlobalLeaderboardDisplay] Open button not found")
end

local leaderboardGui = GuiResolver.WaitForLayer(playerGui, { "Leaderboard", "LeaderBoard", "LeaderboardGui" }, {
	"Rank01",
	"RankTemplate",
	"CountDownTime",
}, 30)
if not leaderboardGui then
	warn("[GlobalLeaderboardDisplay] Leaderboard gui not found")
	return
end

local bg = leaderboardGui:WaitForChild("Bg", 10)
if not bg then
	warn("[GlobalLeaderboardDisplay] Leaderboard.Bg not found")
	return
end

local title = bg:WaitForChild("Title", 10)
local closeButton = title and title:WaitForChild("CloseButton", 10) or nil
if closeButton and not closeButton:IsA("GuiButton") then
	closeButton = closeButton:FindFirstChildWhichIsA("GuiButton", true)
end

local scroll = bg:WaitForChild("ScrollingFrame", 10)
if not scroll then
	warn("[GlobalLeaderboardDisplay] ScrollingFrame not found")
	return
end

local rank01 = scroll:WaitForChild("Rank01", 10)
local rank02 = scroll:WaitForChild("Rank02", 10)
local rank03 = scroll:WaitForChild("Rank03", 10)
local template = scroll:WaitForChild("RankTemplate", 10)

local playerFrame = bg:WaitForChild("Player", 10)
local countDownLabel = bg:WaitForChild("CountDownTime", 10)

local cachedList = {}
local nextRefreshTime = 0
local countdownToken = 0

local function formatSpeed(speed)
	local value = tonumber(speed) or 0
	return string.format("%s/s", FormatHelper.FormatCoinsShort(value, false))
end

local function setAvatar(imageLabel, userId)
	if not imageLabel or not imageLabel:IsA("ImageLabel") then
		return
	end
	imageLabel.Image = ""
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
		end)
		if ok and imageLabel.Parent then
			imageLabel.Image = content
		end
	end)
end

local function applyEntry(frame, entry, rankIndex)
	if not frame or not frame:IsA("GuiObject") then
		return
	end
	if not entry then
		frame.Visible = false
		return
	end
	frame.Visible = true
	local avatar = frame:FindFirstChild("Avatar", true)
	local nameLabel = frame:FindFirstChild("Name", true)
	local powerLabel = frame:FindFirstChild("Power", true)
	local rankLabel = frame:FindFirstChild("Rank", true)
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = entry.Name or "Unknown"
	end
	if powerLabel and powerLabel:IsA("TextLabel") then
		powerLabel.Text = formatSpeed(entry.Speed)
	end
	if rankLabel and rankLabel:IsA("TextLabel") and rankIndex then
		rankLabel.Text = tostring(rankIndex)
	end
	setAvatar(avatar, entry.UserId)
	if frame.LayoutOrder then
		frame.LayoutOrder = rankIndex or frame.LayoutOrder
	end
end

local function clearGenerated()
	for _, child in ipairs(scroll:GetChildren()) do
		if child:GetAttribute("Generated") == true then
			child:Destroy()
		end
	end
end

local function renderList(list)
	clearGenerated()
	list = list or {}
	applyEntry(rank01, list[1], 1)
	applyEntry(rank02, list[2], 2)
	applyEntry(rank03, list[3], 3)
	for index = 4, #list do
		local entry = list[index]
		local clone = template:Clone()
		clone.Name = string.format("RankClone_%02d", index)
		clone.Visible = true
		clone:SetAttribute("Generated", true)
		clone.Parent = scroll
		if clone.LayoutOrder then
			clone.LayoutOrder = index
		end
		applyEntry(clone, entry, index)
	end
end

local function updatePlayerFrame(list)
	if not playerFrame or not playerFrame:IsA("GuiObject") then
		return
	end
	local rankText = "20+"
	if type(list) == "table" then
		for _, entry in ipairs(list) do
			if entry.UserId == player.UserId and entry.Rank then
				rankText = tostring(entry.Rank)
				break
			end
		end
	end
	local avatar = playerFrame:FindFirstChild("Avatar", true)
	local nameLabel = playerFrame:FindFirstChild("Name", true)
	local powerLabel = playerFrame:FindFirstChild("Power", true)
	local rankLabel = playerFrame:FindFirstChild("Rank", true)
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = player.Name
	end
	if powerLabel and powerLabel:IsA("TextLabel") then
		powerLabel.Text = formatSpeed(player:GetAttribute("OutputSpeed"))
	end
	if rankLabel and rankLabel:IsA("TextLabel") then
		rankLabel.Text = rankText
	end
	setAvatar(avatar, player.UserId)
end

local function updateCountdown()
	if not countDownLabel or not countDownLabel:IsA("TextLabel") then
		return
	end
	local remaining = math.max(0, (tonumber(nextRefreshTime) or 0) - os.time())
	local total = math.max(0, math.floor(remaining))
	local minutes = math.floor(total / 60)
	local seconds = total % 60
	countDownLabel.Text = string.format("Refreshes in: %02d:%02d", minutes, seconds)
end

local function startCountdown()
	countdownToken += 1
	local token = countdownToken
	task.spawn(function()
		while bg.Visible and token == countdownToken do
			updateCountdown()
			task.wait(1)
		end
	end)
end

local function openLeaderboard()
	bg.Visible = true
	if requestEvent then
		requestEvent:FireServer()
	end
	if cachedList then
		renderList(cachedList)
		updatePlayerFrame(cachedList)
	end
	startCountdown()
end

local function closeLeaderboard()
	bg.Visible = false
	countdownToken += 1
end

if openButton then
	openButton.Activated:Connect(openLeaderboard)
end

if closeButton then
	closeButton.Activated:Connect(closeLeaderboard)
end

if pushEvent then
	pushEvent.OnClientEvent:Connect(function(list, nextRefresh)
		cachedList = type(list) == "table" and list or {}
		nextRefreshTime = tonumber(nextRefresh) or 0
		if bg.Visible then
			renderList(cachedList)
			updatePlayerFrame(cachedList)
			startCountdown()
		end
	end)
end

player:GetAttributeChangedSignal("OutputSpeed"):Connect(function()
	if bg.Visible then
		updatePlayerFrame(cachedList)
	end
end)
