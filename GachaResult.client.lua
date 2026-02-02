--[[
脚本名称: GachaResult
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/GachaResult
版本: V3.2
职责: 开盲盒结果界面与翻面/升级表现
]]

local ContentProvider = game:GetService("ContentProvider")
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
local BackpackVisibility = require(modulesFolder:WaitForChild("BackpackVisibility"))
local GuiResolver = require(modulesFolder:WaitForChild("GuiResolver"))

local gachaGui = GuiResolver.WaitForLayer(playerGui, { "GachaResult", "GachaResultGui", "GachaResultGUI" }, {
	"Result",
	"Cover",
	"LevelUp",
}, 30)
if not gachaGui then
	warn("[GachaResult] GachaResult gui not found")
	return
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
local resultLightBg = resultFrame:FindFirstChild("LightBg", true)
local gachaBg = gachaGui:FindFirstChild("Bg") or gachaGui:FindFirstChild("Bg", true)

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

local RARITY_TEXT_COLORS = {
	[1] = Color3.fromRGB(160, 160, 160),
	[2] = Color3.fromRGB(255, 255, 255),
	[3] = Color3.fromRGB(255, 255, 0),
	[4] = Color3.fromRGB(255, 85, 255),
}

local rainbowGradientTemplate

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

local function resolveGuiObject(target)
	if not target then
		return nil
	end
	if target:IsA("GuiObject") then
		return target
	end
	return target:FindFirstChildWhichIsA("GuiObject", true)
end

local function resolveImageTarget(target)
	if not target then
		return nil
	end
	if target:IsA("ImageLabel") or target:IsA("ImageButton") then
		return target
	end
	return target:FindFirstChildWhichIsA("ImageLabel", true)
		or target:FindFirstChildWhichIsA("ImageButton", true)
end

local function setVisible(guiObject, visible)
	local target = resolveGuiObject(guiObject)
	if target then
		target.Visible = visible
	end
end

local function setImage(imageObject, image)
	local target = resolveImageTarget(imageObject)
	if target then
		target.Image = image or ""
	end
end

local function preloadImageTargets(targets)
	if type(targets) ~= "table" then
		return
	end
	local instances = {}
	for _, target in ipairs(targets) do
		local resolved = resolveImageTarget(target)
		if resolved then
			table.insert(instances, resolved)
		end
	end
	if #instances > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(instances)
		end)
	end
end

local function resolveTextObject(target)
	if not target then
		return nil
	end
	if target:IsA("TextLabel") or target:IsA("TextButton") or target:IsA("TextBox") then
		return target
	end
	local label = target:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		return label
	end
	local button = target:FindFirstChildWhichIsA("TextButton", true)
	if button then
		return button
	end
	return target:FindFirstChildWhichIsA("TextBox", true)
end

local function setText(textObject, text)
	local target = resolveTextObject(textObject)
	if target then
		target.Text = text or ""
	end
end

local function getRainbowGradientTemplate()
	if rainbowGradientTemplate and rainbowGradientTemplate.Parent then
		return rainbowGradientTemplate
	end
	local capsuleInfo = ReplicatedStorage:FindFirstChild("CapsuleInfo")
	if not capsuleInfo then
		capsuleInfo = ReplicatedStorage:WaitForChild("CapsuleInfo", 2)
	end
	if not capsuleInfo then
		return nil
	end
	local rainbowNode = capsuleInfo:FindFirstChild("Rainbow", true)
	if not rainbowNode then
		return nil
	end
	local gradient = rainbowNode:FindFirstChildWhichIsA("UIGradient", true)
	if gradient then
		rainbowGradientTemplate = gradient
		return gradient
	end
	return nil
end

local function clearTextGradients(textObject)
	if not textObject then
		return
	end
	for _, child in ipairs(textObject:GetChildren()) do
		if child:IsA("UIGradient") then
			child:Destroy()
		end
	end
end

