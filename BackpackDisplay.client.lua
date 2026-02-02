--[[
脚本名称: BackpackDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/BackpackDisplay
版本: V2.5
职责: 自定义盲盒背包UI显示与装备交互
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local configFolder = ReplicatedStorage:WaitForChild("Config")
local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local CapsuleConfig = require(configFolder:WaitForChild("CapsuleConfig"))
local BackpackVisibility = require(modulesFolder:WaitForChild("BackpackVisibility"))
local GuiResolver = require(modulesFolder:WaitForChild("GuiResolver"))

local function disableCoreBackpack()
	local ok, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	if not ok then
		warn(string.format("[BackpackDisplay] Disable Core Backpack failed: %s", tostring(err)))
	end
end

disableCoreBackpack()

local function waitForBackpackGui()
	local gui = GuiResolver.WaitForLayer(playerGui, { "BackpackGui", "BackpackGUI", "Backpack" }, {
		"BackpackFrame",
		"ItemListFrame",
		"ArmyTemplate",
	}, 30)
	if gui then
		return gui
	end
	local attempts = 0
	while not gui do
		attempts = attempts + 1
		if attempts % 20 == 0 then
			warn("[BackpackDisplay] BackpackGui not found, waiting...")
		end
		task.wait(0.5)
		gui = GuiResolver.FindLayer(playerGui, { "BackpackGui", "BackpackGUI", "Backpack" }, {
			"BackpackFrame",
			"ItemListFrame",
			"ArmyTemplate",
		})
	end
	return gui
end

local function waitForChildSafe(parent, name, tag)
	local child = parent and parent:FindFirstChild(name)
	local attempts = 0
	while not child do
		attempts = attempts + 1
		if attempts % 20 == 0 then
			warn(string.format("[%s] %s not found, waiting...", tag, name))
		end
		task.wait(0.5)
		child = parent and parent:FindFirstChild(name)
	end
	return child
end

local backpackGui = waitForBackpackGui()

BackpackVisibility.Reconcile(playerGui)

local backpackFrame = waitForChildSafe(backpackGui, "BackpackFrame", "BackpackDisplay")

backpackGui.Enabled = true
backpackGui.DisplayOrder = 50
backpackGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
backpackFrame.ZIndex = 10
backpackFrame.Active = true

local itemListFrame = waitForChildSafe(backpackFrame, "ItemListFrame", "BackpackDisplay")

itemListFrame.ZIndex = 11
itemListFrame.Active = true

local template = waitForChildSafe(itemListFrame, "ArmyTemplate", "BackpackDisplay")

local templateStroke = template:FindFirstChild("UIStroke", true)
local defaultStrokeColor = templateStroke and templateStroke.Color or Color3.fromRGB(255, 255, 255)
local highlightStrokeColor = Color3.fromRGB(255, 255, 0)

template.Visible = false
backpackFrame.Visible = false

local hotkeyIndexMap = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
	[Enum.KeyCode.KeypadFive] = 5,
	[Enum.KeyCode.KeypadSix] = 6,
	[Enum.KeyCode.KeypadSeven] = 7,
	[Enum.KeyCode.KeypadEight] = 8,
	[Enum.KeyCode.KeypadNine] = 9,
	[Enum.KeyCode.KeypadZero] = 10,
}

local rarityNames = {
	[1] = "Common",
	[2] = "Light",
	[3] = "Gold",
	[4] = "Diamond",
	[5] = "Rainbow",
}

local function getCapsuleInfo(capsuleId)
	local normalizedId = tonumber(capsuleId) or capsuleId
	if type(CapsuleConfig.GetById) == "function" then
		return CapsuleConfig.GetById(normalizedId)
	end

	local list = CapsuleConfig.Capsules
	if type(list) ~= "table" and type(CapsuleConfig) == "table" then
		list = CapsuleConfig
	end
	if type(list) ~= "table" then
		return nil
	end
	for _, info in ipairs(list) do
		if info.Id == normalizedId then
			return info
		end
	end
	return nil
end

local function getCapsuleId(tool)
	if not tool then
		return nil
	end
	return tonumber(tool:GetAttribute("CapsuleId")) or tool:GetAttribute("CapsuleId")
end

local function isCapsuleTool(tool)
	return tool and tool:IsA("Tool") and getCapsuleId(tool) ~= nil
end

local function getStackCount(tool)
	local count = tonumber(tool:GetAttribute("StackCount"))
	if count == nil then
		count = 1
	end
	count = math.floor(count)
	if count < 0 then
		count = 0
	end
	return count
end

local function collectCapsuleTools(container, list)
	if not container then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		if isCapsuleTool(child) then
			table.insert(list, child)
		end
	end
end

local function findToolIn(container, capsuleId)
	if not container then
		return nil
	end
	for _, child in ipairs(container:GetChildren()) do
		if isCapsuleTool(child) and getCapsuleId(child) == capsuleId then
			return child
		end
	end
	return nil
end

local currentBackpack = player:WaitForChild("Backpack")
local currentCharacter = player.Character

local refresh
local requestRefresh

local refreshQueued = false
local cachedEntries = {}
requestRefresh = function()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		-- 使用延迟刷新避免频繁重建列表
		refresh()
	end)
