--[[
脚本名称: IndexDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/IndexDisplay
版本: V2.7
职责: 手办索引界面显示与筛选]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local configFolder = ReplicatedStorage:WaitForChild("Config")
local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local FigurineConfig = require(configFolder:WaitForChild("FigurineConfig"))
local QualityConfig = require(configFolder:WaitForChild("QualityConfig"))
local BackpackVisibility = require(modulesFolder:WaitForChild("BackpackVisibility"))
local modelRoot = ReplicatedStorage:WaitForChild("LBB")

local mainGui = playerGui:WaitForChild("MainGui", 10)
if not mainGui then
	warn("[IndexDisplay] MainGui not found")
	return
end

local function resolveIndexButton()
	local button = mainGui:FindFirstChild("Index")
	if button and not button:IsA("GuiButton") then
		local nested = button:FindFirstChildWhichIsA("GuiButton", true)
		if nested then
			button = nested
		end
	end
	if button and button:IsA("GuiButton") then
		return button
	end
	local descendant = mainGui:FindFirstChild("Index", true)
	if descendant then
		if descendant:IsA("GuiButton") then
			return descendant
		end
		local nested = descendant:FindFirstChildWhichIsA("GuiButton", true)
		if nested then
			return nested
		end
	end
	return nil
end

local indexButton = resolveIndexButton()
if not indexButton then
	warn("[IndexDisplay] MainGui.Index not found")
end

local indexGui = playerGui:WaitForChild("Index", 10)
if not indexGui then
	warn("[IndexDisplay] Index screen gui not found")
	return
end

local indexBg = indexGui:WaitForChild("IndexBg", 10)
if not indexBg then
	warn("[IndexDisplay] IndexBg not found")
	return
end

local title = indexBg:WaitForChild("Title", 10)
if not title then
	warn("[IndexDisplay] IndexBg.Title not found")
	return
end

local closeButton = title:WaitForChild("CloseButton", 10)
if not closeButton then
	warn("[IndexDisplay] IndexBg.Title.CloseButton not found")
	return
end

local tabList = indexBg:FindFirstChild("TabList")
local tabScroll = tabList and tabList:FindFirstChild("ScrollingFrame")

local infoBg = indexBg:WaitForChild("InfoBg", 10)
if not infoBg then
	warn("[IndexDisplay] IndexBg.InfoBg not found")
	return
end

local listFrame = infoBg:WaitForChild("ScrollingFrame", 10)
if not listFrame then
	warn("[IndexDisplay] IndexBg.InfoBg.ScrollingFrame not found")
	return
end

local template = listFrame:WaitForChild("FigurineTemplate", 10)
if not template then
	warn("[IndexDisplay] FigurineTemplate not found")
	return
end

local bagGui = playerGui:FindFirstChild("Bag")
local bagBg = bagGui and bagGui:FindFirstChild("BagBg")

local checkGui = playerGui:WaitForChild("Check", 10)
if not checkGui then
	warn("[IndexDisplay] Check screen gui not found")
end

local checkBg = checkGui and checkGui:WaitForChild("CheckBg", 10)
if not checkBg then
	warn("[IndexDisplay] CheckBg not found")
end

local checkViewport = checkBg and checkBg:WaitForChild("ViewportFrame", 10)
if not checkViewport then
	warn("[IndexDisplay] CheckBg.ViewportFrame not found")
end

local checkExit = checkBg and checkBg:WaitForChild("Exit", 10)
if not checkExit then
	warn("[IndexDisplay] CheckBg.Exit not found")
end

local currentNumLabel = infoBg:FindFirstChild("CurrentNum", true)
local totalNumLabel = infoBg:FindFirstChild("TotalNum", true)
local currentIcon = infoBg:FindFirstChild("CurrentIcon", true)

template.Visible = false
if indexGui:IsA("LayerCollector") then
	indexGui.Enabled = true
end
if checkGui and checkGui:IsA("LayerCollector") then
	checkGui.Enabled = true
end
if checkBg then
	checkBg.Visible = false
end
if checkViewport then
	checkViewport.Active = true
end

local entriesById = {}
local entriesByQuality = {}
local totalAll = 0
local currentQuality = nil
local openIndex
local closeIndex
local openCheck
local closeCheck
local indexBound = false


local checkOpen = false
local lastCanvasPosition = nil
local currentCheckId = nil

local viewportWorld = nil
local viewportCamera = nil
local viewportModel = nil
local baseRotation = CFrame.new()
local currentYaw = 0
local currentPitch = 0

local dragActive = false
local hoverActive = false
local hoverLastPos = nil
local dragInput = nil
local dragStartPos = nil
local dragStartYaw = 0
local dragStartPitch = 0
local maxRotation = math.rad(30)
local rotationSpeed = 0.005
local inputBound = false

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

local function setIndexBackpackHidden(hidden)
	BackpackVisibility.SetHidden(playerGui, "Index", hidden == true)
end

local function setCheckBackpackHidden(hidden)
	BackpackVisibility.SetHidden(playerGui, "IndexCheck", hidden == true)
end

local function resolveModelResource(root, resource)
	if not root or type(resource) ~= "string" or resource == "" then
		return nil
	end
	local current = root
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

local function getRotationOnly(cframe)
	return CFrame.fromMatrix(Vector3.zero, cframe.RightVector, cframe.UpVector, cframe.LookVector)
end

local function setAnchored(model, anchored)
	if model:IsA("BasePart") then
		model.Anchored = anchored
		model.CanCollide = false
	end
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = anchored
			obj.CanCollide = false
		end
	end
end

local function setModelCFrame(model, cframe)
	if not model then
		return
	end
	if model:IsA("Model") then
		model:PivotTo(cframe)
	elseif model:IsA("BasePart") then
		model.CFrame = cframe
	end
end

local function applyIconToInstance(instance, icon)
	if instance:IsA("Decal") or instance:IsA("Texture") then
		instance.Texture = icon
	elseif instance:IsA("SurfaceAppearance") then
		instance.ColorMap = icon
	elseif instance:IsA("MeshPart") then
		instance.TextureID = icon
	elseif instance:IsA("SpecialMesh") then
		instance.TextureId = icon
	end
end

local function applyFigurineIcon(model, icon)
	if not model or type(icon) ~= "string" or icon == "" then
		return
	end
	applyIconToInstance(model, icon)
	for _, obj in ipairs(model:GetDescendants()) do
		applyIconToInstance(obj, icon)
	end
end

local function ensureViewportObjects()
	if not checkViewport then
		return false
	end
	if not viewportWorld then
		viewportWorld = Instance.new("WorldModel")
		viewportWorld.Name = "ViewportWorld"
		viewportWorld.Parent = checkViewport
	end
	if not viewportCamera then
		viewportCamera = Instance.new("Camera")
		viewportCamera.Name = "ViewportCamera"
		viewportCamera.Parent = checkViewport
	end
	viewportCamera.FieldOfView = 30
	checkViewport.CurrentCamera = viewportCamera
	viewportWorld:ClearAllChildren()
	return true
end

local function clearViewport()
	if viewportWorld then
		viewportWorld:ClearAllChildren()
	end
	viewportModel = nil
	currentCheckId = nil
	currentYaw = 0
	currentPitch = 0
end

local function setupViewportCamera(model, rotation)
	if not viewportCamera or not model then
		return
	end
	local bboxSize
	if model:IsA("Model") then
		local _, size = model:GetBoundingBox()
		bboxSize = size
	elseif model:IsA("BasePart") then
		bboxSize = model.Size
	else
		return
	end
	local maxSize = math.max(bboxSize.X, bboxSize.Y, bboxSize.Z)
	local halfFov = math.rad(viewportCamera.FieldOfView / 2)
	local distance = (maxSize / 2) / math.tan(halfFov)
	distance = distance * 1.25
	local frontDir = rotation:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local camPos = -frontDir.Unit * distance
	viewportCamera.CFrame = CFrame.lookAt(camPos, Vector3.zero, rotation.UpVector)
end

local function updateViewportRotation()
	if not viewportModel then
		return
	end
	local rotation = CFrame.Angles(currentPitch, currentYaw, 0)
	local finalRotation = baseRotation * rotation
	setModelCFrame(viewportModel, CFrame.new(0, 0, 0) * finalRotation)
end

local function loadCheckModel(figurineId)
	if not ensureViewportObjects() then
		return
	end
	local info = FigurineConfig.GetById and FigurineConfig.GetById(figurineId)
	if not info then
		warn(string.format("[IndexDisplay] Figurine info missing: %s", tostring(figurineId)))
		return
	end
	local resource = info.ModelResource or info.ModelName
	local source = resolveModelResource(modelRoot, resource)
	if not source then
		warn(string.format("[IndexDisplay] Figurine model missing: %s", tostring(resource)))
		return
	end

	local model = source:Clone()
	if model:IsA("Model") then
		local found = model:FindFirstChild("PartLbb", true)
		if found and found:IsA("BasePart") then
			local onlyPart = found:Clone()
			model:Destroy()
			model = onlyPart
		end
	elseif model:IsA("BasePart") then
		if model.Name ~= "PartLbb" then
			local found = model:FindFirstChild("PartLbb", true)
			if found and found:IsA("BasePart") then
				local onlyPart = found:Clone()
				model:Destroy()
				model = onlyPart
			end
		end
	end
	applyFigurineIcon(model, info.Icon)
	setAnchored(model, true)
	if model:IsA("Model") then
		local bboxCFrame = model:GetBoundingBox()
		local pivotPart = Instance.new("Part")
		pivotPart.Name = "ViewportPivot"
		pivotPart.Size = Vector3.new(0.2, 0.2, 0.2)
		pivotPart.Transparency = 1
		pivotPart.Anchored = true
		pivotPart.CanCollide = false
		pivotPart.CastShadow = false
		pivotPart.CFrame = bboxCFrame
		pivotPart.Parent = model
		model.PrimaryPart = pivotPart
	end
	model.Parent = viewportWorld

	baseRotation = getRotationOnly(model:IsA("Model") and model:GetPivot() or model.CFrame)
	currentYaw = 0
	currentPitch = 0
	viewportModel = model
	updateViewportRotation()
	setupViewportCamera(model, baseRotation)
end

local function bindViewportInput()
	if inputBound or not checkViewport then
		return
	end
	inputBound = true

	local useHoverRotation = UserInputService.MouseEnabled and not UserInputService.TouchEnabled

	local function isPointerInsideViewport(position)
		if not checkViewport then
			return false
		end
		local pos = checkViewport.AbsolutePosition
		local size = checkViewport.AbsoluteSize
		local x = position.X
		local y = position.Y
		return x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y
	end

	local function startDrag(input)
		if dragActive then
			return
		end
		dragActive = true
		dragInput = input
		dragStartPos = input.Position
		dragStartYaw = currentYaw
		dragStartPitch = currentPitch
	end

	checkViewport.InputBegan:Connect(function(input)
		if not checkOpen then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startDrag(input)
		end
	end)

	checkViewport.InputEnded:Connect(function(input)
		if input == dragInput then
			dragActive = false
			dragInput = nil
		end
	end)

	UserInputService.InputBegan:Connect(function(input)
		if not checkOpen then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if isPointerInsideViewport(input.Position) then
				startDrag(input)
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not checkOpen then
			return
		end

		if useHoverRotation and input.UserInputType == Enum.UserInputType.MouseMovement then
			if not isPointerInsideViewport(input.Position) then
				hoverActive = false
				hoverLastPos = nil
				return
			end
			if not hoverActive or not hoverLastPos then
				hoverActive = true
				hoverLastPos = input.Position
				return
			end
			local delta = input.Position - hoverLastPos
			hoverLastPos = input.Position
			currentYaw = math.clamp(currentYaw + delta.X * rotationSpeed, -maxRotation, maxRotation)
			currentPitch = math.clamp(currentPitch - delta.Y * rotationSpeed, -maxRotation, maxRotation)
			updateViewportRotation()
			return
		end

		if not dragActive then
			return
		end
		if dragInput and input ~= dragInput and input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local delta = input.Position - dragStartPos
		currentYaw = math.clamp(dragStartYaw + delta.X * rotationSpeed, -maxRotation, maxRotation)
		currentPitch = math.clamp(dragStartPitch - delta.Y * rotationSpeed, -maxRotation, maxRotation)
		updateViewportRotation()
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragActive = false
			dragInput = nil
		end
	end)
end

local function clearEntries()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:GetAttribute("IsIndexEntry") then
			child:Destroy()
		end
	end
	table.clear(entriesById)
	table.clear(entriesByQuality)
	totalAll = 0
end

local function setEntryOwned(entry, owned)
	if not entry then
		return
	end
	entry.Owned = owned == true
	if entry.NameLabel and entry.NameLabel:IsA("TextLabel") then
		entry.NameLabel.Visible = entry.Owned
	end
	if entry.Icon and (entry.Icon:IsA("ImageLabel") or entry.Icon:IsA("ImageButton")) then
		if entry.Owned then
			entry.Icon.ImageColor3 = entry.DefaultIconColor
		else
			entry.Icon.ImageColor3 = Color3.new(0, 0, 0)
		end
	end
	if entry.QuestionMark and entry.QuestionMark:IsA("GuiObject") then
		entry.QuestionMark.Visible = not entry.Owned
	end
	if entry.CheckButton and entry.CheckButton:IsA("GuiObject") then
		entry.CheckButton.Visible = entry.Owned
	end
end

local function buildEntries()
	clearEntries()
	local list = FigurineConfig.Figurines
	if type(list) ~= "table" then
		return
	end
	for index, info in ipairs(list) do
		local clone = template:Clone()
		clone.Name = string.format("Figurine_%s", tostring(info.Id))
		clone.Visible = true
		clone.LayoutOrder = index
		clone:SetAttribute("IsIndexEntry", true)
		clone:SetAttribute("FigurineId", info.Id)

		local icon = clone:FindFirstChild("Icon", true)
		if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
			icon.Image = info.Icon or ""
		end

		local nameLabel = clone:FindFirstChild("Name", true)
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = info.Name or tostring(info.Id)
		end

		updateQualityIndicators(clone, info.Quality)

		local questionMark = clone:FindFirstChild("QuestionMark", true)
		if questionMark and questionMark:IsA("GuiObject") then
			questionMark.Visible = false
		end

		local checkButton = clone:FindFirstChild("CheckIcon", true)
		if checkButton and checkButton:IsA("GuiObject") then
			checkButton.Visible = false
		end

		clone.Parent = listFrame

		local entry = {
			Id = info.Id,
			Quality = tonumber(info.Quality) or 0,
			Frame = clone,
			Icon = icon,
			NameLabel = nameLabel,
			QuestionMark = questionMark,
			CheckButton = checkButton,
			DefaultIconColor = icon and icon.ImageColor3 or Color3.new(1, 1, 1),
			Owned = false,
		}

		if checkButton and checkButton:IsA("GuiButton") then
			checkButton.Activated:Connect(function()
				if entry.Owned then
					openCheck(entry.Id)
				end
			end)
		end

		entriesById[info.Id] = entry
		local quality = entry.Quality
		if entriesByQuality[quality] == nil then
			entriesByQuality[quality] = {}
		end
		table.insert(entriesByQuality[quality], entry)
		totalAll += 1
	end
end

local function countOwnedForQuality(quality)
	local list = entriesByQuality[quality] or {}
	local owned = 0
	for _, entry in ipairs(list) do
		if entry.Owned then
			owned += 1
		end
	end
	return owned, #list
end

local function countOwnedTotal()
	local owned = 0
	for _, entry in pairs(entriesById) do
		if entry.Owned then
			owned += 1
		end
	end
	return owned, totalAll
end

local function updateCounters()
	if currentQuality then
		local owned, total = countOwnedForQuality(currentQuality)
		if currentNumLabel and currentNumLabel:IsA("TextLabel") then
			currentNumLabel.Text = string.format("%d/%d", owned, total)
		end
	end
	local ownedAll, total = countOwnedTotal()
	if totalNumLabel and totalNumLabel:IsA("TextLabel") then
		totalNumLabel.Text = string.format("%d/%d", ownedAll, total)
	end
end

local function applyFilter()
	for _, entry in pairs(entriesById) do
		entry.Frame.Visible = (entry.Quality == currentQuality)
	end
	updateCounters()
end

local function updateQualityIcon(quality)
	if not currentIcon then
		return
	end
	if not (currentIcon:IsA("ImageLabel") or currentIcon:IsA("ImageButton")) then
		return
	end
	local icon = ""
	if QualityConfig and type(QualityConfig.GetIcon) == "function" then
		icon = QualityConfig.GetIcon(quality)
	elseif QualityConfig and type(QualityConfig.Icons) == "table" then
		icon = QualityConfig.Icons[tonumber(quality) or 0] or ""
	end
	currentIcon.Image = icon or ""
end

local function setQuality(quality)
	currentQuality = quality
	applyFilter()
	updateQualityIcon(quality)
end

openIndex = function(restoreScroll, forceBackpack)
	local shouldSetBackpack = forceBackpack or not indexBg.Visible
	indexBg.Visible = true
	if shouldSetBackpack then
		setIndexBackpackHidden(true)
	end
	if not currentQuality then
		currentQuality = 1
	end
	applyFilter()
	updateCounters()
	updateQualityIcon(currentQuality)
	if restoreScroll and lastCanvasPosition then
		listFrame.CanvasPosition = lastCanvasPosition
	end
end

closeIndex = function()
	if indexBg.Visible then
		indexBg.Visible = false
		setIndexBackpackHidden(false)
	end
end

local function connectButton(button, callback)
	if not button or not button:IsA("GuiButton") then
		return
	end
	button.Activated:Connect(callback)
end

local function bindIndexButton(button)
	if indexBound or not button or not button:IsA("GuiButton") then
		return
	end
	indexBound = true
	connectButton(button, function()
		openIndex(false)
	end)
end

openCheck = function(figurineId)
	if not checkBg or not checkViewport then
		warn("[IndexDisplay] Check ui not ready")
		return
	end
	lastCanvasPosition = listFrame.CanvasPosition
	currentCheckId = figurineId

	if bagBg and bagBg.Visible then
		bagBg.Visible = false
	end
	if indexBg.Visible then
		indexBg.Visible = false
		setIndexBackpackHidden(false)
	end

	checkBg.Visible = true
	setCheckBackpackHidden(true)
	checkOpen = true
	dragActive = false
	dragInput = nil
	hoverActive = false
	hoverLastPos = nil
	bindViewportInput()
	loadCheckModel(figurineId)
end

closeCheck = function()
	if not checkBg or not checkBg.Visible then
		return
	end
	checkBg.Visible = false
	checkOpen = false
	dragActive = false
	dragInput = nil
	hoverActive = false
	hoverLastPos = nil
	clearViewport()
	setCheckBackpackHidden(false)
	openIndex(true)
end

local function bindTabButtons(container)
	if not container then
		return
	end
	local map = {
		Leaf = 1,
		Water = 2,
		Lunar = 3,
		Solar = 4,
		Flame = 5,
		Heart = 6,
		Celestial = 7,
	}
	for name, quality in pairs(map) do
		local button = container:FindFirstChild(name)
		if button and button:IsA("GuiButton") then
			connectButton(button, function()
				setQuality(quality)
			end)
		else
			warn(string.format("[IndexDisplay] Tab button %s not found", name))
		end
	end
end

local ownedFolder = nil
local ownedConnections = {}

local function clearOwnedConnections()
	for _, conn in ipairs(ownedConnections) do
		conn:Disconnect()
	end
	table.clear(ownedConnections)
end

local function collectOwnedSet()
	local owned = {}
	if ownedFolder then
		for _, child in ipairs(ownedFolder:GetChildren()) do
			if child:IsA("BoolValue") and child.Value then
				local id = tonumber(child.Name)
				if id then
					owned[id] = true
				end
			end
		end
	end
	return owned
end

local function refreshOwned()
	local ownedSet = collectOwnedSet()
	for id, entry in pairs(entriesById) do
		setEntryOwned(entry, ownedSet[id] == true)
	end
	updateCounters()
end

local function bindOwnedFolder(folder)
	clearOwnedConnections()
	ownedFolder = folder
	if not folder then
		refreshOwned()
		return
	end
	table.insert(ownedConnections, folder.ChildAdded:Connect(function(child)
		if child:IsA("BoolValue") then
			table.insert(ownedConnections, child:GetPropertyChangedSignal("Value"):Connect(refreshOwned))
		end
		refreshOwned()
	end))
	table.insert(ownedConnections, folder.ChildRemoved:Connect(function()
		refreshOwned()
	end))
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BoolValue") then
			table.insert(ownedConnections, child:GetPropertyChangedSignal("Value"):Connect(refreshOwned))
		end
	end
	refreshOwned()
end

buildEntries()

local existingFolder = player:FindFirstChild("FigurineOwned")
if existingFolder and existingFolder:IsA("Folder") then
	bindOwnedFolder(existingFolder)
else
	refreshOwned()
end

player.ChildAdded:Connect(function(child)
	if child.Name == "FigurineOwned" and child:IsA("Folder") then
		bindOwnedFolder(child)
	end
end)

bindIndexButton(indexButton)
if not indexBound then
	mainGui.DescendantAdded:Connect(function(child)
		if indexBound or child.Name ~= "Index" then
			return
		end
		local button = child
		if not button:IsA("GuiButton") then
			button = child:FindFirstChildWhichIsA("GuiButton", true)
		end
		bindIndexButton(button)
	end)
end

connectButton(closeButton, function()
	closeIndex()
end)

if checkExit then
	connectButton(checkExit, function()
		closeCheck()
	end)
end

if tabScroll then
	bindTabButtons(tabScroll)
elseif tabList then
	bindTabButtons(tabList)
else
	warn("[IndexDisplay] TabList not found")
end

setIndexBackpackHidden(indexBg.Visible)
if checkBg then
	setCheckBackpackHidden(checkBg.Visible)
end

BackpackVisibility.Reconcile(playerGui)

if indexBg.Visible then
	openIndex(false, true)
end