local function shouldShowRare(rarity)
	local value = tonumber(rarity) or 0
	return value > 1
end

local function applyRareStyle(textObject, rarity)
	local target = resolveTextObject(textObject)
	if not target then
		return
	end
	clearTextGradients(target)
	local rarityValue = tonumber(rarity) or 0
	if rarityValue == 5 then
		local template = getRainbowGradientTemplate()
		if template then
			local gradient = template:Clone()
			gradient.Parent = target
		end
		target.TextColor3 = Color3.fromRGB(255, 255, 255)
		return
	end
	local color = RARITY_TEXT_COLORS[rarityValue]
	if color then
		target.TextColor3 = color
	end
end

local function resolveIconNode(frame, fallback)
	if not frame then
		return fallback
	end
	local direct = frame:FindFirstChild("Icon")
	if direct then
		return direct
	end
	local namedImage = nil
	for _, descendant in ipairs(frame:GetDescendants()) do
		if descendant.Name == "Icon" and (descendant:IsA("ImageLabel") or descendant:IsA("ImageButton")) then
			return descendant
		end
		if not namedImage and (descendant:IsA("ImageLabel") or descendant:IsA("ImageButton")) then
			namedImage = descendant
		end
	end
	return fallback or namedImage
end

resultIcon = resolveIconNode(resultFrame, resultIcon)
levelUpIcon = resolveIconNode(levelUpFrame, levelUpIcon)

local preloadedAssets = {}

local function isAssetId(value)
	if type(value) ~= "string" or value == "" then
		return false
	end
	if value:find("rbxassetid://") then
		return true
	end
	if value:find("rbxasset://") then
		return true
	end
	if value:find("http://www.roblox.com/asset") or value:find("https://www.roblox.com/asset") then
		return true
	end
	return false
end

local function addPreloadAsset(targets, value)
	if not isAssetId(value) then
		return
	end
	if preloadedAssets[value] then
		return
	end
	preloadedAssets[value] = true
	table.insert(targets, value)
end

local function collectGuiImages(container, targets)
	if not container then
		return
	end
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			addPreloadAsset(targets, descendant.Image)
		end
	end
end

-- 同步预加载资源，确保加载完成后才返回
local function preloadAssets(assets)
	if #assets <= 0 then
		return
	end
	-- 分离字符串资源和实例
	local stringAssets = {}
	local instanceAssets = {}
	for _, asset in ipairs(assets) do
		if type(asset) == "string" then
			table.insert(stringAssets, asset)
		elseif typeof(asset) == "Instance" then
			table.insert(instanceAssets, asset)
		end
	end
	-- 预加载字符串资源
	if #stringAssets > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(stringAssets)
		end)
	end
	-- 预加载实例
	if #instanceAssets > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(instanceAssets)
		end)
	end
end

-- 预加载单个图片并等待完成
local function preloadImageSync(assetId)
	if type(assetId) ~= "string" or assetId == "" then
		return
	end
	pcall(function()
		ContentProvider:PreloadAsync({ assetId })
	end)
end

local function waitForAssetsPreloaded(timeoutSeconds)
	local timeout = tonumber(timeoutSeconds) or 10
	local startTime = os.clock()
	while os.clock() - startTime < timeout do
		if player:GetAttribute("AssetsPreloaded") == true then
			return true
		end
		task.wait(0.1)
	end
	return player:GetAttribute("AssetsPreloaded") == true
end

local function resolveModelResource(modelRoot, resource)
	if not modelRoot or type(resource) ~= "string" or resource == "" then
		return nil
	end
	local current = modelRoot
	for _, segment in ipairs(string.split(resource, "/")) do
		if segment ~= "" then
			current = current:FindFirstChild(segment)
			if not current then
				return nil
			end
		end
	end
	return current
end