end

backpackGui:GetAttributeChangedSignal("BackpackForceHidden"):Connect(requestRefresh)

local toolConnections = {}
local backpackConnections = {}
local characterConnections = {}

local function disconnectConnections(connections)
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	table.clear(connections)
end

local function trackTool(tool)
	if toolConnections[tool] then
		return
	end
	toolConnections[tool] = tool:GetAttributeChangedSignal("StackCount"):Connect(requestRefresh)
end

local function untrackTool(tool)
	local conn = toolConnections[tool]
	if conn then
		conn:Disconnect()
		toolConnections[tool] = nil
	end
end

local function onToolAdded(tool)
	if isCapsuleTool(tool) then
		trackTool(tool)
		requestRefresh()
	end
end

local function onToolRemoved(tool)
	if isCapsuleTool(tool) then
		untrackTool(tool)
		requestRefresh()
	end
end

local function bindContainer(container, connections)
	if not container then
		return
	end
	table.insert(connections, container.ChildAdded:Connect(onToolAdded))
	table.insert(connections, container.ChildRemoved:Connect(onToolRemoved))
end

local function rebuildToolTracking()
	for tool, conn in pairs(toolConnections) do
		if conn then
			conn:Disconnect()
		end
		toolConnections[tool] = nil
	end
	if currentBackpack then
		for _, child in ipairs(currentBackpack:GetChildren()) do
			onToolAdded(child)
		end
	end
	if currentCharacter then
		for _, child in ipairs(currentCharacter:GetChildren()) do
			onToolAdded(child)
		end
	end
end

local function buildInventory()
	local list = {}
	local totalCount = 0
	local itemsById = {}
	local tools = {}

	collectCapsuleTools(currentBackpack, tools)
	collectCapsuleTools(currentCharacter, tools)

	for _, tool in ipairs(tools) do
		local capsuleId = getCapsuleId(tool)
		if capsuleId ~= nil then
			local count = getStackCount(tool)
			if count > 0 then
				totalCount += count
				local entry = itemsById[capsuleId]
				if not entry then
					entry = {
						Id = capsuleId,
						Count = 0,
						Order = nil,
					}
					itemsById[capsuleId] = entry
					table.insert(list, entry)
				end
				entry.Count += count
				local stackIndex = tonumber(tool:GetAttribute("StackIndex"))
				if stackIndex and (not entry.Order or stackIndex < entry.Order) then
					entry.Order = stackIndex
				end
			end
		end
	end

	table.sort(list, function(a, b)
		local aOrder = a.Order or math.huge
		local bOrder = b.Order or math.huge
		if aOrder == bOrder then
			return tostring(a.Id) < tostring(b.Id)
		end
		return aOrder < bOrder
	end)

	return list, totalCount
end

local function clearEntries()
	for _, child in ipairs(itemListFrame:GetChildren()) do
		if child:GetAttribute("IsBackpackEntry") then
			child:Destroy()
		end
	end
end

local function equipCapsuleById(capsuleId)
	local normalizedId = tonumber(capsuleId) or capsuleId
	if not currentCharacter or not currentBackpack then
		return
	end
	local tool = findToolIn(currentBackpack, normalizedId)
	local humanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local equippedTool = findToolIn(currentCharacter, normalizedId)
	if equippedTool then
		humanoid:UnequipTools()
		requestRefresh()
		return
	end
	if not tool then
		return
	end
	humanoid:EquipTool(tool)
	requestRefresh()
end

local function getEquippedCapsuleId()
	if not currentCharacter then
		return nil
	end
	for _, child in ipairs(currentCharacter:GetChildren()) do
		if child:IsA("Tool") then
			local capsuleId = getCapsuleId(child)
			if capsuleId then
				return capsuleId
			end
		end
	end
	return nil
end

local function handleClickPosition(pos, inputType)
	if not backpackFrame.Visible then
		return
	end
	local hitObjects = playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
	for _, gui in ipairs(hitObjects) do
		local capsuleId = gui:GetAttribute("CapsuleId")
		if capsuleId then
			if inputType == Enum.UserInputType.MouseButton1
				or inputType == Enum.UserInputType.Touch then
				equipCapsuleById(capsuleId)
			end
			return
		end
	end

	if inputType == Enum.UserInputType.MouseButton2 then
		local humanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
			requestRefresh()
		end
	end
