--[[
鑴氭湰鍚嶇О: FigurineService
鑴氭湰绫诲瀷: ModuleScript
鑴氭湰浣嶇疆: ServerScriptService/Server/FigurineService
鐗堟湰: V2.0
鑱岃矗: 鎵嬪姙鎶藉彇/鎽嗘斁/寰呴鍙栦骇甯?淇℃伅灞曠ず/鍗囩骇琛ㄧ幇
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local FigurineConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FigurineConfig"))
local FigurinePoolConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FigurinePoolConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UpgradeConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FormatHelper = require(Modules:WaitForChild("FormatHelper"))

local FigurineService = {}
FigurineService.__index = FigurineService

local rng = Random.new()
local playerStates = {} -- [userId] = {Active, LoopStarted, UiEntries, ButtonConnections, TouchStates, PlatformTweens, ModelTweens, ButtonEffects}

local CLAIM_COOLDOWN = 0.5
local CLAIM_EFFECT_DEFAULT_COUNT = 25
local CLAIM_EFFECT_LIFETIME = 3
local CLAIM_EFFECT_FOLDER_NAME = "Effect"
local CLAIM_EFFECT_TEMPLATE_NAME = "EffectTouchMoney"
local CLAIM_EFFECT_DEBUG = false
local PLATFORM_EFFECT_TEMPLATE_NAME = "EffectPlatformUp"
local PLATFORM_MIN_Y = 1
local PLATFORM_MAX_Y = 5
local UI_UPDATE_INTERVAL = 1

local function formatHomeName(index)
	return string.format("%s%02d", GameConfig.HomeSlotPrefix, index)
end

local function getHomeFolder(player)
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

local function getFigurineFolder(homeFolder)
	if not homeFolder then
		return nil
	end
	local folder = homeFolder:FindFirstChild("Figurines")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Figurines"
		folder.Parent = homeFolder
	end
	return folder
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

local function resolveClaimButton(homeFolder, path)
	if not homeFolder or type(path) ~= "string" or path == "" then
		return nil
	end
	local root = homeFolder:FindFirstChild("ClaimButton")
	if not root then
		return nil
	end
	local current = root
	for _, segment in ipairs(string.split(path, "/")) do
		if segment ~= "" then
			current = current:FindFirstChild(segment)
			if not current then
				return nil
			end
		end
	end
	if current:IsA("BasePart") then
		return current
	end
	return nil
end

local function resolveCFrame(node)
	if node:IsA("BasePart") then
		return node.CFrame
	end
	if node:IsA("Attachment") then
		return node.WorldCFrame
	end
	if node:IsA("Model") then
		return node:GetPivot()
	end
	return nil
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

local function getBottomAlignedCFrame(baseCFrame, baseSizeY, targetSizeY)
	local deltaY = (targetSizeY - baseSizeY) / 2
	return baseCFrame * CFrame.new(0, deltaY, 0)
end

local function setAnchored(model, anchored)
	if model:IsA("BasePart") then
		model.Anchored = anchored
	end
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = anchored
		end
	end
end

local function getPrimaryPart(model)
	if model:IsA("BasePart") then
		return model
	end
	if model:IsA("Model") then
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function getModelBounds(model)
	local pivot = model:GetPivot()
	local bboxCFrame, bboxSize = model:GetBoundingBox()
	local offsetWorld = bboxCFrame.Position - pivot.Position
	local offsetLocal = pivot:VectorToObjectSpace(offsetWorld)
	return bboxSize, offsetLocal
end

local function getRotationOnly(cframe)
	return CFrame.fromMatrix(Vector3.zero, cframe.RightVector, cframe.UpVector, cframe.LookVector)
end

local function getFigurinePivotCFrame(platformCFrame, platformSizeY, modelSize, modelOffset, modelRotation)
	local topY = platformCFrame.Position.Y + platformSizeY / 2
	local targetCenter = Vector3.new(platformCFrame.Position.X, topY + modelSize.Y / 2, platformCFrame.Position.Z)
	local offsetWorld = modelRotation and modelRotation:VectorToWorldSpace(modelOffset) or modelOffset
	local pivotPos = targetCenter - offsetWorld
	if modelRotation then
		return CFrame.new(pivotPos) * modelRotation
	end
	return CFrame.new(pivotPos)
end

local function createModelTween(model, startCFrame, targetCFrame, duration, state)
	local pivotValue = Instance.new("CFrameValue")
	pivotValue.Value = startCFrame
	model:PivotTo(startCFrame)

	local conn
	local cleaned = false
	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if pivotValue then
			pivotValue:Destroy()
			pivotValue = nil
		end
	end

	conn = pivotValue.Changed:Connect(function(value)
		if model.Parent then
			model:PivotTo(value)
		end
	end)

	local tween = TweenService:Create(pivotValue, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Value = targetCFrame })
	tween.Completed:Connect(function()
		cleanup()
		if state and state.ModelTweens then
			state.ModelTweens[model] = nil
		end
	end)
	if state and state.ModelTweens then
		state.ModelTweens[model] = { Tween = tween, Cleanup = cleanup }
	end
	tween:Play()
end

local function hasFigurineModel(folder, figurineId, ownerUserId)
	if not folder then
		return false
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:GetAttribute("FigurineId") == figurineId and child:GetAttribute("OwnerUserId") == ownerUserId then
			return true
		end
	end
	return false
end

local function findFigurineModel(folder, figurineId, ownerUserId)
	if not folder then
		return nil
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:GetAttribute("FigurineId") == figurineId and child:GetAttribute("OwnerUserId") == ownerUserId then
			return child
		end
	end
	return nil
end

local function getPlayerState(player)
	local state = playerStates[player.UserId]
	if not state then
		state = {
			Active = true,
			LoopStarted = false,
			UiEntries = {},
			ButtonConnections = {},
			TouchStates = {},
			PlatformTweens = {},
			ModelTweens = {},
			ButtonEffects = {},
		}
		playerStates[player.UserId] = state
	end
	return state
end

local function getPlayerFromHit(hit)
	if not hit then
		return nil
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function collectClaimEmitters(button)
	if not button then
		return nil
	end
	local emitters = {}
	for _, obj in ipairs(button:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = false
			table.insert(emitters, obj)
		end
	end
	if #emitters == 0 then
		return nil
	end
	return emitters
end

local function playClaimEmitters(emitters)
	if not emitters then
		return
	end
	for _, emitter in ipairs(emitters) do
		if emitter.Parent then
			local count = tonumber(emitter:GetAttribute("BurstCount")) or CLAIM_EFFECT_DEFAULT_COUNT
			if count > 0 then
				emitter:Emit(count)
			end
		end
	end
end

local function collectEmittersFromInstances(instances)
	if not instances then
		return nil
	end
	local emitters = {}
	for _, obj in ipairs(instances) do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = false
			table.insert(emitters, obj)
		end
		for _, child in ipairs(obj:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
				table.insert(emitters, child)
			end
		end
	end
	if #emitters == 0 then
		return nil
	end
	return emitters
end

local function cloneEffectChildren(template, targetParent)
	local clones = {}
	for _, child in ipairs(template:GetChildren()) do
		local clone = child:Clone()
		clone.Parent = targetParent
		table.insert(clones, clone)
		Debris:AddItem(clone, CLAIM_EFFECT_LIFETIME)
	end
	return clones
end

local function clonePlatformEffect(platform)
	if not platform then
		return nil
	end
	local template = ReplicatedStorage:FindFirstChild(PLATFORM_EFFECT_TEMPLATE_NAME)
	if not template then
		return nil
	end
	local clones = {}
	for _, child in ipairs(template:GetChildren()) do
		local clone = child:Clone()
		clone.Parent = platform
		table.insert(clones, clone)
	end
	if #clones == 0 then
		return nil
	end
	return clones
end

local function cleanupEffectInstances(instances)
	if not instances then
		return
	end
	for _, inst in ipairs(instances) do
		if inst and inst.Parent then
			inst:Destroy()
		end
	end
end

local cachedClaimEffect

local function resolveClaimEffectTemplate()
	if cachedClaimEffect and cachedClaimEffect.Parent then
		return cachedClaimEffect
	end
	local function findIn(container)
		if not container then
			return nil
		end
		local folder = container:FindFirstChild(CLAIM_EFFECT_FOLDER_NAME)
		if folder then
			local template = folder:FindFirstChild(CLAIM_EFFECT_TEMPLATE_NAME)
			if template then
				return template
			end
		end
		return container:FindFirstChild(CLAIM_EFFECT_TEMPLATE_NAME)
	end
	cachedClaimEffect = findIn(ServerStorage) or findIn(ReplicatedStorage)
	return cachedClaimEffect
end

local function resolveClaimEffectTarget(button)
	if not button then
		return nil
	end
	local touch = button:FindFirstChild("Touch")
	if touch then
		if touch:IsA("BasePart") or touch:IsA("Attachment") then
			return touch
		end
	end
	return button
end

local function spawnClaimEffect(button, fallbackEmitters)
	local template = resolveClaimEffectTemplate()
	local target = resolveClaimEffectTarget(button)
	local targetCFrame
	local targetParent
	if target then
		if target:IsA("Attachment") then
			targetCFrame = target.WorldCFrame
			targetParent = target.Parent
		elseif target:IsA("BasePart") then
			targetCFrame = target.CFrame
			targetParent = target
		end
	end
	if not targetCFrame then
		targetCFrame = button.CFrame
	end
	if not targetParent then
		targetParent = Workspace
	end

	if template then
		if not targetParent or not targetParent:IsA("BasePart") then
			if CLAIM_EFFECT_DEBUG then
				warn("[FigurineService] ClaimEffect target invalid, fallback to button emitters")
			end
			playClaimEmitters(fallbackEmitters)
			return
		end
		local clones = cloneEffectChildren(template, targetParent)
		local emitters = collectEmittersFromInstances(clones)
		if not emitters and CLAIM_EFFECT_DEBUG then
			warn("[FigurineService] ClaimEffect template has no ParticleEmitter")
		end
		playClaimEmitters(emitters)
		return
	end
	if CLAIM_EFFECT_DEBUG then
		warn("[FigurineService] ClaimEffect template missing, fallback to button emitters")
	end
	playClaimEmitters(fallbackEmitters)
end

local function getFigurineRate(player, figurineInfo)
	if not player or not figurineInfo then
		return 0
	end
	local state = DataService:EnsureFigurineState(player, figurineInfo.Id)
	return DataService:CalculateFigurineRate(figurineInfo, state)
end

local function getPendingCoins(player, figurineId, rate)
	local state = DataService:EnsureFigurineState(player, figurineId)
	if not state then
		return 0
	end
	local lastCollect = tonumber(state.LastCollectTime) or os.time()
	local elapsed = math.max(0, os.time() - lastCollect)
	local capSeconds = tonumber(GameConfig.FigurineCoinCapSeconds) or 0
	if capSeconds > 0 then
		elapsed = math.min(elapsed, capSeconds)
	end
	local pending = rate * elapsed
	if pending < 0 then
		pending = 0
	end
	return math.floor(pending + 0.0001)
end

local function updateMoneyLabel(player, figurineId, entry)
	if not entry or not entry.MoneyLabel or not entry.MoneyLabel.Parent then
		return
	end
	local figurineInfo = entry.FigurineInfo or FigurineConfig.GetById(figurineId)
	if not figurineInfo then
		return
	end
	local rate = getFigurineRate(player, figurineInfo)
	entry.Rate = rate
	local pending = getPendingCoins(player, figurineId, rate)
	local pendingText = FormatHelper.FormatCoinsShort(pending, true)
	local rateText = FormatHelper.FormatCoinsShort(rate, true)
	entry.MoneyLabel.Text = string.format("%s/(%s/S)", pendingText, rateText)
end

local function updateLevelLabel(player, figurineId, entry)
	if not entry then
		return
	end
	local state = DataService:EnsureFigurineState(player, figurineId)
	if not state then
		return
	end
	local level = tonumber(state.Level) or 1
	local exp = tonumber(state.Exp) or 0
	local maxLevel = UpgradeConfig.GetMaxLevel()
	local progress = 0
	if level >= maxLevel then
		level = maxLevel
		progress = 1
	else
		local required = UpgradeConfig.GetRequiredExp(level) or 0
		if required > 0 then
			progress = math.clamp(exp / required, 0, 1)
		end
	end
	if entry.LevelLabel and entry.LevelLabel:IsA("TextLabel") then
		entry.LevelLabel.Text = string.format("LV.%d", level)
	end
	if entry.ProgressBar and entry.ProgressBar:IsA("ImageLabel") then
		local size = entry.ProgressBar.Size
		entry.ProgressBar.Size = UDim2.new(progress, size.X.Offset, size.Y.Scale, size.Y.Offset)
	end
end

local function attachInfoGui(platform)
	local infoFolder = ReplicatedStorage:FindFirstChild("InfoPart")
	if not infoFolder then
		warn("[FigurineService] InfoPart missing in ReplicatedStorage")
		return nil
	end
	local template = infoFolder:FindFirstChild("Info")
	if not template or not template:IsA("SurfaceGui") then
		warn("[FigurineService] Info SurfaceGui missing")
		return nil
	end

	local existing = platform:FindFirstChild("Info")
	if existing and existing:IsA("SurfaceGui") then
		existing.Face = Enum.NormalId.Front
		return existing
	end

	local gui = template:Clone()
	gui.Name = "Info"
	gui.Face = Enum.NormalId.Front
	gui.Parent = platform
	return gui
end

local function registerUiEntry(player, figurineInfo, platform, infoGui)
	local nameLabel
	local moneyLabel
	local levelLabel
	local progressBar
	if infoGui then
		nameLabel = infoGui:FindFirstChild("Name", true)
		moneyLabel = infoGui:FindFirstChild("Money", true)
		levelLabel = infoGui:FindFirstChild("LevelText", true)
		progressBar = infoGui:FindFirstChild("ProgressBar", true)
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = figurineInfo.Name
		end
	end
	local entry = {
		Platform = platform,
		InfoGui = infoGui,
		NameLabel = nameLabel,
		MoneyLabel = moneyLabel,
		LevelLabel = levelLabel,
		ProgressBar = progressBar,
		Rate = getFigurineRate(player, figurineInfo),
		FigurineInfo = figurineInfo,
	}
	local state = getPlayerState(player)
	state.UiEntries[figurineInfo.Id] = entry
	updateMoneyLabel(player, figurineInfo.Id, entry)
	updateLevelLabel(player, figurineInfo.Id, entry)
end

local function setupShowcasePlatform(player, figurineInfo, animate)
	local homeFolder = getHomeFolder(player)
	if not homeFolder then
		return
	end
	local platform = resolvePlatform(homeFolder, figurineInfo.ShowcasePath)
	if not platform then
		warn(string.format("[FigurineService] Platform missing: %s", tostring(figurineInfo.ShowcasePath)))
		return
	end
	local figurineFolder = getFigurineFolder(homeFolder)
	local model = findFigurineModel(figurineFolder, figurineInfo.Id, player.UserId)
	local modelSize
	local modelOffset
	local modelRotation
	if model then
		modelSize, modelOffset = getModelBounds(model)
		local baseRotation = model:GetAttribute("BaseRotation")
		if typeof(baseRotation) ~= "CFrame" then
			local modelRoot = ReplicatedStorage:FindFirstChild("LBB")
			local resource = figurineInfo and (figurineInfo.ModelResource or figurineInfo.ModelName)
			local source = modelRoot and resource and resolveModelResource(modelRoot, resource)
			local sourceCFrame = source and resolveCFrame(source)
			if sourceCFrame then
				baseRotation = getRotationOnly(sourceCFrame)
			else
				baseRotation = getRotationOnly(model:GetPivot())
			end
		end
		modelRotation = getRotationOnly(platform.CFrame) * baseRotation
	end

	local function attach()
		local infoGui = attachInfoGui(platform)
		registerUiEntry(player, figurineInfo, platform, infoGui)
	end

	if animate then
		local state = getPlayerState(player)
		local duration = 2
		local baseCFrame = platform.CFrame
		local baseSize = platform.Size
		local startSize = Vector3.new(baseSize.X, PLATFORM_MIN_Y, baseSize.Z)
		local targetSize = Vector3.new(baseSize.X, PLATFORM_MAX_Y, baseSize.Z)
		local startCFrame = getBottomAlignedCFrame(baseCFrame, baseSize.Y, startSize.Y)
		local targetCFrame = getBottomAlignedCFrame(baseCFrame, baseSize.Y, targetSize.Y)
		platform.Size = startSize
		platform.CFrame = startCFrame
		local platformEffects = clonePlatformEffect(platform)
		if model and modelSize and modelOffset then
			local startModelCFrame = getFigurinePivotCFrame(startCFrame, startSize.Y, modelSize, modelOffset, modelRotation)
			local targetModelCFrame = getFigurinePivotCFrame(targetCFrame, targetSize.Y, modelSize, modelOffset, modelRotation)
			createModelTween(model, startModelCFrame, targetModelCFrame, duration, state)
		end
		local tween = TweenService:Create(platform, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = targetSize, CFrame = targetCFrame })
		state.PlatformTweens[platform] = tween
		tween.Completed:Connect(function(playbackState)
			cleanupEffectInstances(platformEffects)
			platformEffects = nil
			state.PlatformTweens[platform] = nil
			if playbackState ~= Enum.PlaybackState.Completed then
				return
			end
			local currentState = playerStates[player.UserId]
			if not currentState or not currentState.Active then
				local currentCFrame = platform.CFrame
				local currentSize = platform.Size
				local minSize = Vector3.new(currentSize.X, PLATFORM_MIN_Y, currentSize.Z)
				platform.Size = minSize
				platform.CFrame = getBottomAlignedCFrame(currentCFrame, currentSize.Y, minSize.Y)
				return
			end
			attach()
		end)
		tween:Play()
	else
		local baseCFrame = platform.CFrame
		local baseSize = platform.Size
		local targetSize = Vector3.new(baseSize.X, PLATFORM_MAX_Y, baseSize.Z)
		platform.Size = targetSize
		platform.CFrame = getBottomAlignedCFrame(baseCFrame, baseSize.Y, targetSize.Y)
		if model and modelSize and modelOffset then
			local targetModelCFrame = getFigurinePivotCFrame(platform.CFrame, targetSize.Y, modelSize, modelOffset, modelRotation)
			model:PivotTo(targetModelCFrame)
		end
		attach()
	end
end

local function resetShowcasePlatform(entry)
	if not entry or not entry.Platform then
		return
	end
	local platform = entry.Platform
	if not platform.Parent then
		return
	end
	local infoGui = entry.InfoGui or platform:FindFirstChild("Info")
	if infoGui and infoGui:IsA("SurfaceGui") then
		infoGui:Destroy()
	end
	local baseCFrame = platform.CFrame
	local baseSize = platform.Size
	local minSize = Vector3.new(baseSize.X, PLATFORM_MIN_Y, baseSize.Z)
	platform.Size = minSize
	platform.CFrame = getBottomAlignedCFrame(baseCFrame, baseSize.Y, minSize.Y)
end

local function bindClaimButton(player, figurineInfo)
	local homeFolder = getHomeFolder(player)
	if not homeFolder then
		return
	end
	local button = resolveClaimButton(homeFolder, figurineInfo.ClaimButtonPath)
	if not button then
		warn(string.format("[FigurineService] ClaimButton missing: %s", tostring(figurineInfo.ClaimButtonPath)))
		return
	end

	local state = getPlayerState(player)
	if state.ButtonConnections[button] then
		return
	end

	local touchState = {
		IsTouching = false,
		LastTrigger = 0,
		TouchingParts = {},
	}
	state.TouchStates[button] = touchState
	local emitters = state.ButtonEffects[button]
	if emitters == nil then
		emitters = collectClaimEmitters(button)
		state.ButtonEffects[button] = emitters
	end

	local function onTouched(hit)
		local hitPlayer = getPlayerFromHit(hit)
		if hitPlayer ~= player then
			return
		end
		if hit and not touchState.TouchingParts[hit] then
			touchState.TouchingParts[hit] = true
		end
		if touchState.IsTouching then
			return
		end
		local now = os.clock()
		if now - touchState.LastTrigger < CLAIM_COOLDOWN then
			touchState.IsTouching = true
			return
		end
		touchState.IsTouching = true
		touchState.LastTrigger = now
		FigurineService:CollectCoins(player, figurineInfo.Id)
		spawnClaimEffect(button, emitters)
		local entry = state.UiEntries[figurineInfo.Id]
		updateMoneyLabel(player, figurineInfo.Id, entry)
	end

	local function onTouchEnded(hit)
		local hitPlayer = getPlayerFromHit(hit)
		if hitPlayer ~= player then
			return
		end
		if hit then
			touchState.TouchingParts[hit] = nil
		end
		if next(touchState.TouchingParts) == nil then
			touchState.IsTouching = false
		end
	end

	local connTouched = button.Touched:Connect(onTouched)
	local connEnded = button.TouchEnded:Connect(onTouchEnded)
	state.ButtonConnections[button] = { connTouched, connEnded }
end

local function placeFigurineModel(player, figurineInfo)
	local homeFolder = getHomeFolder(player)
	if not homeFolder then
		return false
	end
	local targetNode = resolveShowcaseNode(homeFolder, figurineInfo.ShowcasePath)
	if not targetNode then
		warn(string.format("[FigurineService] Showcase path missing: %s", tostring(figurineInfo.ShowcasePath)))
		return false
	end

	local platform = resolvePlatform(homeFolder, figurineInfo.ShowcasePath)
	local targetCFrame = platform and platform.CFrame or resolveCFrame(targetNode)
	if not targetCFrame then
		warn(string.format("[FigurineService] Showcase node invalid: %s", targetNode.Name))
		return false
	end

	local figurineFolder = getFigurineFolder(homeFolder)
	if hasFigurineModel(figurineFolder, figurineInfo.Id, player.UserId) then
		return false
	end

	local modelRoot = ReplicatedStorage:WaitForChild("LBB")
	local resource = figurineInfo.ModelResource or figurineInfo.ModelName
	local source = resolveModelResource(modelRoot, resource)
	if not source then
		warn(string.format("[FigurineService] Figurine model missing: %s", tostring(resource)))
		return false
	end

	local model = source:Clone()
	model.Name = string.format("Figurine_%d", figurineInfo.Id)
	model:SetAttribute("FigurineId", figurineInfo.Id)
	model:SetAttribute("FigurineName", figurineInfo.Name)
	model:SetAttribute("Quality", figurineInfo.Quality)
	model:SetAttribute("Rarity", figurineInfo.Rarity)
	model:SetAttribute("OwnerUserId", player.UserId)

	local primary = getPrimaryPart(model)
	if model:IsA("Model") and not model.PrimaryPart and primary then
		model.PrimaryPart = primary
	end
	if not primary then
		warn("[FigurineService] Figurine model missing BasePart")
		model:Destroy()
		return false
	end

	setAnchored(model, true)
	local baseRotation = getRotationOnly(model:GetPivot())
	model:SetAttribute("BaseRotation", baseRotation)
	local modelRotation = platform and (getRotationOnly(platform.CFrame) * baseRotation) or baseRotation
	if platform then
		local modelSize, modelOffset = getModelBounds(model)
		local placementCFrame = getFigurinePivotCFrame(platform.CFrame, platform.Size.Y, modelSize, modelOffset, modelRotation)
		model:PivotTo(placementCFrame)
	else
		model:PivotTo(CFrame.new(targetCFrame.Position) * modelRotation)
	end
	model.Parent = figurineFolder
	return true
end

local function pickRandomFigurine(poolId)
	local pool = FigurinePoolConfig.GetPool(poolId)
	if not pool then
		warn(string.format("[FigurineService] Pool not found: %s", tostring(poolId)))
		return nil
	end

	local totalWeight = 0
	for _, entry in ipairs(pool) do
		local weight = entry.Weight or 0
		if weight > 0 then
			totalWeight += weight
		end
	end
	if totalWeight <= 0 then
		return nil
	end

	local roll = rng:NextNumber(0, totalWeight)
	local acc = 0
	for _, entry in ipairs(pool) do
		local weight = entry.Weight or 0
		if weight > 0 then
			acc += weight
			if roll <= acc then
				return entry.FigurineId
			end
		end
	end

	local lastEntry = pool[#pool]
	return lastEntry and lastEntry.FigurineId or nil
end

local function startUiLoop(player, state)
	if state.LoopStarted then
		return
	end
	state.LoopStarted = true

	task.spawn(function()
		while state.Active and player.Parent do
			for figurineId, entry in pairs(state.UiEntries) do
				if not entry.Platform or not entry.Platform.Parent then
					state.UiEntries[figurineId] = nil
				else
					updateMoneyLabel(player, figurineId, entry)
				end
			end
			task.wait(UI_UPDATE_INTERVAL)
		end
	end)
end

local function triggerCameraFocus(player, figurineId)
	if not player or not player.Parent then
		return
	end
	player:SetAttribute("CameraFocusFigurineId", figurineId)
	local seq = tonumber(player:GetAttribute("CameraFocusSeq")) or 0
	player:SetAttribute("CameraFocusSeq", seq + 1)
end

function FigurineService:CollectCoins(player, figurineId)
	local figurineInfo = FigurineConfig.GetById(figurineId)
	if not figurineInfo then
		return 0
	end
	local rate = getFigurineRate(player, figurineInfo)
	local pending = getPendingCoins(player, figurineId, rate)
	if pending <= 0 then
		return 0
	end
	DataService:AddCoins(player, pending)
	DataService:SetFigurineLastCollectTime(player, figurineId, os.time())
	return pending
end

function FigurineService:GetTotalPendingCoins(player)
	local figurines = DataService:GetFigurines(player)
	if type(figurines) ~= "table" then
		return 0
	end
	local total = 0
	for figurineId, owned in pairs(figurines) do
		if owned then
			local info = FigurineConfig.GetById(tonumber(figurineId) or figurineId)
			if info then
				local rate = getFigurineRate(player, info)
				local pending = getPendingCoins(player, figurineId, rate)
				if pending > 0 then
					total += pending
				end
			end
		end
	end
	return total
end

function FigurineService:CollectAllCoins(player, multiplier)
	local figurines = DataService:GetFigurines(player)
	if type(figurines) ~= "table" then
		return 0
	end
	multiplier = tonumber(multiplier) or 1
	if multiplier < 1 then
		multiplier = 1
	end
	local total = 0
	local now = os.time()
	for figurineId, owned in pairs(figurines) do
		if owned then
			local info = FigurineConfig.GetById(tonumber(figurineId) or figurineId)
			if info then
				local rate = getFigurineRate(player, info)
				local pending = getPendingCoins(player, figurineId, rate)
				if pending > 0 then
					total += pending
					DataService:SetFigurineLastCollectTime(player, figurineId, now)
				end
			end
		end
	end
	local grant = total * multiplier
	if grant > 0 then
		DataService:AddCoins(player, grant)
	end
	return grant
end


function FigurineService:BindPlayer(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end

	local state = getPlayerState(player)

	for figurineId, owned in pairs(data.Figurines) do
		if owned then
			local info = FigurineConfig.GetById(figurineId)
			if info then
				DataService:EnsureFigurineState(player, figurineId)
				placeFigurineModel(player, info)
				setupShowcasePlatform(player, info, false)
				bindClaimButton(player, info)
			end
		end
	end

	startUiLoop(player, state)
end

function FigurineService:UnbindPlayer(player)
	local state = playerStates[player.UserId]
	if state then
		state.Active = false
		for _, tween in pairs(state.PlatformTweens) do
			tween:Cancel()
		end
		for _, entry in pairs(state.ModelTweens) do
			if entry.Tween then
				entry.Tween:Cancel()
			end
			if entry.Cleanup then
				entry.Cleanup()
			end
		end
		for _, entry in pairs(state.UiEntries) do
			resetShowcasePlatform(entry)
		end
		for _, conns in pairs(state.ButtonConnections) do
			for _, conn in ipairs(conns) do
				conn:Disconnect()
			end
		end
		playerStates[player.UserId] = nil
	end

	local homeFolder = getHomeFolder(player)
	if not homeFolder then
		return
	end
	local figurineFolder = homeFolder:FindFirstChild("Figurines")
	if figurineFolder then
		for _, child in ipairs(figurineFolder:GetChildren()) do
			if child:GetAttribute("OwnerUserId") == player.UserId then
				child:Destroy()
			end
		end
	end
end

function FigurineService:GrantFromCapsule(player, capsuleInfo, presentDelaySeconds)
	if not capsuleInfo or not capsuleInfo.PoolId then
		warn("[FigurineService] Capsule missing PoolId")
		return nil, false
	end

	local figurineId = pickRandomFigurine(capsuleInfo.PoolId)
	if not figurineId then
		warn("[FigurineService] pickRandomFigurine returned nil")
		return nil, false
	end

	local figurineInfo = FigurineConfig.GetById(figurineId)
	if not figurineInfo then
		warn(string.format("[FigurineService] Figurine config missing: %s", tostring(figurineId)))
		return nil, false
	end

	local result = DataService:AddFigurine(player, figurineId, capsuleInfo.Rarity)
	local added = result and result.IsNew
	if added then
		local function present()
			if not player or not player.Parent then
				return
			end
			placeFigurineModel(player, figurineInfo)
			setupShowcasePlatform(player, figurineInfo, true)
			bindClaimButton(player, figurineInfo)
			triggerCameraFocus(player, figurineId)
		end
		local delaySeconds = tonumber(presentDelaySeconds) or 0
		if delaySeconds > 0 then
			task.delay(delaySeconds, present)
		else
			present()
		end
	elseif result then
		local state = getPlayerState(player)
		local entry = state.UiEntries[figurineId]
		updateLevelLabel(player, figurineId, entry)
		updateMoneyLabel(player, figurineId, entry)
	end

	return figurineInfo, result
end

return FigurineService