local function preloadFigurineModel(figurineInfo)
	if not figurineInfo then
		return
	end
	local modelRoot = ReplicatedStorage:FindFirstChild("LBB")
	local resource = figurineInfo.ModelResource or figurineInfo.ModelName
	local source = resolveModelResource(modelRoot, resource)
	if not source then
		return
	end
	pcall(function()
		ContentProvider:PreloadAsync({ source })
	end)
	pcall(function()
		ContentProvider:PreloadAsync(source:GetDescendants())
	end)
end

local function preloadGachaAssets(capsuleInfo, figurineInfo)
	if not capsuleInfo or not figurineInfo then
		return
	end

	-- 收集所有需要预加载的图片资源ID
	local imageAssets = {}

	-- 盲盒图标和展示图
	local capsuleIcon = capsuleInfo.Icon or ""
	local capsuleDisplay = capsuleInfo.DisplayImage or ""
	if capsuleIcon ~= "" then
		table.insert(imageAssets, capsuleIcon)
	end
	if capsuleDisplay ~= "" and capsuleDisplay ~= capsuleIcon then
		table.insert(imageAssets, capsuleDisplay)
	end

	-- 手办图标
	local figurineIcon = figurineInfo.Icon or ""
	if figurineIcon ~= "" then
		table.insert(imageAssets, figurineIcon)
	end

	-- 先同步预加载所有图片资源（阻塞等待完成）
	if #imageAssets > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(imageAssets)
		end)
	end

	-- 预加载手办模型
	preloadFigurineModel(figurineInfo)

	-- 设置图片到UI（此时图片已经加载完成）
	setImage(resultCover, capsuleInfo.Icon or capsuleInfo.DisplayImage)
	setImage(resultIcon, figurineIcon)
	setImage(levelUpIcon, figurineIcon)
	preloadImageTargets({ resultCover, resultIcon, levelUpIcon })
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
local LIGHT_BG_ROTATION_TIME = 2
local ASSET_PRELOAD_TIMEOUT = 20

local activeToken = { Value = 0 }
local activeTweens = {}
local notifyGachaFinishedEvent = nil
local ensureLabubuEvents

local function setBackpackHidden(hidden)
	BackpackVisibility.SetHidden(playerGui, "GachaResult", hidden == true)
end

local function getNotifyGachaFinishedEvent()
	if notifyGachaFinishedEvent and notifyGachaFinishedEvent.Parent then
		return notifyGachaFinishedEvent
	end
	local labubuEvents = ensureLabubuEvents()
	if not labubuEvents then
		return nil
	end
	local event = labubuEvents:FindFirstChild("NotifyGachaFinished")
	if event and event:IsA("RemoteEvent") then
		notifyGachaFinishedEvent = event
		return event
	end
	return nil
end

local function notifyGachaFinished(figurineId)
	local event = getNotifyGachaFinishedEvent()
	if event then
		event:FireServer(figurineId)
	end
end

local function setGachaBgVisible(visible)
	if gachaBg and gachaBg:IsA("GuiObject") then
		gachaBg.Visible = visible == true
	end
end

local lightBgTween
local function stopLightBg()
	if lightBgTween then
		lightBgTween:Cancel()
		lightBgTween = nil
	end
	if resultLightBg and resultLightBg:IsA("GuiObject") then
		resultLightBg.Rotation = 0
		resultLightBg.Visible = false
	end
end

local function startLightBg()
	if not resultLightBg or not resultLightBg:IsA("GuiObject") then
		return
	end
	if lightBgTween then
		lightBgTween:Cancel()
		lightBgTween = nil
	end
	resultLightBg.Rotation = 0
	resultLightBg.Visible = true
	lightBgTween = TweenService:Create(resultLightBg, TweenInfo.new(LIGHT_BG_ROTATION_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
		Rotation = 360,
	})
	lightBgTween:Play()
end

