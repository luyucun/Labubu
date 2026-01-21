--[[
脚本名称: CameraFocus
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/CameraFocus
版本: V1.9
职责: 新手办升台时镜头聚焦效果
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local FigurineConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FigurineConfig"))

-- 镜头从玩家移动到目标台子的时间（秒）
local FOCUS_MOVE_TIME = 0.5
-- 台子升起时长（需与服务端升台动画时长保持一致）
local PLATFORM_RISE_TIME = 2
-- 台子升起结束后的额外停顿时间（秒）
local EXTRA_HOLD_TIME = 1
-- 镜头移动缓动类型
local FOCUS_EASING_STYLE = Enum.EasingStyle.Quad
-- 镜头移动缓动方向
local FOCUS_EASING_DIR = Enum.EasingDirection.Out
-- 镜头到台子的距离（越小越近）
local FOCUS_DISTANCE = 16
-- 镜头高度偏移（相对台子中心，越大越高）
local FOCUS_HEIGHT_OFFSET = 16
-- 镜头对准点的高度偏移（相对台子中心，（越小越俯视；越大越平视））
local FOCUS_LOOK_AT_HEIGHT = 0.65
-- 镜头正对台子朝向（-1 表示在台子正面，1 表示在台子背面）
local FOCUS_FACE_SIGN = 1

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

local function setCoreBackpackEnabled(enabled)
	local ok, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
	end)
	if not ok then
		warn(string.format("[CameraFocus] SetCoreGuiEnabled failed: %s", tostring(err)))
	end
end

local function getCoreBackpackEnabled()
	local ok, result = pcall(function()
		return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
	end)
	if ok then
		return result
	end
	return nil
end

local function setBackpackVisibility(hidden)
	local counter = playerGui:FindFirstChild("BackpackHideCount")
	if not counter then
		counter = Instance.new("IntValue")
		counter.Name = "BackpackHideCount"
		counter.Value = 0
		counter.Parent = playerGui
	end

	local backpackGui = playerGui:FindFirstChild("BackpackGui")
	if hidden then
		if backpackGui then
			backpackGui:SetAttribute("BackpackForceHidden", true)
		end
		if counter.Value == 0 then
			local corePrev = getCoreBackpackEnabled()
			if type(corePrev) == "boolean" then
				playerGui:SetAttribute("BackpackHideCorePrev", corePrev)
			end
			if backpackGui and backpackGui:IsA("LayerCollector") then
				playerGui:SetAttribute("BackpackHideGuiPrev", backpackGui.Enabled)
				backpackGui.Enabled = false
			end
			setCoreBackpackEnabled(false)
		end
		counter.Value += 1
	else
		if counter.Value <= 0 then
			return
		end
		counter.Value -= 1
		if counter.Value == 0 then
			local corePrev = playerGui:GetAttribute("BackpackHideCorePrev")
			if type(corePrev) == "boolean" then
				setCoreBackpackEnabled(corePrev)
			end
			if backpackGui and backpackGui:IsA("LayerCollector") then
				local guiPrev = playerGui:GetAttribute("BackpackHideGuiPrev")
				if type(guiPrev) == "boolean" then
					backpackGui.Enabled = guiPrev
				else
					backpackGui.Enabled = true
				end
			end
			if backpackGui then
				backpackGui:SetAttribute("BackpackForceHidden", false)
			end
			playerGui:SetAttribute("BackpackHideCorePrev", nil)
			playerGui:SetAttribute("BackpackHideGuiPrev", nil)
		end
	end
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
		stopFocus(true)
	end)
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
			setExitVisible(true)
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
