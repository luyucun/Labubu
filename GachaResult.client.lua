--[[
脚本名称: GachaResult
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/GachaResult
版本: V3.0
职责: 开盲盒结果界面与翻面/升级表现
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local configFolder = ReplicatedStorage:WaitForChild("Config")
local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(configFolder:WaitForChild("GameConfig"))
local CapsuleConfig = require(configFolder:WaitForChild("CapsuleConfig"))
local FigurineConfig = require(configFolder:WaitForChild("FigurineConfig"))
local FigurineRateConfig = require(configFolder:WaitForChild("FigurineRateConfig"))
local UpgradeConfig = require(configFolder:WaitForChild("UpgradeConfig"))
local FormatHelper = require(modulesFolder:WaitForChild("FormatHelper"))

local gachaGui = playerGui:WaitForChild("GachaResult", 10)
if not gachaGui then
	warn("[GachaResult] GachaResult gui not found")
	return
end

local function getBackpackGui()
	local gui = playerGui:FindFirstChild("BackpackGui")
	if gui and gui:IsA("LayerCollector") then
		return gui
	end
	return nil
end

local resultFrame = gachaGui:WaitForChild("Result", 10)
if not resultFrame then
	warn("[GachaResult] Result frame not found")
	return
end

local levelUpFrame = gachaGui:FindFirstChild("LevelUp")

local resultCover = resultFrame:FindFirstChild("Cover", true)
local resultIcon = resultFrame:FindFirstChild("Icon", true)
local resultName = resultFrame:FindFirstChild("Name", true)
local resultRare = resultFrame:FindFirstChild("Rare", true)
local resultSpeed = resultFrame:FindFirstChild("Speed", true)
local resultNewTitle = resultFrame:FindFirstChild("NewTitle", true)

local levelUpIcon = levelUpFrame and levelUpFrame:FindFirstChild("Icon", true)
local levelUpName = levelUpFrame and levelUpFrame:FindFirstChild("Name", true)
local levelUpRare = levelUpFrame and levelUpFrame:FindFirstChild("Rare", true)
local levelUpSpeed = levelUpFrame and levelUpFrame:FindFirstChild("Speed", true)
local levelUpProgress = levelUpFrame and levelUpFrame:FindFirstChild("Progressbar", true)
local levelUpText = levelUpFrame and levelUpFrame:FindFirstChild("Text", true)

local rarityNames = {
	[1] = "Common",
	[2] = "Light",
	[3] = "Gold",
	[4] = "Diamond",
	[5] = "Rainbow",
}

local qualityIndicatorNames = {
	[1] = "Leaf",
	[2] = "Water",
	[3] = "Lunar",
	[4] = "Solar",
	[5] = "Flame",
	[6] = "Heart",
	[7] = "Celestial",
}

local qualityIndicatorLookup = {}
for _, name in pairs(qualityIndicatorNames) do
	qualityIndicatorLookup[name] = true
end

local function getRarityName(rarity)
	return rarityNames[tonumber(rarity) or 0] or tostring(rarity or "")
end

local function updateQualityIndicators(container, quality)
	if not container then
		return
	end
	local targetName = qualityIndicatorNames[tonumber(quality) or 0]
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("GuiObject") and qualityIndicatorLookup[descendant.Name] then
			descendant.Visible = targetName ~= nil and descendant.Name == targetName
		end
	end
end

local function calculateRate(figurineInfo, level, rarity)
	if not figurineInfo then
		return 0
	end
	local baseRate = tonumber(figurineInfo.BaseRate) or 0
	if baseRate <= 0 then
		return 0
	end
	local quality = tonumber(figurineInfo.Quality) or 1
	local levelValue = tonumber(level) or 1
	local rarityValue = tonumber(rarity) or figurineInfo.Rarity or 1
	local qualityCoeff = FigurineRateConfig.GetQualityCoeff(quality)
	local rarityCoeff = FigurineRateConfig.GetRarityCoeff(rarityValue)
	local levelFactor = 1 + (levelValue - 1) * qualityCoeff
	if levelFactor < 0 then
		levelFactor = 0
	end
	return baseRate * rarityCoeff * levelFactor
end

local function getLevelProgress(level, exp, maxLevel)
	local maxValue = tonumber(maxLevel) or UpgradeConfig.GetMaxLevel()
	local levelValue = tonumber(level) or 1
	if levelValue >= maxValue then
		return 1
	end
	local required = UpgradeConfig.GetRequiredExp(levelValue) or 0
	if required <= 0 then
		return 1
	end
	local expValue = tonumber(exp) or 0
	return math.clamp(expValue / required, 0, 1)
end

local function formatSpeedText(speed)
	return string.format("%s/S", FormatHelper.FormatCoinsShort(speed, true))
end

local function setVisible(guiObject, visible)
	if guiObject and guiObject:IsA("GuiObject") then
		guiObject.Visible = visible
	end
end

local function setImage(imageObject, image)
	if imageObject and (imageObject:IsA("ImageLabel") or imageObject:IsA("ImageButton")) then
		imageObject.Image = image or ""
	end
end

local function setText(textObject, text)
	if textObject and textObject:IsA("TextLabel") then
		textObject.Text = text or ""
	end
end

local function captureLayout(frame)
	if not frame or not frame.Parent then
		return nil
	end
	local parentSize = frame.Parent.AbsoluteSize
	if not parentSize or parentSize.X <= 0 then
		RunService.RenderStepped:Wait()
		parentSize = frame.Parent.AbsoluteSize
	end
	if not parentSize or parentSize.X <= 0 then
		local camera = workspace.CurrentCamera
		parentSize = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	end
	local absPos = frame.AbsolutePosition
	local absSize = frame.AbsoluteSize
	local center = Vector2.new(absPos.X + absSize.X * 0.5, absPos.Y + absSize.Y * 0.5)
	return {
		ParentSize = parentSize,
		AbsSize = absSize,
		Center = center,
		OriginalAnchor = frame.AnchorPoint,
		OriginalPos = frame.Position,
		OriginalSize = frame.Size,
	}
end

local function applyCenteredLayout(frame, layout)
	if not frame or not layout then
		return
	end
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(layout.Center.X / layout.ParentSize.X, 0, layout.Center.Y / layout.ParentSize.Y, 0)
end

local function restoreLayout(frame, layout)
	if not frame or not layout then
		return
	end
	frame.AnchorPoint = layout.OriginalAnchor
	frame.Position = layout.OriginalPos
	frame.Size = layout.OriginalSize
end

local function getSlidePositions(layout)
	local parentHeight = layout.ParentSize.Y
	local frameHeight = layout.AbsSize.Y
	local targetY = layout.Center.Y / layout.ParentSize.Y
	local startY = (parentHeight + frameHeight * 0.5) / parentHeight
	local endY = (-frameHeight * 0.5) / parentHeight
	local xScale = layout.Center.X / layout.ParentSize.X
	return UDim2.new(xScale, 0, startY, 0), UDim2.new(xScale, 0, targetY, 0), UDim2.new(xScale, 0, endY, 0)
end

local function tweenObject(target, tweenInfo, props, pool)
	local tween = TweenService:Create(target, tweenInfo, props)
	table.insert(pool, tween)
	tween:Play()
	return tween
end

local function playShake(frame, basePosition, duration, magnitude, interval, token, tokenRef)
	if not frame or not basePosition then
		return
	end
	local total = tonumber(duration) or 0
	if total <= 0 or magnitude <= 0 then
		frame.Position = basePosition
		if total > 0 then
			task.wait(total)
		end
		return
	end
	local startTime = os.clock()
	while os.clock() - startTime < total do
		if token ~= tokenRef.Value then
			return
		end
		local dx = (math.random() * 2 - 1) * magnitude
		local dy = (math.random() * 2 - 1) * magnitude
		frame.Position = UDim2.new(basePosition.X.Scale, basePosition.X.Offset + dx, basePosition.Y.Scale, basePosition.Y.Offset + dy)
		task.wait(interval)
	end
	frame.Position = basePosition
end

local baseLayoutResult = captureLayout(resultFrame)
local baseLayoutLevel = levelUpFrame and captureLayout(levelUpFrame) or nil

local function playFlip(frame, duration, onHalf, token, tokenRef, pool)
	local halfTime = math.max(0, duration / 2)
	local baseSize = frame.Size
	local collapseSize = UDim2.new(0, 0, baseSize.Y.Scale, baseSize.Y.Offset)
	local tweenOut = TweenService:Create(frame, TweenInfo.new(halfTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = collapseSize,
	})
	table.insert(pool, tweenOut)
	tweenOut.Completed:Connect(function(state)
		if state ~= Enum.PlaybackState.Completed then
			return
		end
		if token ~= tokenRef.Value then
			return
		end
		if onHalf then
			onHalf()
		end
		local tweenIn = TweenService:Create(frame, TweenInfo.new(halfTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = baseSize,
		})
		table.insert(pool, tweenIn)
		tweenIn:Play()
	end)
	tweenOut:Play()
end

local gachaTimes = {
	SlideIn = tonumber(GameConfig.GachaSlideInTime) or 0.35,
	CoverHold = tonumber(GameConfig.GachaCoverHoldTime) or 0.5,
	Flip = tonumber(GameConfig.GachaFlipTime) or 0.4,
	ResultHold = tonumber(GameConfig.GachaResultHoldTime) or 0.5,
	LevelUp = tonumber(GameConfig.GachaLevelUpTime) or 0.5,
	SlideOut = tonumber(GameConfig.GachaSlideOutTime) or 0.35,
}
local coverShakeMagnitude = 6
local coverShakeInterval = 0.05

local activeToken = { Value = 0 }
local activeTweens = {}
local backpackRestoreState

local function getBackpackHideCount()
	local counter = playerGui:FindFirstChild("BackpackHideCount")
	if counter and counter:IsA("IntValue") then
		return counter.Value
	end
	return 0
end

local function restoreBackpack()
	if not backpackRestoreState then
		return
	end
	local backpackGui = getBackpackGui()
	if backpackGui then
		if getBackpackHideCount() > 0 then
			backpackGui.Enabled = false
			backpackGui:SetAttribute("BackpackForceHidden", true)
		else
			backpackGui.Enabled = backpackRestoreState.Enabled == true
			backpackGui:SetAttribute("BackpackForceHidden", backpackRestoreState.ForceHidden)
		end
	end
	backpackRestoreState = nil
end

local function cancelActive()
	activeToken.Value += 1
	for _, tween in ipairs(activeTweens) do
		tween:Cancel()
	end
	table.clear(activeTweens)
	restoreBackpack()
	if baseLayoutResult then
		restoreLayout(resultFrame, baseLayoutResult)
	end
	if levelUpFrame and baseLayoutLevel then
		restoreLayout(levelUpFrame, baseLayoutLevel)
	end
	resultFrame.Visible = false
	if levelUpFrame then
		levelUpFrame.Visible = false
	end
end

local function playSequence(payload)
	cancelActive()
	activeToken.Value += 1
	local token = activeToken.Value

	if gachaGui:IsA("LayerCollector") then
		gachaGui.Enabled = true
	end

	local capsuleInfo = CapsuleConfig.GetById(payload.CapsuleId)
	local figurineInfo = FigurineConfig.GetById(payload.FigurineId)
	if not capsuleInfo or not figurineInfo then
		restoreBackpack()
		return
	end
	local capsuleQuality = tonumber(capsuleInfo.Quality) or 0
	local figurineQuality = tonumber(figurineInfo.Quality) or capsuleQuality or 0

	local backpackGui = getBackpackGui()
	if backpackGui then
		backpackRestoreState = {
			Enabled = backpackGui.Enabled,
			ForceHidden = backpackGui:GetAttribute("BackpackForceHidden"),
		}
		backpackGui.Enabled = false
		backpackGui:SetAttribute("BackpackForceHidden", true)
	end

	local layoutResult = captureLayout(resultFrame)
	if not layoutResult then
		restoreBackpack()
		return
	end
	local layoutLevel = levelUpFrame and captureLayout(levelUpFrame) or nil

	applyCenteredLayout(resultFrame, layoutResult)
	if levelUpFrame and layoutLevel then
		applyCenteredLayout(levelUpFrame, layoutLevel)
	end

	local startPos, targetPos, endPos = getSlidePositions(layoutResult)
	local levelStartPos
	local levelTargetPos
	local levelEndPos
	if levelUpFrame and layoutLevel then
		levelStartPos, levelTargetPos, levelEndPos = getSlidePositions(layoutLevel)
	end
	resultFrame.Position = startPos
	resultFrame.Visible = true

	setVisible(resultCover, true)
	setVisible(resultIcon, false)
	setVisible(resultName, false)
	setVisible(resultRare, false)
	setVisible(resultSpeed, false)
	setVisible(resultNewTitle, false)

	updateQualityIndicators(resultFrame, capsuleQuality)
	setImage(resultCover, capsuleInfo.Icon or capsuleInfo.DisplayImage)

	if levelUpFrame then
		levelUpFrame.Visible = false
		setImage(levelUpIcon, figurineInfo.Icon)
		setText(levelUpName, figurineInfo.Name)
		setText(levelUpRare, getRarityName(payload.Rarity))
		updateQualityIndicators(levelUpFrame, figurineQuality)
		setVisible(levelUpIcon, true)
		setVisible(levelUpName, true)
		setVisible(levelUpRare, true)
		setVisible(levelUpSpeed, true)
	end

	tweenObject(resultFrame, TweenInfo.new(gachaTimes.SlideIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = targetPos,
	}, activeTweens)
	task.wait(gachaTimes.SlideIn)
	if token ~= activeToken.Value then
		return
	end

	playShake(resultFrame, targetPos, gachaTimes.CoverHold, coverShakeMagnitude, coverShakeInterval, token, activeToken)
	if token ~= activeToken.Value then
		return
	end

	setVisible(resultCover, false)
	updateQualityIndicators(resultFrame, figurineQuality)
	setImage(resultIcon, figurineInfo.Icon)
	setText(resultName, figurineInfo.Name)
	setText(resultRare, getRarityName(payload.Rarity))
	setText(resultSpeed, formatSpeedText(tonumber(figurineInfo.BaseRate) or 0))
	setVisible(resultIcon, true)
	setVisible(resultName, true)
	setVisible(resultRare, true)
	setVisible(resultSpeed, true)

	if payload.IsNew then
		setVisible(resultNewTitle, true)
		task.wait(gachaTimes.ResultHold)
		if token ~= activeToken.Value then
			return
		end
	else
		if levelUpFrame and levelUpProgress then
			levelUpFrame.Position = levelTargetPos or targetPos
			levelUpFrame.Visible = true
			local prevProgress = getLevelProgress(payload.PrevLevel, payload.PrevExp, payload.MaxLevel)
			local newProgress = getLevelProgress(payload.Level, payload.Exp, payload.MaxLevel)
			local size = levelUpProgress.Size
			levelUpProgress.Size = UDim2.new(prevProgress, size.X.Offset, size.Y.Scale, size.Y.Offset)
			setText(levelUpText, string.format("Lv.%d", tonumber(payload.PrevLevel) or 1))
			local prevRate = calculateRate(figurineInfo, payload.PrevLevel, payload.Rarity)
			setText(levelUpSpeed, formatSpeedText(prevRate))

			tweenObject(levelUpProgress, TweenInfo.new(gachaTimes.LevelUp, Enum.EasingStyle.Linear), {
				Size = UDim2.new(newProgress, size.X.Offset, size.Y.Scale, size.Y.Offset),
			}, activeTweens)
			task.wait(gachaTimes.LevelUp)
			if token ~= activeToken.Value then
				return
			end
			setText(levelUpText, string.format("Lv.%d", tonumber(payload.Level) or 1))
			local newRate = calculateRate(figurineInfo, payload.Level, payload.Rarity)
			setText(levelUpSpeed, formatSpeedText(newRate))
		end
		task.wait(gachaTimes.ResultHold)
		if token ~= activeToken.Value then
			return
		end
	end

	tweenObject(resultFrame, TweenInfo.new(gachaTimes.SlideOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = endPos,
	}, activeTweens)
	if levelUpFrame and levelUpFrame.Visible then
		tweenObject(levelUpFrame, TweenInfo.new(gachaTimes.SlideOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = levelEndPos or endPos,
		}, activeTweens)
	end

	task.wait(gachaTimes.SlideOut)
	if token ~= activeToken.Value then
		return
	end

	resultFrame.Visible = false
	if levelUpFrame then
		levelUpFrame.Visible = false
	end
	restoreLayout(resultFrame, layoutResult)
	if levelUpFrame and layoutLevel then
		restoreLayout(levelUpFrame, layoutLevel)
	end
	restoreBackpack()
end

local function ensureLabubuEvents()
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		return nil
	end
	return eventsFolder:WaitForChild("LabubuEvents", 10)
end

local function bindOpenEggResult()
	local labubuEvents = ensureLabubuEvents()
	if not labubuEvents then
		warn("[GachaResult] LabubuEvents not found")
		return
	end
	local event = labubuEvents:WaitForChild("OpenEggResult", 10)
	if not event or not event:IsA("RemoteEvent") then
		warn("[GachaResult] OpenEggResult event not found")
		return
	end
	event.OnClientEvent:Connect(function(capsuleId, figurineId, isNew, rarity, prevLevel, prevExp, level, exp, maxLevel)
		playSequence({
			CapsuleId = capsuleId,
			FigurineId = figurineId,
			IsNew = isNew == true,
			Rarity = rarity,
			PrevLevel = prevLevel,
			PrevExp = prevExp,
			Level = level,
			Exp = exp,
			MaxLevel = maxLevel,
		})
	end)
end

bindOpenEggResult()
