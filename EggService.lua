--[[
脚本名称: EggService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/EggService
版本: V1.7
职责: 盲盒生成/购买/背包/放置/倒计时/打开/手办产出
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local CapsuleConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CapsuleConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local FigurineService = require(script.Parent:WaitForChild("FigurineService"))

local EggService = {}
EggService.__index = EggService

local toolConnections = {} -- [tool] = connection
local playerConnections = {} -- [player] = {Backpack, Character}
local playerStackIndex = {} -- [userId] = number

local function toVectorTable(vec)
	return { X = vec.X, Y = vec.Y, Z = vec.Z }
end

local function fromVectorTable(data)
	if type(data) ~= "table" then
		return nil
	end
	local x = tonumber(data.X or data.x)
	local y = tonumber(data.Y or data.y)
	local z = tonumber(data.Z or data.z)
	if not x or not y or not z then
		return nil
	end
	return Vector3.new(x, y, z)
end

local function toRotationTable(cframe)
	local rx, ry, rz = cframe:ToOrientation()
	return { X = rx, Y = ry, Z = rz }
end

local function fromRotationTable(data)
	if type(data) ~= "table" then
		return 0, 0, 0
	end
	local x = tonumber(data.X or data.x) or 0
	local y = tonumber(data.Y or data.y) or 0
	local z = tonumber(data.Z or data.z) or 0
	return x, y, z
end

local function buildCFrame(positionData, rotationData)
	local pos = fromVectorTable(positionData)
	if not pos then
		return nil
	end
	local rx, ry, rz = fromRotationTable(rotationData)
	return CFrame.new(pos) * CFrame.Angles(rx, ry, rz)
end

local function getNextStackIndex(player)
	local userId = player.UserId
	local nextIndex = (playerStackIndex[userId] or 0) + 1
	playerStackIndex[userId] = nextIndex
	return nextIndex
end

local function getStackCount(tool)
	return tonumber(tool:GetAttribute("StackCount")) or 1
end

local function setStackCount(tool, count)
	tool:SetAttribute("StackCount", count)
end

local function ensureStackIndex(player, tool, preferredIndex)
	if tool:GetAttribute("StackIndex") then
		return
	end
	tool:SetAttribute("StackIndex", preferredIndex or getNextStackIndex(player))
end

local function collectCapsuleToolsFrom(container, list)
	if not container then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("CapsuleId") then
			table.insert(list, child)
		end
	end
end

local function getCapsuleTools(player)
	local tools = {}
	collectCapsuleToolsFrom(player:FindFirstChild("Backpack"), tools)
	collectCapsuleToolsFrom(player.Character, tools)
	return tools
end

local function getCapsuleToolsById(player, capsuleId)
	local tools = {}
	for _, tool in ipairs(getCapsuleTools(player)) do
		if tool:GetAttribute("CapsuleId") == capsuleId then
			table.insert(tools, tool)
		end
	end
	return tools
end

local function toLocalData(baseCFrame, worldCFrame)
	local localCFrame = baseCFrame:ToObjectSpace(worldCFrame)
	return toVectorTable(localCFrame.Position), toRotationTable(localCFrame)
end

local function toWorldCFrame(baseCFrame, positionData, rotationData)
	local localCFrame = buildCFrame(positionData, rotationData)
	if not localCFrame then
		return nil
	end
	return baseCFrame:ToWorldSpace(localCFrame)
end

local function hasPlacedCapsule(folder, eggUid)
	if not folder or not eggUid then
		return false
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:GetAttribute("EggUid") == eggUid then
			return true
		end
	end
	return false
end

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

local function getPlacedFolder(homeFolder)
	if not homeFolder then
		return nil
	end
	local folder = homeFolder:FindFirstChild("PlacedCapsules")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PlacedCapsules"
		folder.Parent = homeFolder
	end
	return folder
end

local function getIdleFloor(homeFolder)
	if not homeFolder then
		return nil
	end
	local baseFolder = homeFolder:FindFirstChild("Base")
	if baseFolder then
		local idleFloor = baseFolder:FindFirstChild("IdleFloor")
		if idleFloor and idleFloor:IsA("BasePart") then
			return idleFloor
		end
	end
	local fallback = homeFolder:FindFirstChild("IdleFloor", true)
	if fallback and fallback:IsA("BasePart") then
		return fallback
	end
	return nil
end

local function isWithinIdleFloor(idleFloor, worldPos)
	local localPos = idleFloor.CFrame:PointToObjectSpace(worldPos)
	local halfSize = idleFloor.Size * 0.5
	return math.abs(localPos.X) <= halfSize.X and math.abs(localPos.Z) <= halfSize.Z
end

local function findIdleFloorByWorldPosition(worldPos)
	local homeRoot = Workspace:FindFirstChild(GameConfig.HomeFolderName)
	if not homeRoot then
		return nil
	end

	local nearest
	local nearestDist
	for _, folder in ipairs(homeRoot:GetChildren()) do
		local idleFloor = getIdleFloor(folder)
		if idleFloor then
			if isWithinIdleFloor(idleFloor, worldPos) then
				return idleFloor
			end
			local dist = (idleFloor.Position - worldPos).Magnitude
			if not nearestDist or dist < nearestDist then
				nearestDist = dist
				nearest = idleFloor
			end
		end
	end
	return nearest
end

local function ensureLocalPlacedEntry(player, entry, idleFloor)
	if entry.IsLocal then
		return true
	end

	local worldCFrame = buildCFrame(entry.Position, entry.Rotation)
	if not worldCFrame then
		return false
	end

	local legacyFloor = findIdleFloorByWorldPosition(worldCFrame.Position)
	if not legacyFloor then
		legacyFloor = idleFloor
	end
	if not legacyFloor or not idleFloor then
		return false
	end

	local localPosition, localRotation = toLocalData(legacyFloor.CFrame, worldCFrame)
	entry.Position = localPosition
	entry.Rotation = localRotation
	entry.IsLocal = true
	DataService:MarkDirty(player)
	return true
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

local function getCapsuleInfo(capsuleId)
	if type(CapsuleConfig.GetById) == "function" then
		return CapsuleConfig.GetById(capsuleId)
	end

	local list = CapsuleConfig.Capsules
	if type(list) ~= "table" and type(CapsuleConfig) == "table" then
		list = CapsuleConfig
	end
	if type(list) ~= "table" then
		warn("[EggService] CapsuleConfig missing GetById")
		return nil
	end

	for _, info in ipairs(list) do
		if info.Id == capsuleId then
			return info
		end
	end
	return nil
end

local function getPromptHeight(model, part)
	if model and model:IsA("Model") then
		return model:GetExtentsSize().Y
	end
	if part and part:IsA("BasePart") then
		return part.Size.Y
	end
	return 0
end

local function createPrompt(model, part, price)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = string.format("$%d", price)
	prompt.HoldDuration = 0.1
	prompt.MaxActivationDistance = 20
	prompt.RequiresLineOfSight = false

	local attachment = Instance.new("Attachment")
	attachment.Name = "CapsulePrompt"
	attachment.Position = Vector3.new(0, getPromptHeight(model, part) * 0.6, 0)
	attachment.Parent = part

	prompt.Parent = attachment
	return prompt
end

local function createOpenPrompt(model, part)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 20
	prompt.RequiresLineOfSight = false

	local attachment = Instance.new("Attachment")
	attachment.Name = "CapsuleOpenPrompt"
	attachment.Position = Vector3.new(0, getPromptHeight(model, part) * 0.6, 0)
	attachment.Parent = part

	prompt.Parent = attachment
	return prompt
end

local function setupHatchTimer(model, hatchEndTime)
	local endTime = tonumber(hatchEndTime) or os.time()
	local remaining = endTime - os.time()

	local function markReady()
		if model and model.Parent then
			model:SetAttribute("HatchReady", true)
			local openPart = getPrimaryPart(model)
			if openPart then
				local openPrompt = createOpenPrompt(model, openPart)
				openPrompt.Triggered:Connect(function(openPlayer)
					EggService:HandleOpen(openPlayer, model)
				end)
			end
		end
	end

	if remaining <= 0 then
		markReady()
		return
	end

	model:SetAttribute("HatchReady", false)
	task.delay(remaining, markReady)
end

function EggService:CreateConveyorCapsule(capsuleInfo, ownerUserId)
	local capsuleFolder = ReplicatedStorage:WaitForChild("Capsule")
	local source = capsuleFolder:FindFirstChild(capsuleInfo.ModelName)
	if not source then
		warn(string.format("[EggService] Capsule model missing: %s", capsuleInfo.ModelName))
		return nil
	end

	local model = source:Clone()
	model.Name = string.format("Capsule_%d", capsuleInfo.Id)
	model:SetAttribute("CapsuleId", capsuleInfo.Id)
	model:SetAttribute("CapsuleName", capsuleInfo.Name)
	model:SetAttribute("Quality", capsuleInfo.Quality)
	model:SetAttribute("Rarity", capsuleInfo.Rarity)
	model:SetAttribute("Price", capsuleInfo.Price)
	model:SetAttribute("OpenSeconds", capsuleInfo.OpenSeconds)
	model:SetAttribute("OwnerUserId", ownerUserId)

	local primary = getPrimaryPart(model)
	if model:IsA("Model") and not model.PrimaryPart and primary then
		model.PrimaryPart = primary
	end
	if not primary then
		warn("[EggService] Capsule model missing BasePart")
		model:Destroy()
		return nil
	end

	setAnchored(model, true)
	local prompt = createPrompt(model, primary, capsuleInfo.Price)
	prompt.Triggered:Connect(function(player)
		self:HandlePurchase(player, model, capsuleInfo)
	end)

	return model
end

function EggService:HandlePurchase(player, model, capsuleInfo)
	if not player or not player.Parent then
		return
	end
	if not model or not model.Parent then
		return
	end
	if model:GetAttribute("IsSold") == true then
		return
	end
	if model:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end

	local coins = DataService:GetCoins(player)
	if coins < capsuleInfo.Price then
		return
	end

	model:SetAttribute("IsSold", true)
	DataService:AddCoins(player, -capsuleInfo.Price)
	DataService:AddEgg(player, capsuleInfo.Id)
	self:GiveCapsuleTool(player, capsuleInfo)
	model:Destroy()
end

function EggService:HandleOpen(player, model)
	if not player or not player.Parent then
		return
	end
	if not model or not model.Parent then
		return
	end
	if model:GetAttribute("IsOpened") == true then
		return
	end
	if model:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	if model:GetAttribute("HatchReady") ~= true then
		return
	end

	local capsuleId = model:GetAttribute("CapsuleId")
	if not capsuleId then
		return
	end

	local capsuleInfo = getCapsuleInfo(capsuleId)
	if not capsuleInfo then
		warn(string.format("[EggService] Capsule config missing: %s", tostring(capsuleId)))
		return
	end

	model:SetAttribute("IsOpened", true)
	DataService:AddCapsuleOpen(player, capsuleId)
	local eggUid = model:GetAttribute("EggUid")
	if eggUid then
		DataService:RemovePlacedEgg(player, eggUid)
	end
	FigurineService:GrantFromCapsule(player, capsuleInfo)
	model:Destroy()
end

local function createCapsuleTool(player, capsuleInfo, count, stackIndex)
	local capsuleFolder = ReplicatedStorage:WaitForChild("Capsule")
	local source = capsuleFolder:FindFirstChild(capsuleInfo.ModelName)
	if not source then
		warn(string.format("[EggService] Capsule model missing: %s", capsuleInfo.ModelName))
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = capsuleInfo.Name
	tool.RequiresHandle = true
	tool:SetAttribute("CapsuleId", capsuleInfo.Id)
	tool:SetAttribute("CapsuleName", capsuleInfo.Name)
	tool:SetAttribute("Quality", capsuleInfo.Quality)
	tool:SetAttribute("Rarity", capsuleInfo.Rarity)
	tool:SetAttribute("Price", capsuleInfo.Price)
	tool:SetAttribute("OpenSeconds", capsuleInfo.OpenSeconds)
	setStackCount(tool, count or 1)
	ensureStackIndex(player, tool, stackIndex)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local model = source:Clone()
	local pivot = model:GetPivot()
	handle.CFrame = pivot
	model:PivotTo(handle.CFrame)
	model.Parent = tool

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = false
			obj.CanCollide = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = obj
			weld.Parent = handle
		end
	end

	return tool
end

function EggService:GiveCapsuleTool(player, capsuleInfo)
	local tools = getCapsuleToolsById(player, capsuleInfo.Id)
	local tool = tools[1]
	for i = 2, #tools do
		tools[i]:Destroy()
	end

	if tool then
		setStackCount(tool, getStackCount(tool) + 1)
		ensureStackIndex(player, tool)
		return tool
	end

	tool = createCapsuleTool(player, capsuleInfo, 1)
	if not tool then
		return nil
	end
	local backpack = player:WaitForChild("Backpack")
	tool.Parent = backpack
	return tool
end

function EggService:PlaceFromTool(player, tool)
	if not player or not player.Parent then
		return
	end
	if not tool or not tool.Parent then
		return
	end
	if tool:GetAttribute("IsPlacing") == true then
		return
	end

	local capsuleId = tool:GetAttribute("CapsuleId")
	if not capsuleId then
		return
	end

	local capsuleInfo = getCapsuleInfo(capsuleId)
	if not capsuleInfo then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local homeFolder = getHomeFolder(player)
	local placedFolder = getPlacedFolder(homeFolder)
	if not placedFolder then
		return
	end

	local idleFloor = getIdleFloor(homeFolder)
	if not idleFloor then
		return
	end

	local capsuleFolder = ReplicatedStorage:WaitForChild("Capsule")
	local source = capsuleFolder:FindFirstChild(capsuleInfo.ModelName)
	if not source then
		warn(string.format("[EggService] Capsule model missing: %s", capsuleInfo.ModelName))
		return
	end
	if not getPrimaryPart(source) then
		warn("[EggService] Capsule model missing BasePart")
		return
	end

	tool:SetAttribute("IsPlacing", true)
	local function cancelPlacement(model)
		if model then
			model:Destroy()
		end
		tool:SetAttribute("IsPlacing", false)
	end

	local model = source:Clone()
	model.Name = string.format("PlacedCapsule_%d", capsuleInfo.Id)
	model:SetAttribute("CapsuleId", capsuleInfo.Id)
	model:SetAttribute("CapsuleName", capsuleInfo.Name)
	model:SetAttribute("Quality", capsuleInfo.Quality)
	model:SetAttribute("Rarity", capsuleInfo.Rarity)
	model:SetAttribute("OpenSeconds", capsuleInfo.OpenSeconds)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Placed", true)

	local primary = getPrimaryPart(model)
	if model:IsA("Model") and not model.PrimaryPart and primary then
		model.PrimaryPart = primary
	end
	if not primary then
		warn("[EggService] Capsule model missing BasePart")
		cancelPlacement(model)
		return
	end

	local forward = root.CFrame.LookVector
	local basePos = root.Position + forward * 5
	local floorRayParams = RaycastParams.new()
	floorRayParams.FilterType = Enum.RaycastFilterType.Include
	floorRayParams.FilterDescendantsInstances = { idleFloor }

	local floorResult = Workspace:Raycast(basePos + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0), floorRayParams)
	if not floorResult or floorResult.Instance ~= idleFloor then
		cancelPlacement(model)
		return
	end

	local floorPos = floorResult.Position
	if not isWithinIdleFloor(idleFloor, floorPos) then
		cancelPlacement(model)
		return
	end

	local size = model:GetExtentsSize()
	local blockCheckCFrame = CFrame.new(floorPos + Vector3.new(0, size.Y / 2, 0))
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { idleFloor, character }

	local blocking = Workspace:GetPartBoundsInBox(blockCheckCFrame, size, overlapParams)
	if #blocking > 0 then
		cancelPlacement(model)
		return
	end

	local placeCFrame = CFrame.new(floorPos)
	model:PivotTo(placeCFrame)
	setAnchored(model, true)
	model.Parent = placedFolder

	local hatchEndTime = os.time() + capsuleInfo.OpenSeconds
	model:SetAttribute("HatchEndTime", hatchEndTime)
	setupHatchTimer(model, hatchEndTime)

	local localPosition, localRotation = toLocalData(idleFloor.CFrame, model:GetPivot())
	local removed = DataService:RemoveEgg(player, nil, capsuleId)
	if not removed then
		warn(string.format("[EggService] RemoveEgg missing entry: userId=%d eggId=%s", player.UserId, tostring(capsuleId)))
	end
	local eggUid = removed and removed.Uid or DataService:GenerateUid()
	model:SetAttribute("EggUid", eggUid)
	DataService:AddPlacedEgg(player, {
		Uid = eggUid,
		EggId = capsuleId,
		HatchEndTime = hatchEndTime,
		Position = localPosition,
		Rotation = localRotation,
		IsLocal = true,
	})

	local newCount = getStackCount(tool) - 1
	if newCount <= 0 then
		tool:Destroy()
	else
		setStackCount(tool, newCount)
		tool:SetAttribute("IsPlacing", false)
	end

	self:EquipNextCapsule(player)
end

function EggService:EquipNextCapsule(player)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	if not backpack or not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local tools = {}
	collectCapsuleToolsFrom(backpack, tools)
	collectCapsuleToolsFrom(character, tools)
	if #tools == 0 then
		return
	end

	table.sort(tools, function(a, b)
		local aIndex = tonumber(a:GetAttribute("StackIndex")) or 0
		local bIndex = tonumber(b:GetAttribute("StackIndex")) or 0
		if aIndex == bIndex then
			return a.Name < b.Name
		end
		return aIndex < bIndex
	end)

	local target = tools[1]
	local equipped
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("CapsuleId") then
			equipped = child
			break
		end
	end

	if equipped == target then
		return
	end
	if target.Parent == backpack then
		humanoid:EquipTool(target)
	end
end

function EggService:CreatePlacedCapsuleFromData(player, capsuleInfo, entry, placedFolder, idleFloor)
	if not player or not capsuleInfo or type(entry) ~= "table" then
		return false
	end

	local homeFolder = getHomeFolder(player)
	placedFolder = placedFolder or getPlacedFolder(homeFolder)
	if not placedFolder then
		return false
	end
	idleFloor = idleFloor or getIdleFloor(homeFolder)

	local capsuleFolder = ReplicatedStorage:WaitForChild("Capsule")
	local source = capsuleFolder:FindFirstChild(capsuleInfo.ModelName)
	if not source then
		warn(string.format("[EggService] Capsule model missing: %s", capsuleInfo.ModelName))
		return false
	end
	if not getPrimaryPart(source) then
		warn("[EggService] Capsule model missing BasePart")
		return false
	end

	local baseCFrame = buildCFrame(entry.Position, entry.Rotation)
	if not baseCFrame then
		return false
	end
	local targetCFrame = baseCFrame
	if entry.IsLocal then
		if not idleFloor then
			return false
		end
		targetCFrame = toWorldCFrame(idleFloor.CFrame, entry.Position, entry.Rotation)
		if not targetCFrame then
			return false
		end
	end

	local model = source:Clone()
	model.Name = string.format("PlacedCapsule_%d", capsuleInfo.Id)
	model:SetAttribute("CapsuleId", capsuleInfo.Id)
	model:SetAttribute("CapsuleName", capsuleInfo.Name)
	model:SetAttribute("Quality", capsuleInfo.Quality)
	model:SetAttribute("Rarity", capsuleInfo.Rarity)
	model:SetAttribute("OpenSeconds", capsuleInfo.OpenSeconds)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Placed", true)
	if entry.Uid then
		model:SetAttribute("EggUid", entry.Uid)
	end

	local primary = getPrimaryPart(model)
	if model:IsA("Model") and not model.PrimaryPart and primary then
		model.PrimaryPart = primary
	end
	if not primary then
		warn("[EggService] Capsule model missing BasePart")
		model:Destroy()
		return false
	end

	model:PivotTo(targetCFrame)
	setAnchored(model, true)
	model.Parent = placedFolder

	local hatchEndTime = tonumber(entry.HatchEndTime)
	if not hatchEndTime then
		hatchEndTime = os.time() + capsuleInfo.OpenSeconds
		entry.HatchEndTime = hatchEndTime
		DataService:MarkDirty(player)
	end
	model:SetAttribute("HatchEndTime", hatchEndTime)
	setupHatchTimer(model, hatchEndTime)

	return true
end

function EggService:RestorePlayer(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end

	if type(data.Eggs) == "table" then
		local invalidEggs = {}
		local counts = {}
		local order = {}
		local infoById = {}

		for _, entry in ipairs(data.Eggs) do
			local eggId = entry.EggId
			if not eggId then
				table.insert(invalidEggs, entry)
			else
				local capsuleInfo = getCapsuleInfo(eggId)
				if not capsuleInfo then
					table.insert(invalidEggs, entry)
				else
					if not entry.Uid then
						entry.Uid = DataService:GenerateUid()
						DataService:MarkDirty(player)
					end
					if not counts[eggId] then
						counts[eggId] = 0
						table.insert(order, eggId)
					end
					counts[eggId] += 1
					infoById[eggId] = capsuleInfo
				end
			end
		end

		for _, entry in ipairs(invalidEggs) do
			DataService:RemoveEgg(player, entry.Uid, entry.EggId)
		end

		local existingTools = getCapsuleTools(player)
		local kept = {}
		for _, tool in ipairs(existingTools) do
			local toolId = tool:GetAttribute("CapsuleId")
			if counts[toolId] then
				if not kept[toolId] then
					kept[toolId] = tool
				else
					tool:Destroy()
				end
			else
				tool:Destroy()
			end
		end

		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			for index, eggId in ipairs(order) do
				local count = counts[eggId]
				local capsuleInfo = infoById[eggId]
				if count and capsuleInfo then
					local tool = kept[eggId]
					if tool then
						setStackCount(tool, count)
						ensureStackIndex(player, tool, index)
					else
						tool = createCapsuleTool(player, capsuleInfo, count, index)
						if tool then
							tool.Parent = backpack
							kept[eggId] = tool
						end
					end
				end
			end
		end

		local maxIndex = 0
		for _, tool in pairs(kept) do
			local idx = tonumber(tool:GetAttribute("StackIndex")) or 0
			if idx > maxIndex then
				maxIndex = idx
			end
		end
		playerStackIndex[player.UserId] = math.max(playerStackIndex[player.UserId] or 0, maxIndex)
	end

	if type(data.PlacedEggs) == "table" then
		local invalidPlaced = {}
		local homeFolder = getHomeFolder(player)
		local placedFolder = getPlacedFolder(homeFolder)
		local idleFloor = getIdleFloor(homeFolder)
		if placedFolder and idleFloor then
			for _, entry in ipairs(data.PlacedEggs) do
				local eggId = entry.EggId
				if not eggId then
					table.insert(invalidPlaced, entry)
				else
					local eggUid = entry.Uid
					if not eggUid then
						eggUid = DataService:GenerateUid()
						entry.Uid = eggUid
						DataService:MarkDirty(player)
					end
					if not ensureLocalPlacedEntry(player, entry, idleFloor) then
						table.insert(invalidPlaced, entry)
					else
						if not hasPlacedCapsule(placedFolder, eggUid) then
							local capsuleInfo = getCapsuleInfo(eggId)
							if capsuleInfo then
								local ok = self:CreatePlacedCapsuleFromData(player, capsuleInfo, entry, placedFolder, idleFloor)
								if not ok then
									table.insert(invalidPlaced, entry)
								end
							else
								table.insert(invalidPlaced, entry)
							end
						end
					end
				end
			end
		end

		for _, entry in ipairs(invalidPlaced) do
			if entry.Uid then
				DataService:RemovePlacedEgg(player, entry.Uid)
			end
		end
	end
end

local function bindTool(player, tool)
	if toolConnections[tool] then
		return
	end
	if not tool:IsA("Tool") then
		return
	end
	if not tool:GetAttribute("CapsuleId") then
		return
	end

	toolConnections[tool] = tool.Activated:Connect(function()
		EggService:PlaceFromTool(player, tool)
	end)

	tool.AncestryChanged:Connect(function(_, parent)
		if not parent and toolConnections[tool] then
			toolConnections[tool]:Disconnect()
			toolConnections[tool] = nil
		end
	end)
end

function EggService:BindPlayer(player)
	if playerConnections[player] then
		return
	end

	local connections = {}
	playerConnections[player] = connections

	local backpack = player:WaitForChild("Backpack")
	connections.Backpack = backpack.ChildAdded:Connect(function(child)
		bindTool(player, child)
	end)

	connections.Character = player.CharacterAdded:Connect(function(character)
		for _, child in ipairs(character:GetChildren()) do
			bindTool(player, child)
		end
		character.ChildAdded:Connect(function(child)
			bindTool(player, child)
		end)
	end)

	for _, child in ipairs(backpack:GetChildren()) do
		bindTool(player, child)
	end

	self:RestorePlayer(player)
end

function EggService:ClearPlacedCapsules(player)
	local homeFolder = getHomeFolder(player)
	if not homeFolder then
		return
	end
	local placedFolder = homeFolder:FindFirstChild("PlacedCapsules")
	if not placedFolder then
		return
	end
	for _, child in ipairs(placedFolder:GetChildren()) do
		if child:GetAttribute("OwnerUserId") == player.UserId then
			child:Destroy()
		end
	end
end

function EggService:UnbindPlayer(player)
	local connections = playerConnections[player]
	if not connections then
		return
	end
	if connections.Backpack then
		connections.Backpack:Disconnect()
	end
	if connections.Character then
		connections.Character:Disconnect()
	end
	playerConnections[player] = nil

	self:ClearPlacedCapsules(player)
	playerStackIndex[player.UserId] = nil
end

function EggService:ClearPlayerState(player)
	if not player or not player.Parent then
		return
	end

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("CapsuleId") then
				child:Destroy()
			end
		end
	end

	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("CapsuleId") then
				child:Destroy()
			end
		end
	end

	self:ClearPlacedCapsules(player)
	playerStackIndex[player.UserId] = nil
end

return EggService
