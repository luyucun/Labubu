--[[
脚本名称: ConveyorDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/Client/ConveyorDisplay
版本: V1.0
职责: 传送带盲盒本地表现与购买请求
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local configFolder = ReplicatedStorage:WaitForChild("Config")
local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(configFolder:WaitForChild("GameConfig"))
local CapsuleConfig = require(configFolder:WaitForChild("CapsuleConfig"))
local FormatHelper = require(modulesFolder:WaitForChild("FormatHelper"))

local RARITY_LABELS = {
	[2] = "Light",
	[3] = "Gold",
	[4] = "Diamond",
	[5] = "Rainbow",
}

local QUALITY_NAME_COLORS = {
	[1] = Color3.fromRGB(0, 255, 0),
	[2] = Color3.fromRGB(0, 255, 255),
	[3] = Color3.fromRGB(170, 0, 170),
	[4] = Color3.fromRGB(255, 255, 0),
	[5] = Color3.fromRGB(255, 0, 0),
	[6] = Color3.fromRGB(255, 152, 220),
	[7] = Color3.fromRGB(0, 255, 255),
}

local PROMPT_MAX_DISTANCE = 20
local PURCHASE_COOLDOWN = 0.25

local function getServerTimeNow()
	local ok, value = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	if ok and type(value) == "number" then
		return value
	end
	return os.time()
end

local function ensureLabubuEvents()
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		return nil
	end
	return eventsFolder:WaitForChild("LabubuEvents", 10)
end

local function getEvent(name)
	local labubuEvents = ensureLabubuEvents()
	if not labubuEvents then
		return nil
	end
	local event = labubuEvents:WaitForChild(name, 10)
	if event and event:IsA("RemoteEvent") then
		return event
	end
	return nil
end

local spawnEvent = getEvent("PushConveyorEggSpawn")
if not spawnEvent then
	warn("[ConveyorDisplay] PushConveyorEggSpawn event not found")
end
local removeEvent = getEvent("PushConveyorEggRemove")
if not removeEvent then
	warn("[ConveyorDisplay] PushConveyorEggRemove event not found")
end
local buyEvent = getEvent("BuyConveyorEgg")
if not buyEvent then
	warn("[ConveyorDisplay] BuyConveyorEgg event not found")
end

local function formatHomeName(index)
	return string.format("%s%02d", GameConfig.HomeSlotPrefix, index)
end

local function getHomeFolder()
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

local function resolveCFrame(marker)
	if marker:IsA("BasePart") then
		return marker.CFrame
	end
	if marker:IsA("Attachment") then
		return marker.WorldCFrame
	end
	if marker:IsA("Model") then
		return marker:GetPivot()
	end
	return nil
end

local function getConveyorPath()
	local homeFolder = getHomeFolder()
	if not homeFolder then
		return nil, nil
	end
	local conveyorFolder = homeFolder:FindFirstChild("ConveyorBelt")
	if not conveyorFolder then
		return nil, nil
	end
	local startMarker = conveyorFolder:FindFirstChild("Start", true)
	local endMarker = conveyorFolder:FindFirstChild("End", true)
	if not startMarker or not endMarker then
		return nil, nil
	end
	return resolveCFrame(startMarker), resolveCFrame(endMarker)
end

local function waitForConveyorPath(timeoutSeconds)
	local timeout = tonumber(timeoutSeconds) or 5
	local startTime = os.clock()
	while os.clock() - startTime < timeout do
		local startCFrame, endCFrame = getConveyorPath()
		if startCFrame and endCFrame then
			return startCFrame, endCFrame
		end
		task.wait(0.1)
	end
	return nil, nil
end

local function getCapsuleInfo(capsuleId)
	local normalized = tonumber(capsuleId) or capsuleId
	if type(CapsuleConfig.GetById) == "function" then
		return CapsuleConfig.GetById(normalized)
	end
	local list = CapsuleConfig.Capsules
	if type(list) ~= "table" and type(CapsuleConfig) == "table" then
		list = CapsuleConfig
	end
	if type(list) ~= "table" then
		return nil
	end
	for _, info in ipairs(list) do
		if info.Id == normalized then
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

local function isPlayerNearModel(model, maxDistance)
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local primary = getPrimaryPart(model)
	if not primary then
		return false
	end
	local distance = (root.Position - primary.Position).Magnitude
	return distance <= (maxDistance or PROMPT_MAX_DISTANCE)
end

local function setAnchored(model, anchored)
	if not model then
		return
	end
	if model:IsA("BasePart") then
		model.Anchored = anchored
		model.CanCollide = false
		model.CanQuery = true
		return
	end
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = anchored
			obj.CanCollide = false
			obj.CanQuery = true
		end
	end
end

local function getCapsuleInfoHeight(model, part)
	if model and model:IsA("Model") then
		return model:GetExtentsSize().Y
	end
	if part and part:IsA("BasePart") then
		return part.Size.Y
	end
	return 0
end

local function createBuyPrompt(model, part, price)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = FormatHelper.FormatCoinsShort(price, true)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false

	local attachment = Instance.new("Attachment")
	attachment.Name = "CapsulePrompt"
	attachment.Position = Vector3.new(0, getCapsuleInfoHeight(model, part) * 0.6, 0)
	attachment.Parent = part

	prompt.Parent = attachment
	return prompt
end

local function applyCapsuleInfoBillboard(model, capsuleInfo)
	if not model then
		return
	end
	local info = type(capsuleInfo) == "table" and capsuleInfo or nil
	local template = ReplicatedStorage:FindFirstChild("CapsuleInfo")
	if not template or not template:IsA("BillboardGui") then
		return
	end
	local primary = getPrimaryPart(model)
	if not primary then
		return
	end
	local existing = model:FindFirstChild("CapsuleInfo")
	if existing and existing:IsA("BillboardGui") then
		existing:Destroy()
	end
	local legacy = primary:FindFirstChild("CapsuleInfo")
	if legacy and legacy:IsA("BillboardGui") then
		legacy:Destroy()
	end

	local billboard = template:Clone()
	billboard.Enabled = true
	billboard.Adornee = primary
	billboard.Parent = model
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	local baseOffset = billboard.StudsOffset
	local height = getCapsuleInfoHeight(model, primary)
	local scale = billboard:GetAttribute("OffsetScale")
	if type(scale) ~= "number" then
		scale = 0.6
	end
	local infoScale = model:GetAttribute("CapsuleInfoScale")
	if type(infoScale) ~= "number" then
		infoScale = 1
	end
	local extra = billboard:GetAttribute("OffsetY")
	if type(extra) ~= "number" then
		extra = 0
	end
	billboard.StudsOffset = Vector3.new(baseOffset.X, (height * scale + extra) * infoScale, baseOffset.Z)

	local nameLabel = billboard:FindFirstChild("Name", true)
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = tostring((info and info.Name) or model:GetAttribute("CapsuleName") or model.Name)
		local quality = tonumber(info and info.Quality) or tonumber(model:GetAttribute("Quality")) or 0
		local color = QUALITY_NAME_COLORS[quality]
		if color then
			nameLabel.TextColor3 = color
		end
	end

	local priceLabel = billboard:FindFirstChild("Price", true)
	if priceLabel and priceLabel:IsA("TextLabel") then
		local price = tonumber(info and info.Price) or tonumber(model:GetAttribute("Price")) or 0
		priceLabel.Text = FormatHelper.FormatCoinsShort(price, true)
	end

	for _, labelName in ipairs({ "Light", "Gold", "Diamond", "Rainbow" }) do
		local label = billboard:FindFirstChild(labelName, true)
		if label and label:IsA("GuiObject") then
			label.Visible = false
		end
	end

	local rarity = tonumber(info and info.Rarity) or tonumber(model:GetAttribute("Rarity")) or 1
	local targetName = RARITY_LABELS[rarity]
	if targetName then
		local label = billboard:FindFirstChild(targetName, true)
		if label and label:IsA("GuiObject") then
			label.Visible = true
		end
	end
end

local container = Workspace:FindFirstChild("ClientConveyorCapsules")
if not container then
	container = Instance.new("Folder")
	container.Name = "ClientConveyorCapsules"
	container.Parent = Workspace
end

local activeCapsules = {} -- [uid] = {Model, Tween, CFrameValue, Conn}
local lastPurchase = 0

local function requestPurchase(uid)
	if not buyEvent then
		return
	end
	local now = os.clock()
	if now - lastPurchase < PURCHASE_COOLDOWN then
		return
	end
	lastPurchase = now
	buyEvent:FireServer(uid)
end

local function cleanupCapsule(uid)
	local entry = activeCapsules[uid]
	if not entry then
		return
	end
	if entry.Tween then
		entry.Tween:Cancel()
	end
	if entry.Conn then
		entry.Conn:Disconnect()
	end
	if entry.CFrameValue then
		entry.CFrameValue:Destroy()
	end
	if entry.Model and entry.Model.Parent then
		entry.Model:Destroy()
	end
	activeCapsules[uid] = nil
end

local function spawnCapsule(payload)
	if type(payload) ~= "table" then
		return
	end
	local uid = payload.Uid
	if type(uid) ~= "string" or uid == "" then
		return
	end
	cleanupCapsule(uid)

	local capsuleInfo = getCapsuleInfo(payload.CapsuleId)
	if not capsuleInfo then
		return
	end
	local capsuleFolder = ReplicatedStorage:FindFirstChild("Capsule")
	if not capsuleFolder then
		return
	end
	local source = capsuleFolder:FindFirstChild(capsuleInfo.ModelName)
	if not source then
		return
	end
	local model = source:Clone()
	model.Name = string.format("ClientCapsule_%s", uid)
	model:SetAttribute("ConveyorUid", uid)
	model:SetAttribute("CapsuleId", capsuleInfo.Id)
	model:SetAttribute("CapsuleName", capsuleInfo.Name)
	model:SetAttribute("Quality", capsuleInfo.Quality)
	model:SetAttribute("Rarity", payload.Rarity or capsuleInfo.Rarity)
	model:SetAttribute("Price", payload.Price or capsuleInfo.Price)
	model:SetAttribute("OpenSeconds", capsuleInfo.OpenSeconds)
	model:SetAttribute("OwnerUserId", player.UserId)

	local primary = getPrimaryPart(model)
	if model:IsA("Model") and not model.PrimaryPart and primary then
		model.PrimaryPart = primary
	end
	if not primary then
		model:Destroy()
		return
	end

	local rarity = tonumber(payload.Rarity) or tonumber(capsuleInfo.Rarity) or 1
	if rarity > 1 then
		if model:IsA("Model") then
			model:ScaleTo(1.5)
		elseif model:IsA("BasePart") then
			model.Size = model.Size * 1.5
		end
		model:SetAttribute("CapsuleInfoScale", 1.5)
	end

	applyCapsuleInfoBillboard(model, capsuleInfo)
	local prompt = createBuyPrompt(model, primary, payload.Price or capsuleInfo.Price)
	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then
			return
		end
		requestPurchase(uid)
	end)
	model.Parent = container

	local startCFrame, endCFrame = waitForConveyorPath(5)
	if not startCFrame or not endCFrame then
		model:Destroy()
		return
	end

	local moveTime = tonumber(payload.MoveTime) or tonumber(GameConfig.ConveyorMoveTime) or 0
	local expireAt = tonumber(payload.ExpireAt)
	if expireAt then
		local remaining = expireAt - getServerTimeNow()
		if remaining <= 0 then
			model:Destroy()
			return
		end
		if moveTime <= 0 or remaining < moveTime then
			moveTime = remaining
		end
	end
	if moveTime <= 0 then
		model:Destroy()
		return
	end
	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = startCFrame
	setAnchored(model, true)
	model:PivotTo(startCFrame)

	local conn
	conn = cframeValue.Changed:Connect(function()
		if model and model.Parent then
			model:PivotTo(cframeValue.Value)
		else
			if conn then
				conn:Disconnect()
				conn = nil
			end
		end
	end)

	local tween = TweenService:Create(cframeValue, TweenInfo.new(moveTime, Enum.EasingStyle.Linear), { Value = endCFrame })
	activeCapsules[uid] = {
		Model = model,
		Tween = tween,
		CFrameValue = cframeValue,
		Conn = conn,
	}
	tween:Play()
	tween.Completed:Connect(function()
		cleanupCapsule(uid)
	end)
end

if spawnEvent then
	spawnEvent.OnClientEvent:Connect(spawnCapsule)
end

if removeEvent then
	removeEvent.OnClientEvent:Connect(function(uid)
		if type(uid) ~= "string" then
			return
		end
		cleanupCapsule(uid)
	end)
end

local function findCapsuleUid(instance)
	local current = instance
	while current and current ~= Workspace do
		local uid = current:GetAttribute("ConveyorUid")
		if uid then
			return uid
		end
		current = current.Parent
	end
	return nil
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local pos = input.Position
	local ray = camera:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = {}
	if player.Character then
		filter[#filter + 1] = player.Character
	end
	params.FilterDescendantsInstances = filter
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if not result or not result.Instance then
		return
	end
	local uid = findCapsuleUid(result.Instance)
	if not uid then
		return
	end
	local entry = activeCapsules[uid]
	if not entry or not entry.Model then
		return
	end
	if not isPlayerNearModel(entry.Model, PROMPT_MAX_DISTANCE) then
		return
	end
	requestPurchase(uid)
end)
