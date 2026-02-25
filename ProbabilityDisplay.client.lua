--[[
脚本名称: ProbabilityDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/Client/ProbabilityDisplay
版本: V1.0
职责: 盲盒靠近时展示对应手办抽取概率
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local configFolder = ReplicatedStorage:WaitForChild("Config")
local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local CapsuleConfig = require(configFolder:WaitForChild("CapsuleConfig"))
local FigurineConfig = require(configFolder:WaitForChild("FigurineConfig"))
local FigurinePoolConfig = require(configFolder:WaitForChild("FigurinePoolConfig"))
local IconDisplayHelper = require(modulesFolder:WaitForChild("IconDisplayHelper"))

local UNKNOWN_ICON = "rbxassetid://15476451150"
local PROBABILITY_GUI_NAME = "ProbabilityGui"

local promptToModel = {}
local modelPromptCount = {}
local modelGuiCache = {}
local activeModels = {}
local offsetConnections = {}
local ownedFolder = nil
local ownedConnections = {}
local warnedMissingGui = false

local function getCapsuleInfo(capsuleId)
	local id = tonumber(capsuleId) or capsuleId
	if type(CapsuleConfig.GetById) == "function" then
		return CapsuleConfig.GetById(id)
	end
	local list = CapsuleConfig.Capsules
	if type(list) ~= "table" and type(CapsuleConfig) == "table" then
		list = CapsuleConfig
	end
	if type(list) ~= "table" then
		return nil
	end
	for _, info in ipairs(list) do
		if info.Id == id then
			return info
		end
	end
	return nil
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

local function getOwnedFolder()
	if ownedFolder and ownedFolder.Parent == player then
		return ownedFolder
	end
	local folder = player:FindFirstChild("FigurineOwned")
	if folder and folder:IsA("Folder") then
		ownedFolder = folder
		return folder
	end
	return nil
end

local function isFigurineOwned(figurineId)
	local folder = getOwnedFolder()
	if not folder then
		return false
	end
	local value = folder:FindFirstChild(tostring(figurineId))
	if value and value:IsA("BoolValue") then
		return value.Value == true
	end
	return false
end

local function findCapsuleModel(prompt)
	local current = prompt
	while current and current ~= Workspace do
		if current:GetAttribute("CapsuleId") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function getProbabilityTemplate()
	local template = ReplicatedStorage:FindFirstChild(PROBABILITY_GUI_NAME)
	if template and template:IsA("BillboardGui") then
		return template
	end
	if not warnedMissingGui then
		warn("[ProbabilityDisplay] ReplicatedStorage/ProbabilityGui not found")
		warnedMissingGui = true
	end
	return nil
end

local function resolveItemTemplate(gui)
	if not gui then
		return nil, nil
	end
	local bg = gui:FindFirstChild("Bg", true)
	local template = bg and bg:FindFirstChild("ItemTemplate", true) or nil
	if not template then
		template = gui:FindFirstChild("ItemTemplate", true)
	end
	if not template or not template:IsA("GuiObject") then
		return nil, nil
	end
	return template, template.Parent
end

local function getOrCreateProbabilityGui(model)
	if not model or not model.Parent then
		return nil
	end
	local cached = modelGuiCache[model]
	if cached and cached.Parent == model then
		return cached
	end
	local existing = model:FindFirstChild(PROBABILITY_GUI_NAME)
	if existing and existing:IsA("BillboardGui") then
		modelGuiCache[model] = existing
		return existing
	end
	local template = getProbabilityTemplate()
	if not template then
		return nil
	end
	local gui = template:Clone()
	gui.Name = PROBABILITY_GUI_NAME
	gui.Enabled = false
	local primary = getPrimaryPart(model)
	if primary then
		gui.Adornee = primary
	end
	gui:SetAttribute("BaseStudsOffset", gui.StudsOffset)
	gui:SetAttribute("BaseStudsOffsetWorld", gui.StudsOffsetWorldSpace)
	gui.Parent = model
	modelGuiCache[model] = gui
	return gui
end

local function getBillboardEffectiveOffsetY(gui)
	if not gui or not gui:IsA("BillboardGui") then
		return 0
	end
	local offset = gui.StudsOffset
	local worldOffset = gui.StudsOffsetWorldSpace
	local total = (offset and offset.Y or 0) + (worldOffset and worldOffset.Y or 0)
	local ok, extents = pcall(function()
		return gui.ExtentsOffset
	end)
	if ok and extents then
		total += extents.Y
	end
	return total
end

local function getStackOffset(gui, model, height)
	local isConveyor = model and model:GetAttribute("ConveyorUid")
	local attrName = isConveyor and "StackOffsetY" or "StackOffsetY01"
	local value = gui:GetAttribute(attrName)
	if type(value) ~= "number" and not isConveyor then
		value = gui:GetAttribute("StackOffsetY")
	end
	if type(value) ~= "number" then
		value = height * 0.35
	end
	return value
end

local function updateProbabilityOffset(model, gui)
	if not model or not gui then
		return
	end
	local baseOffset = gui:GetAttribute("BaseStudsOffset") or gui.StudsOffset
	local baseWorld = gui:GetAttribute("BaseStudsOffsetWorld") or gui.StudsOffsetWorldSpace
	local baseSum = (baseOffset and baseOffset.Y or 0) + (baseWorld and baseWorld.Y or 0)
	local maxOffset = nil
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BillboardGui") and child ~= gui then
			local offsetY = getBillboardEffectiveOffsetY(child)
			if not maxOffset or offsetY > maxOffset then
				maxOffset = offsetY
			end
		end
	end
	if maxOffset then
		local height = 0
		if model:IsA("Model") then
			height = model:GetExtentsSize().Y
		else
			local primary = getPrimaryPart(model)
			height = primary and primary.Size.Y or 0
		end
		local extra = getStackOffset(gui, model, height)
		local targetSum = math.max(baseSum, maxOffset + extra)
		gui.StudsOffset = Vector3.new(baseOffset.X, targetSum - (baseWorld and baseWorld.Y or 0), baseOffset.Z)
	else
		gui.StudsOffset = baseOffset
	end
	gui.StudsOffsetWorldSpace = baseWorld
end

local function clearItemList(container, template)
	if not container or not template then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		if child ~= template then
			if child:GetAttribute("ProbabilityItem") == true then
				child:Destroy()
			elseif child:IsA("GuiObject") and child.Name == template.Name then
				child:Destroy()
			end
		end
	end
end

local function collectPoolEntries(pool)
	if type(pool) ~= "table" then
		return {}, 0
	end
	local entries = {}
	local totalWeight = 0
	for _, entry in ipairs(pool) do
		local id = entry.FigurineId or entry.Id or entry.figurineId
		local weight = entry.Weight or entry.weight or entry.WeightValue
		local weightValue = tonumber(weight) or 0
		if id and weightValue > 0 then
			totalWeight += weightValue
			table.insert(entries, {
				Id = tonumber(id) or id,
				Weight = weightValue,
			})
		end
	end
	table.sort(entries, function(a, b)
		return (tonumber(a.Id) or 0) < (tonumber(b.Id) or 0)
	end)
	return entries, totalWeight
end

local function rebuildProbabilityGui(model)
	if not model or not model.Parent then
		return
	end
	local capsuleId = model:GetAttribute("CapsuleId")
	if not capsuleId then
		return
	end
	local capsuleInfo = getCapsuleInfo(capsuleId)
	if not capsuleInfo or not capsuleInfo.PoolId then
		return
	end
	local pool = FigurinePoolConfig.GetPool(capsuleInfo.PoolId)
	if type(pool) ~= "table" then
		return
	end
	local gui = getOrCreateProbabilityGui(model)
	if not gui then
		return
	end
	updateProbabilityOffset(model, gui)
	local template, container = resolveItemTemplate(gui)
	if not template or not container then
		if not warnedMissingGui then
			warn("[ProbabilityDisplay] ProbabilityGui missing ItemTemplate")
			warnedMissingGui = true
		end
		return
	end
	template.Visible = false
	clearItemList(container, template)

	local entries, totalWeight = collectPoolEntries(pool)
	local resolvedIcons = {}
	local iconsToPreload = {}
	for _, entry in ipairs(entries) do
		local figurineInfo = FigurineConfig.GetById(entry.Id)
		local owned = isFigurineOwned(entry.Id)
		local iconId = UNKNOWN_ICON
		if owned and figurineInfo and figurineInfo.Icon then
			iconId = figurineInfo.Icon
		end
		resolvedIcons[entry.Id] = iconId
		table.insert(iconsToPreload, iconId)
	end
	IconDisplayHelper.Preload(iconsToPreload, 2)

	for _, entry in ipairs(entries) do
		local clone = template:Clone()
		clone:SetAttribute("ProbabilityItem", true)
		clone.Visible = true
		local icon = clone:FindFirstChild("Icon", true)
		local probability = clone:FindFirstChild("Probability", true)
		if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
			IconDisplayHelper.Apply(icon, resolvedIcons[entry.Id] or UNKNOWN_ICON)
		end
		if probability and probability:IsA("TextLabel") then
			local percent = totalWeight > 0 and (entry.Weight / totalWeight * 100) or 0
			probability.Text = string.format("%.2f%%", percent)
		end
		clone.Parent = container
	end

	local primary = getPrimaryPart(model)
	if primary then
		gui.Adornee = primary
	end
end

local function showProbability(model)
	local gui = getOrCreateProbabilityGui(model)
	if not gui then
		return
	end
	updateProbabilityOffset(model, gui)
	rebuildProbabilityGui(model)
	gui.Enabled = true
	activeModels[model] = true
	if not offsetConnections[model] then
		local conns = {}
		table.insert(conns, model.ChildAdded:Connect(function(child)
			if child:IsA("BillboardGui") then
				updateProbabilityOffset(model, gui)
			end
		end))
		table.insert(conns, model.ChildRemoved:Connect(function(child)
			if child:IsA("BillboardGui") then
				updateProbabilityOffset(model, gui)
			end
		end))
		offsetConnections[model] = conns
	end
end

local function hideProbability(model)
	local gui = modelGuiCache[model]
	if gui and gui.Parent then
		gui.Enabled = false
	end
	activeModels[model] = nil
	local conns = offsetConnections[model]
	if conns then
		for _, conn in ipairs(conns) do
			conn:Disconnect()
		end
		offsetConnections[model] = nil
	end
end

local function handlePromptShown(prompt)
	local model = findCapsuleModel(prompt)
	if not model then
		return
	end
	promptToModel[prompt] = model
	modelPromptCount[model] = (modelPromptCount[model] or 0) + 1
	showProbability(model)
end

local function handlePromptHidden(prompt)
	local model = promptToModel[prompt] or findCapsuleModel(prompt)
	if not model then
		promptToModel[prompt] = nil
		return
	end
	local count = (modelPromptCount[model] or 1) - 1
	if count <= 0 then
		modelPromptCount[model] = nil
		hideProbability(model)
	else
		modelPromptCount[model] = count
	end
	promptToModel[prompt] = nil
end

local function refreshVisibleProbabilities()
	for model in pairs(activeModels) do
		rebuildProbabilityGui(model)
	end
end

local function clearOwnedConnections()
	for _, conn in ipairs(ownedConnections) do
		conn:Disconnect()
	end
	table.clear(ownedConnections)
end

local function bindOwnedFolder(folder)
	clearOwnedConnections()
	ownedFolder = folder
	if not folder then
		return
	end
	table.insert(ownedConnections, folder.ChildAdded:Connect(refreshVisibleProbabilities))
	table.insert(ownedConnections, folder.ChildRemoved:Connect(refreshVisibleProbabilities))
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BoolValue") then
			table.insert(ownedConnections, child:GetPropertyChangedSignal("Value"):Connect(refreshVisibleProbabilities))
		end
	end
end

local existingFolder = player:FindFirstChild("FigurineOwned")
if existingFolder and existingFolder:IsA("Folder") then
	bindOwnedFolder(existingFolder)
end

player.ChildAdded:Connect(function(child)
	if child.Name == "FigurineOwned" and child:IsA("Folder") then
		bindOwnedFolder(child)
	end
end)

ProximityPromptService.PromptShown:Connect(function(prompt)
	handlePromptShown(prompt)
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	handlePromptHidden(prompt)
end)