local function cancelActive()
	activeToken.Value += 1
	for _, tween in ipairs(activeTweens) do
		tween:Cancel()
	end
	table.clear(activeTweens)
	stopLightBg()
	setGachaBgVisible(false)
	setBackpackHidden(false)
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
	local layoutResult
	local layoutLevel
	local function finalize()
		if token ~= activeToken.Value then
			return
		end
		stopLightBg()
		setGachaBgVisible(false)
		if resultFrame then
			resultFrame.Visible = false
			if layoutResult then
				restoreLayout(resultFrame, layoutResult)
			elseif baseLayoutResult then
				restoreLayout(resultFrame, baseLayoutResult)
			end
		end
		if levelUpFrame then
			levelUpFrame.Visible = false
			if layoutLevel then
				restoreLayout(levelUpFrame, layoutLevel)
			elseif baseLayoutLevel then
				restoreLayout(levelUpFrame, baseLayoutLevel)
			end
		end
		setBackpackHidden(false)
	end
	local ok, err = xpcall(function()

	if gachaGui:IsA("LayerCollector") then
		gachaGui.Enabled = true
	end
	setGachaBgVisible(true)

	local capsuleInfo = CapsuleConfig.GetById(payload.CapsuleId)
	local figurineInfo = FigurineConfig.GetById(payload.FigurineId)
	if not capsuleInfo or not figurineInfo then
		setBackpackHidden(false)
		return
	end
	local capsuleQuality = tonumber(capsuleInfo.Quality) or 0
	local figurineQuality = tonumber(figurineInfo.Quality) or capsuleQuality or 0

	setBackpackHidden(true)

	-- 等待资源预加载完成
	waitForAssetsPreloaded(ASSET_PRELOAD_TIMEOUT)
	if token ~= activeToken.Value then
		return
	end

	-- 先预加载本次需要的所有图片（阻塞等待完成）
	preloadGachaAssets(capsuleInfo, figurineInfo)
	if token ~= activeToken.Value then
		return
	end

	layoutResult = captureLayout(resultFrame)
	if not layoutResult then
		setBackpackHidden(false)
		return
	end
	layoutLevel = levelUpFrame and captureLayout(levelUpFrame) or nil

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
		if shouldShowRare(payload.Rarity) then
			setText(levelUpRare, getRarityName(payload.Rarity))
			applyRareStyle(levelUpRare, payload.Rarity)
			setVisible(levelUpRare, true)
		else
			setVisible(levelUpRare, false)
		end
		updateQualityIndicators(levelUpFrame, figurineQuality)
		setVisible(levelUpIcon, true)
		setVisible(levelUpName, true)
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

	startLightBg()
	setVisible(resultCover, false)
	updateQualityIndicators(resultFrame, figurineQuality)
	setImage(resultIcon, figurineInfo.Icon)
	setText(resultName, figurineInfo.Name)
	if shouldShowRare(payload.Rarity) then
		setText(resultRare, getRarityName(payload.Rarity))
		applyRareStyle(resultRare, payload.Rarity)
		setVisible(resultRare, true)
	else
		setVisible(resultRare, false)
	end
	setText(resultSpeed, formatSpeedText(tonumber(figurineInfo.BaseRate) or 0))
	setVisible(resultIcon, true)
	setVisible(resultName, true)
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

	notifyGachaFinished(payload.FigurineId)

	setGachaBgVisible(false)
	resultFrame.Visible = false
	if levelUpFrame then
		levelUpFrame.Visible = false
	end
	restoreLayout(resultFrame, layoutResult)
	if levelUpFrame and layoutLevel then
		restoreLayout(levelUpFrame, layoutLevel)
	end
	setBackpackHidden(false)
	end, debug.traceback)
	if not ok then
		warn(string.format("[GachaResult] playSequence failed: %s", tostring(err)))
		if token == activeToken.Value then
			cancelActive()
		end
	end
	finalize()
end

ensureLabubuEvents = function()
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
	notifyGachaFinishedEvent = labubuEvents:WaitForChild("NotifyGachaFinished", 10)
	if not notifyGachaFinishedEvent then
		warn("[GachaResult] NotifyGachaFinished event not found")
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
