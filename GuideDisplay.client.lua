--[[
脚本名称: GuideDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/GuideDisplay
版本: V1.0
职责: 新手引导文本提示/手指提示展示与动效
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
	warn("[GuideDisplay] LabubuEvents not found")
	return
end

local pushGuideStateEvent = labubuEvents:WaitForChild("PushGuideState", 10)
if not pushGuideStateEvent then
	warn("[GuideDisplay] PushGuideState not found")
	return
end

local guideGui = GuiResolver.WaitForLayer(playerGui, { "GuideTips", "GuideTipsGui" }, { "TipsBg", "Tips" }, 30)
if not guideGui then
	warn("[GuideDisplay] GuideTips gui not found")
	return
end

local tipsBg = guideGui:FindFirstChild("TipsBg", true)
if not tipsBg or not tipsBg:IsA("GuiObject") then
	warn("[GuideDisplay] TipsBg not found")
	return
end

local tipsLabel = tipsBg:FindFirstChild("Tips", true)
if not tipsLabel or not tipsLabel:IsA("TextLabel") then
	warn("[GuideDisplay] Tips label not found")
	return
end

local wiggleToken = 0

local function startWiggle()
	wiggleToken += 1
	local token = wiggleToken
	task.spawn(function()
		while token == wiggleToken and tipsBg.Parent and tipsBg.Visible do
			local tween1 = TweenService:Create(tipsBg, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Rotation = 8 })
			tween1:Play()
			tween1.Completed:Wait()
			if token ~= wiggleToken then
				break
			end
			local tween2 = TweenService:Create(tipsBg, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Rotation = -8 })
			tween2:Play()
			tween2.Completed:Wait()
			if token ~= wiggleToken then
				break
			end
			local tween3 = TweenService:Create(tipsBg, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Rotation = 0 })
			tween3:Play()
			tween3.Completed:Wait()
			if token ~= wiggleToken then
				break
			end
			task.wait(1)
		end
	end)
end

local function stopWiggle()
	wiggleToken += 1
	tipsBg.Rotation = 0
end

local function applyTips(text, visible)
	tipsLabel.Text = text or ""
	tipsBg.Visible = visible == true
	if tipsBg.Visible then
		startWiggle()
	else
		stopWiggle()
	end
end

local backpackGui = GuiResolver.WaitForLayer(playerGui, { "BackpackGui", "BackpackGUI", "Backpack" }, {
	"BackpackFrame",
	"ItemListFrame",
	"ArmyTemplate",
}, 30)

local itemListFrame = nil
if backpackGui then
	itemListFrame = backpackGui:FindFirstChild("ItemListFrame", true)
end

local fingerState = {
	Enabled = false,
	CapsuleId = 1001,
}

local fingerTweens = {}
local fingerBasePositions = {}

local function stopFingerTween(finger)
	local tween = fingerTweens[finger]
	if tween then
		tween:Cancel()
		fingerTweens[finger] = nil
	end
	local basePos = fingerBasePositions[finger]
	if basePos then
		finger.Position = basePos
	end
	fingerBasePositions[finger] = nil
end

local function startFingerTween(finger)
	if fingerTweens[finger] then
		return
	end
	local basePos = fingerBasePositions[finger]
	if not basePos then
		basePos = finger.Position
		fingerBasePositions[finger] = basePos
	end
	local targetPos = UDim2.new(basePos.X.Scale, basePos.X.Offset, basePos.Y.Scale, basePos.Y.Offset - 10)
	local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(finger, tweenInfo, { Position = targetPos })
	fingerTweens[finger] = tween
	tween:Play()
end

local function resolveCapsuleId(instance)
	if not instance then
		return nil
	end
	local id = instance:GetAttribute("CapsuleId")
	return tonumber(id) or id
end

local function refreshFingerForEntry(entry)
	if not entry or not entry:IsA("GuiObject") then
		return
	end
	if entry:GetAttribute("IsBackpackEntry") ~= true then
		return
	end
	local entryId = resolveCapsuleId(entry)
	local finger = entry:FindFirstChild("Finger", true)
	if not finger or not finger:IsA("GuiObject") then
		return
	end
	local shouldShow = fingerState.Enabled and entryId == fingerState.CapsuleId
	finger.Visible = shouldShow
	if shouldShow then
		startFingerTween(finger)
	else
		stopFingerTween(finger)
	end
end

local function refreshAllFingers()
	if not itemListFrame then
		return
	end
	for _, child in ipairs(itemListFrame:GetChildren()) do
		refreshFingerForEntry(child)
	end
end

if itemListFrame then
	itemListFrame.ChildAdded:Connect(function(child)
		task.defer(function()
			refreshFingerForEntry(child)
		end)
	end)
	itemListFrame.ChildRemoved:Connect(function(child)
		if not child then
			return
		end
		local finger = child:FindFirstChild("Finger", true)
		if finger and fingerTweens[finger] then
			stopFingerTween(finger)
		end
	end)
end

applyTips("", false)
refreshAllFingers()

pushGuideStateEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	fingerState.Enabled = payload.ShowFinger == true
	local capsuleId = payload.FingerCapsuleId
	if capsuleId ~= nil then
		fingerState.CapsuleId = tonumber(capsuleId) or capsuleId
	end
	applyTips(payload.Text or "", payload.ShowTips == true)
	refreshAllFingers()
end)
