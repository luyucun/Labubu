--[[
脚本名称: CameraFocus
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/CameraFocus
版本: V1.9
职责: 新手办升台时镜头聚焦效果
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local FigurineConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FigurineConfig"))
local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local BackpackVisibility = require(modulesFolder:WaitForChild("BackpackVisibility"))

local function ensureLabubuEvents()
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		return nil
	end
	return eventsFolder:WaitForChild("LabubuEvents", 10)
end

local notifyFocusExitEvent
local function getNotifyFocusExitEvent()
	if notifyFocusExitEvent and notifyFocusExitEvent.Parent then
		return notifyFocusExitEvent
	end
	local labubuEvents = ensureLabubuEvents()
	if not labubuEvents then
		return nil
	end
	local event = labubuEvents:FindFirstChild("NotifyCameraFocusExit")
	if not event then
		event = labubuEvents:WaitForChild("NotifyCameraFocusExit", 2)
	end
	if event and event:IsA("RemoteEvent") then
		notifyFocusExitEvent = event
		return event
	end
	return nil
end

local function notifyFocusExit()
	local event = getNotifyFocusExitEvent()
	if event then
		event:FireServer()
	end
end

-- 镜头从玩家移动到目标台子的时间（秒）
local FOCUS_MOVE_TIME = 0.5
-- 台子升起时长（需与服务端升台动画时长保持一致）
local PLATFORM_RISE_TIME = 2
-- 台子升起结束后的额外停顿时间（秒）
local EXTRA_HOLD_TIME = 0.5
-- 镜头移动缓动类型
local FOCUS_EASING_STYLE = Enum.EasingStyle.Quad
-- 镜头移动缓动方向
local FOCUS_EASING_DIR = Enum.EasingDirection.Out
-- 镜头到台子的距离（越小越近）
local FOCUS_DISTANCE = 16
-- 镜头高度偏移（相对台子中心，越大越高）
local FOCUS_HEIGHT_OFFSET = 18
-- 镜头对准点的高度偏移（相对台子中心，（越小越俯视；越大越平视））
local FOCUS_LOOK_AT_HEIGHT = 0.9
-- 镜头正对台子朝向（-1 表示在台子正面，1 表示在台子背面）
local FOCUS_FACE_SIGN = 1
-- Exit 按钮等待超时（秒）
local EXIT_WAIT_TIMEOUT = 5
local EXIT_WAIT_INTERVAL = 0.2

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("CurrentCamera")

local active = false
local moveTween
local restoreType
local restoreSubject
local restoreCFrame
local focusToken = 0
local exitButton
local exitBound = false

local function formatHomeName(index)
	return string.format("%s%02d", GameConfig.HomeSlotPrefix, index)
end

local function getHomeFolder()
	local homeRoot = Workspace:FindFirstChild(GameConfig.HomeFolderName)
	if not homeRoot then
		return nil
	end
	local slotIndex = player:GetAttribute("HomeSlot")
	if not slotIndex then
		return nil
	end
	return homeRoot:FindFirstChild(formatHomeName(slotIndex))
end

local function resolveShowcaseNode(homeFolder, path)
	if not homeFolder or type(path) ~= "string" or path == "" then
		return nil
	end
	local current = homeFolder
	for _, segment in ipairs(string.split(path, "/")) do
		if segment ~= "" then
			current = current:FindFirstChild(segment)
			if not current then
				return nil
			end
		end
	end
	return current
end

local function resolvePlatform(homeFolder, path)
	local node = resolveShowcaseNode(homeFolder, path)
	if not node then
		return nil
	end
	if node:IsA("BasePart") and node.Name == "Platform" then
		return node
	end
	local platform = node:FindFirstChild("Platform", true)
	if platform and platform:IsA("BasePart") then
		return platform
	end
	return nil
end

local function getLookDirection(platform)
	return platform.CFrame.LookVector * FOCUS_FACE_SIGN
end

local function buildFocusCFrame(platform)
	local lookAt = platform.Position + Vector3.new(0, FOCUS_LOOK_AT_HEIGHT, 0)
	local dir = getLookDirection(platform)
	local camPos = platform.Position + dir * FOCUS_DISTANCE + Vector3.new(0, FOCUS_HEIGHT_OFFSET, 0)
	return CFrame.lookAt(camPos, lookAt)
end

local function resolveExitButton()
	if exitButton and exitButton.Parent then
		return exitButton
	end
	local cameraGui = playerGui:FindFirstChild("Camera")
	if not cameraGui then
		cameraGui = playerGui:WaitForChild("Camera", 5)
	end
	if not cameraGui then
		return nil
	end
	local button = cameraGui:FindFirstChild("Exit", true)
	if button and button:IsA("GuiButton") then
		exitButton = button
	else
		exitButton = nil
	end
	return exitButton
end

local function setExitVisible(visible)
	local button = resolveExitButton()
	if button then
		button.Visible = visible
	end
end

local function setBackpackVisibility(hidden)
	BackpackVisibility.SetHidden(playerGui, "CameraFocus", hidden == true)
end

local function restoreCamera(applyCFrame)
	if not camera then
		return
	end
	if applyCFrame and restoreCFrame then
		camera.CFrame = restoreCFrame
	end
	camera.CameraType = restoreType or Enum.CameraType.Custom
	if restoreSubject and restoreSubject.Parent then
		camera.CameraSubject = restoreSubject
	else
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function cancelTweens()
	if moveTween then
		moveTween:Cancel()
		moveTween = nil
	end
end

local function stopFocus(applyCFrame)
	cancelTweens()
	setExitVisible(false)
	setBackpackVisibility(false)
	restoreCamera(applyCFrame)
	active = false
end

local function bindExitButton()
	local button = resolveExitButton()
	if not button or exitBound then
		return
	end
	exitBound = true
	button.Activated:Connect(function()
		if not active then
			return
		end
		notifyFocusExit()
		stopFocus(true)
	end)
end

local function waitForExitButton(token)
	local startTime = os.clock()
	while active and token == focusToken and os.clock() - startTime < EXIT_WAIT_TIMEOUT do
		local button = resolveExitButton()
		if button then
			bindExitButton()
			button.Visible = true
			return true
		end
		task.wait(EXIT_WAIT_INTERVAL)
	end
	return false
end

local function playFocus(targetCFrame)
	if not camera or not targetCFrame then
		return
	end

	focusToken += 1
	local token = focusToken

	if active then
		stopFocus(true)
	end

	active = true
	restoreType = camera.CameraType
	restoreSubject = camera.CameraSubject
	restoreCFrame = camera.CFrame

	setExitVisible(false)
	setBackpackVisibility(true)
	bindExitButton()

	camera.CameraType = Enum.CameraType.Scriptable

	moveTween = TweenService:Create(camera, TweenInfo.new(FOCUS_MOVE_TIME, FOCUS_EASING_STYLE, FOCUS_EASING_DIR), {
		CFrame = targetCFrame,
	})
	moveTween.Completed:Connect(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed then
			return
		end
		task.delay(PLATFORM_RISE_TIME + EXTRA_HOLD_TIME, function()
			if not active or token ~= focusToken then
				return
			end
			if not waitForExitButton(token) then
				stopFocus(true)
			end
		end)
	end)
	moveTween:Play()
end

local function handleCameraFocus()
	local figurineId = player:GetAttribute("CameraFocusFigurineId")
	if not figurineId then
		return
	end
	local info = FigurineConfig.GetById(tonumber(figurineId) or figurineId)
	if not info then
		return
	end
	local homeFolder = getHomeFolder()
	if not homeFolder then
		return
	end
	local platform = resolvePlatform(homeFolder, info.ShowcasePath)
	if not platform then
		return
	end
	playFocus(buildFocusCFrame(platform))
end

player:GetAttributeChangedSignal("CameraFocusSeq"):Connect(handleCameraFocus)
