--[[
脚本名称: EggService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/EggService
版本: V1.3.1
职责: 盲盒生成/购买/背包/放置与倒计时
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local CapsuleConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CapsuleConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local EggService = {}
EggService.__index = EggService

local toolConnections = {} -- [tool] = connection
local playerConnections = {} -- [player] = {Backpack, Character}

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
	self:GiveCapsuleTool(player, capsuleInfo)
	model:Destroy()
end

function EggService:GiveCapsuleTool(player, capsuleInfo)
	local capsuleFolder = ReplicatedStorage:WaitForChild("Capsule")
	local source = capsuleFolder:FindFirstChild(capsuleInfo.ModelName)
	if not source then
		warn(string.format("[EggService] Capsule model missing: %s", capsuleInfo.ModelName))
		return
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

	local backpack = player:WaitForChild("Backpack")
	tool.Parent = backpack
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

	local capsuleInfo = CapsuleConfig.GetById(capsuleId)
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
		model:Destroy()
		tool:SetAttribute("IsPlacing", false)
		return
	end

	local forward = root.CFrame.LookVector
	local basePos = root.Position + forward * 5
	local floorRayParams = RaycastParams.new()
	floorRayParams.FilterType = Enum.RaycastFilterType.Include
	floorRayParams.FilterDescendantsInstances = { idleFloor }

	local floorResult = Workspace:Raycast(basePos + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0), floorRayParams)
	if not floorResult or floorResult.Instance ~= idleFloor then
		model:Destroy()
		tool:SetAttribute("IsPlacing", false)
		return
	end

	local floorPos = floorResult.Position
	if not isWithinIdleFloor(idleFloor, floorPos) then
		model:Destroy()
		tool:SetAttribute("IsPlacing", false)
		return
	end

	local size = model:GetExtentsSize()
	local blockCheckCFrame = CFrame.new(floorPos + Vector3.new(0, size.Y / 2, 0))
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { idleFloor, character }

	local blocking = Workspace:GetPartBoundsInBox(blockCheckCFrame, size, overlapParams)
	if #blocking > 0 then
		model:Destroy()
		tool:SetAttribute("IsPlacing", false)
		return
	end

	local placeCFrame = CFrame.new(floorPos)
	model:PivotTo(placeCFrame)
	setAnchored(model, true)
	model.Parent = placedFolder

	local hatchEndTime = os.time() + capsuleInfo.OpenSeconds
	model:SetAttribute("HatchEndTime", hatchEndTime)
	model:SetAttribute("HatchReady", false)

	task.delay(capsuleInfo.OpenSeconds, function()
		if model and model.Parent then
			model:SetAttribute("HatchReady", true)
		end
	end)

	tool:Destroy()
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
end

return EggService