end

local function ensureClickArea(container)
	local existing = container:FindFirstChild("ClickArea")
	if existing and existing:IsA("GuiButton") then
		existing.Active = true
		existing.Selectable = true
		existing.ZIndex = 9999
		return existing
	end

	local clickArea = Instance.new("TextButton")
	clickArea.Name = "ClickArea"
	clickArea.BackgroundTransparency = 1
	clickArea.Text = ""
	clickArea.TextTransparency = 1
	clickArea.BorderSizePixel = 0
	clickArea.AutoButtonColor = false
	clickArea.Active = true
	clickArea.Selectable = true
	clickArea.Size = UDim2.new(1, 0, 1, 0)
	clickArea.Position = UDim2.new(0, 0, 0, 0)
	clickArea.ZIndex = 9999
	clickArea.Parent = container
	return clickArea
end

refresh = function()
	local entries, totalCount = buildInventory()
	cachedEntries = entries
	local forceHidden = backpackGui:GetAttribute("BackpackForceHidden") == true
	backpackFrame.Visible = (not forceHidden) and totalCount > 0
	clearEntries()
	local selectedId = getEquippedCapsuleId()

	for _, entry in ipairs(entries) do
		local clone = template:Clone()
		clone.Name = string.format("Capsule_%s", tostring(entry.Id))
		clone.Visible = true
		clone:SetAttribute("CapsuleId", entry.Id)
		local info = getCapsuleInfo(entry.Id)
		local rarity = tonumber(info and info.Rarity) or 1
		local layoutOrder = entry.Order
		if layoutOrder == nil then
			layoutOrder = tonumber(entry.Id) or 0
		end
		clone.LayoutOrder = layoutOrder
		clone:SetAttribute("IsBackpackEntry", true)

		local stroke = clone:FindFirstChild("UIStroke", true)
		if stroke and stroke:IsA("UIStroke") then
			local entryId = tonumber(entry.Id) or entry.Id
			if selectedId ~= nil and entryId == selectedId then
				stroke.Color = highlightStrokeColor
			else
				stroke.Color = defaultStrokeColor
			end
		end

		local icon = clone:FindFirstChild("Icon", true)
		if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
			icon.Image = info and info.Icon or ""
			icon:SetAttribute("CapsuleId", entry.Id)
		end

		local rareLabel = clone:FindFirstChild("Rare", true)
		if rareLabel and rareLabel:IsA("TextLabel") then
			if rarity <= 1 then
				rareLabel.Visible = false
			else
				rareLabel.Visible = true
				rareLabel.Text = rarityNames[rarity] or tostring(rarity)
			end
		end

		local numberLabel = clone:FindFirstChild("Number", true)
		if numberLabel and numberLabel:IsA("TextLabel") then
			numberLabel.Text = string.format("*%d", entry.Count)
			numberLabel:SetAttribute("CapsuleId", entry.Id)
		end

		local button = ensureClickArea(clone)
		if button then
			local capsuleId = entry.Id
			button:SetAttribute("CapsuleId", capsuleId)
			button.MouseButton1Click:Connect(function()
				equipCapsuleById(capsuleId)
			end)
			button.Activated:Connect(function()
				equipCapsuleById(capsuleId)
			end)
		end

		clone.Parent = itemListFrame
	end

	if not itemListFrame:GetAttribute("InputListenerAdded") then
		itemListFrame:SetAttribute("InputListenerAdded", true)
		itemListFrame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2
				or input.UserInputType == Enum.UserInputType.Touch then
				handleClickPosition(input.Position, input.UserInputType)
			end
		end)
	end

	if not _G.BackpackDisplayGlobalInputAdded then
		_G.BackpackDisplayGlobalInputAdded = true
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if UserInputService:GetFocusedTextBox() then
					return
				end
				local index = hotkeyIndexMap[input.KeyCode]
				if index then
					local entry = cachedEntries[index]
					if not entry then
						local entries = buildInventory()
						entry = entries[index]
					end
					if entry and entry.Id then
						equipCapsuleById(entry.Id)
					end
					return
				end
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2
				or input.UserInputType == Enum.UserInputType.Touch then
				handleClickPosition(input.Position, input.UserInputType)
			end
		end)
	end
end

disconnectConnections(backpackConnections)
disconnectConnections(characterConnections)
bindContainer(currentBackpack, backpackConnections)
bindContainer(currentCharacter, characterConnections)
rebuildToolTracking()
requestRefresh()

player.CharacterAdded:Connect(function(character)
	currentCharacter = character
	disconnectConnections(characterConnections)
	bindContainer(currentCharacter, characterConnections)
	rebuildToolTracking()
	requestRefresh()
end)
