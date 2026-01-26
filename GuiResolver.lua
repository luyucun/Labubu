--[[
脚本名称: GuiResolver
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Modules/GuiResolver
版本: V1.0
职责: 提供UI路径容错查找，支持延迟加载与多名称/子节点匹配
]]

local GuiResolver = {}

local function buildLookup(list)
	local lookup = {}
	if type(list) ~= "table" then
		return lookup
	end
	for _, name in ipairs(list) do
		if type(name) == "string" and name ~= "" then
			lookup[name] = true
		end
	end
	return lookup
end

local function findLayerAncestor(instance, root)
	local current = instance
	while current and current ~= root do
		if current:IsA("LayerCollector") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function findLayerByName(root, names)
	if type(names) ~= "table" then
		return nil
	end
	for _, name in ipairs(names) do
		local direct = root:FindFirstChild(name)
		if direct and direct:IsA("LayerCollector") then
			return direct
		end
	end
	for _, name in ipairs(names) do
		local desc = root:FindFirstChild(name, true)
		if desc and desc:IsA("LayerCollector") then
			return desc
		end
	end
	return nil
end

local function findLayerByDescendant(root, descendantNames)
	if type(descendantNames) ~= "table" then
		return nil
	end
	for _, name in ipairs(descendantNames) do
		local desc = root:FindFirstChild(name, true)
		if desc then
			local layer = findLayerAncestor(desc, root)
			if layer then
				return layer
			end
		end
	end
	return nil
end

function GuiResolver.FindLayer(root, names, descendantNames)
	if not root then
		return nil
	end
	local layer = findLayerByName(root, names)
	if layer then
		return layer
	end
	return findLayerByDescendant(root, descendantNames)
end

function GuiResolver.WaitForLayer(root, names, descendantNames, timeoutSeconds)
	if not root then
		return nil
	end
	local layer = GuiResolver.FindLayer(root, names, descendantNames)
	if layer then
		return layer
	end

	local timeout = tonumber(timeoutSeconds) or 20
	if timeout <= 0 then
		return nil
	end

	local nameLookup = buildLookup(names)
	local descendantLookup = buildLookup(descendantNames)
	local found = nil
	local conn
	conn = root.DescendantAdded:Connect(function(child)
		if found then
			return
		end
		if nameLookup[child.Name] or descendantLookup[child.Name] then
			local resolved = findLayerAncestor(child, root)
			if resolved then
				found = resolved
			end
		end
	end)

	local start = os.clock()
	while not found and (os.clock() - start) < timeout do
		task.wait(0.1)
	end

	if conn then
		conn:Disconnect()
	end

	return found or GuiResolver.FindLayer(root, names, descendantNames)
end

function GuiResolver.FindDescendant(root, name, className)
	if not root or type(name) ~= "string" then
		return nil
	end
	local first = root:FindFirstChild(name, true)
	if first and (not className or first:IsA(className)) then
		return first
	end
	if className then
		for _, obj in ipairs(root:GetDescendants()) do
			if obj.Name == name and obj:IsA(className) then
				return obj
			end
		end
	end
	return nil
end

function GuiResolver.FindGuiButton(root, name)
	return GuiResolver.FindDescendant(root, name, "GuiButton")
end

return GuiResolver
