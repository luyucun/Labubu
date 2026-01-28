--[[
脚本名称: BagDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/BagDisplay
版本: V2.7
职责: 盲盒背包总览UI显示与筛选
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local configFolder = ReplicatedStorage:WaitForChild("Config")
local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local CapsuleConfig = require(configFolder:WaitForChild("CapsuleConfig"))
local BackpackVisibility = require(modulesFolder:WaitForChild("BackpackVisibility"))
local GuiResolver = require(modulesFolder:WaitForChild("GuiResolver"))

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

local mainGui = GuiResolver.WaitForLayer(playerGui, { "MainGui", "MainGUI", "Main", "MainUI" }, {
	"CoinNum",
	"CoinBuff",
	"Bag",
	"Index",
	"Home",
}, 30)
if not mainGui then
	warn("[BagDisplay] MainGui not found")
end

local bagButton = nil
if mainGui then
	bagButton = GuiResolver.FindGuiButton(mainGui, "Bag")
end
if not bagButton then
	bagButton = GuiResolver.FindGuiButton(playerGui, "Bag")
end
if not bagButton then
	warn("[BagDisplay] MainGui.Bag not found")
	return
end

local bagGui = GuiResolver.WaitForLayer(playerGui, { "Bag", "BagGui", "BagGUI" }, {
	"BagBg",
	"CapsuleTemplate",
	"TabList",
}, 30)
if not bagGui then
	warn("[BagDisplay] Bag screen gui not found")
	return
end

local bagBg = bagGui:WaitForChild("BagBg", 10)
if not bagBg then
	warn("[BagDisplay] BagBg not found")
	return
end

local title = bagBg:WaitForChild("Title", 10)
if not title then
	warn("[BagDisplay] BagBg.Title not found")
	return
end

local closeButton = title:WaitForChild("CloseButton", 10)
if not closeButton then
	warn("[BagDisplay] BagBg.Title.CloseButton not found")
	return
end

local listFrame = bagBg:WaitForChild("ScrollingFrame", 10)
if not listFrame then
	warn("[BagDisplay] BagBg.ScrollingFrame not found")
	return
end

local template = listFrame:WaitForChild("CapsuleTemplate", 10)
if not template then
	warn("[BagDisplay] CapsuleTemplate not found")
	return
end

local tabList = bagBg:FindFirstChild("TabList")
local tabScroll = tabList and tabList:FindFirstChild("ScrollingFrame")

template.Visible = false
if bagGui:IsA("ScreenGui") then
	bagGui.Enabled = true
end

local qualityIndicatorNames = {
	[1] = "Leaf",
	[2] = "Water",
	[3] = "Lunar",
	[4] = "Solar",
	[5] = "Flame",
	[6] = "Heart",
	[7] = "Celestial",
}

local rarityNames = {
	[1] = "Common",
	[2] = "Light",
	[3] = "Gold",
	[4] = "Diamond",
	[5] = "Rainbow",
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

local currentBackpack = player:WaitForChild("Backpack")
local currentCharacter = player.Character

local function syncBackpackVisibility()
	BackpackVisibility.SetHidden(playerGui, "Bag", bagBg.Visible == true)
end

local refresh
local requestRefresh

local refreshQueued = false
requestRefresh = function()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		refresh()
	end)
end

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
	local itemsById = {}
	local tools = {}

	collectCapsuleTools(currentBackpack, tools)
	collectCapsuleTools(currentCharacter, tools)

	for _, tool in ipairs(tools) do
		local capsuleId = getCapsuleId(tool)
		if capsuleId ~= nil then
			local count = getStackCount(tool)
			if count > 0 then
				local entry = itemsById[capsuleId]
				if not entry then
					entry = {
						Id = capsuleId,
						Count = 0,
					}
					itemsById[capsuleId] = entry
					table.insert(list, entry)
				end
				entry.Count += count
			end
		end
	end

	table.sort(list, function(a, b)
		local aId = tonumber(a.Id) or 0
		local bId = tonumber(b.Id) or 0
		return aId > bId
	end)

	return list
end

local function clearEntries()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:GetAttribute("IsBagEntry") then
			child:Destroy()
		end
	end
end

local currentQualityFilter = nil

local function setFilterQuality(quality)
	currentQualityFilter = quality
	requestRefresh()
end

refresh = function()
	local entries = buildInventory()
	clearEntries()

	-- 预加载所有盲盒图标
	local iconsToPreload = {}
	local seenIcons = {}
	for _, entry in ipairs(entries) do
		local info = getCapsuleInfo(entry.Id)
		if info and info.Icon and info.Icon ~= "" and not seenIcons[info.Icon] then
			seenIcons[info.Icon] = true
			table.insert(iconsToPreload, info.Icon)
		end
	end
	if #iconsToPreload > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(iconsToPreload)
		end)
	end

	for _, entry in ipairs(entries) do
		local info = getCapsuleInfo(entry.Id)
		local quality = info and info.Quality or nil
		local rarity = tonumber(info and info.Rarity) or 1
		if currentQualityFilter == nil or currentQualityFilter == quality then
			local clone = template:Clone()
			clone.Name = string.format("Capsule_%s", tostring(entry.Id))
			clone.Visible = true
			clone:SetAttribute("IsBagEntry", true)
			local idValue = tonumber(entry.Id) or 0
			clone.LayoutOrder = -idValue

			local icon = clone:FindFirstChild("Icon", true)
			if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
				icon.Image = info and info.Icon or ""
			end

			local nameLabel = clone:FindFirstChild("Name", true)
			if nameLabel and nameLabel:IsA("TextLabel") then
				if rarity <= 1 then
					nameLabel.Visible = false
				else
					nameLabel.Visible = true
					nameLabel.Text = rarityNames[rarity] or tostring(rarity)
				end
			end

			updateQualityIndicators(clone, quality)

			local numberLabel = clone:FindFirstChild("Number", true)
			if numberLabel and numberLabel:IsA("TextLabel") then
				numberLabel.Text = tostring(entry.Count)
			end

			clone.Parent = listFrame
		end
	end
end

local function connectButton(button, callback)
	if not button or not button:IsA("GuiButton") then
		return
	end
	button.Activated:Connect(callback)
end

local function normalizeKey(text)
	if text == nil then
		return ""
	end
	text = string.lower(tostring(text))
	text = text:gsub("%s+", "")
	return text
end

local function mapQualityFromText(text)
	local key = normalizeKey(text)
	if key == "" then
		return nil, false
	end
	if key:find("total") or key:find("all") then
		return nil, true
	end
	if key:find("leaf") then
		return 1, true
	end
	if key:find("water") then
		return 2, true
	end
	if key:find("lunar") then
		return 3, true
	end
	if key:find("solar") then
		return 4, true
	end
	if key:find("flame") or key:find("fire") then
		return 5, true
	end
	if key:find("heart") then
		return 6, true
	end
	if key:find("celestial") or key:find("void") then
		return 7, true
	end
	return nil, false
end

local function resolveFilterQuality(button)
	local attr = button:GetAttribute("FilterQuality")
	if attr == nil then
		attr = button:GetAttribute("Quality")
	end
	if attr == nil then
		attr = button:GetAttribute("CapsuleQuality")
	end
	if attr ~= nil then
		local num = tonumber(attr)
		if num ~= nil then
			if num <= 0 then
				return nil, true
			end
			return num, true
		end
		local quality, matched = mapQualityFromText(attr)
		if matched then
			return quality, true
		end
	end

	local textLabel = button:FindFirstChildWhichIsA("TextLabel", true)
	local labelText = textLabel and textLabel.Text or ""
	local buttonText = ""
	if button:IsA("TextButton") then
		buttonText = button.Text
	end
	local quality, matched = mapQualityFromText(button.Name .. " " .. buttonText .. " " .. labelText)
	return quality, matched
end

local function bindFilterButtons(container)
	if not container then
		return
	end
	local bound = {}
	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("GuiButton") and not bound[obj] then
			bound[obj] = true
			local quality, matched = resolveFilterQuality(obj)
			if matched then
				connectButton(obj, function()
					setFilterQuality(quality)
				end)
			end
		end
	end
end

bagBg:GetPropertyChangedSignal("Visible"):Connect(syncBackpackVisibility)
syncBackpackVisibility()

connectButton(bagButton, function()
	bagBg.Visible = true
	syncBackpackVisibility()
	setFilterQuality(nil)
	requestRefresh()
end)

connectButton(closeButton, function()
	bagBg.Visible = false
	syncBackpackVisibility()
end)

if tabScroll then
	bindFilterButtons(tabScroll)
elseif tabList then
	bindFilterButtons(tabList)
else
	warn("[BagDisplay] TabList not found")
end

BackpackVisibility.Reconcile(playerGui)

disconnectConnections(backpackConnections)
disconnectConnections(characterConnections)
bindContainer(currentBackpack, backpackConnections)
bindContainer(currentCharacter, characterConnections)
rebuildToolTracking()
requestRefresh()

if bagBg.Visible then
	syncBackpackVisibility()
end

player.CharacterAdded:Connect(function(character)
	currentCharacter = character
	disconnectConnections(characterConnections)
	bindContainer(currentCharacter, characterConnections)
	rebuildToolTracking()
	requestRefresh()
end)
