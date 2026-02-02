--[[
脚本名称: GuideService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/GuideService
版本: V1.0
职责: 新手引导流程控制/Beam指引/提示同步
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local FigurineConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FigurineConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local GuideService = {}
GuideService.__index = GuideService

local GUIDE_CAPSULE_ID = 1001
local GUIDE_STEP_MAX = 5
local GUIDE_TEXT = {
	[1] = "Buy a blind box",
	[2] = "Head to the destination",
	[3] = "Put this blind box on the ground",
	[4] = "Unbox this blind box",
	[5] = "Tap to collect cash",
}

local playerStates = {}
local loopStarted = false

local function ensureLabubuEvents()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		eventsFolder = Instance.new("Folder")
		eventsFolder.Name = "Events"
		eventsFolder.Parent = ReplicatedStorage
	end
	local labubuEvents = eventsFolder:FindFirstChild("LabubuEvents")
	if not labubuEvents then
		labubuEvents = Instance.new("Folder")
		labubuEvents.Name = "LabubuEvents"
		labubuEvents.Parent = eventsFolder
	end
	return labubuEvents
end

local function ensureRemoteEvent(name)
	local labubuEvents = ensureLabubuEvents()
	local event = labubuEvents:FindFirstChild(name)
	if event and not event:IsA("RemoteEvent") then
		event:Destroy()
		event = nil
	end
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = labubuEvents
	end
	return event
end

local pushGuideStateEvent = ensureRemoteEvent("PushGuideState")
local focusExitEvent = ensureRemoteEvent("NotifyCameraFocusExit")
local focusExitBound = false

local function formatHomeName(index)
	return string.format("%s%02d", GameConfig.HomeSlotPrefix, index)
end

local function getHomeFolder(player)
	if not player then
		return nil
	end
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
	if not idleFloor or not worldPos then
		return false
	end
	local localPos = idleFloor.CFrame:PointToObjectSpace(worldPos)
	local halfSize = idleFloor.Size * 0.5
	return math.abs(localPos.X) <= halfSize.X and math.abs(localPos.Z) <= halfSize.Z
end

local function resolveTargetPart(target)
	if not target then
		return nil
	end
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") then
		if target.PrimaryPart then
			return target.PrimaryPart
		end
		return target:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function resolveGuideRootPart(instance)
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		if not instance.PrimaryPart then
			local part = instance:FindFirstChildWhichIsA("BasePart", true)
			if part then
				instance.PrimaryPart = part
			end
		end
		return instance.PrimaryPart
	end
	return nil
end

local function findFirstAttachment(root)
	if not root then
		return nil
	end
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("Attachment") then
			return obj
		end
	end
	return nil
end

local function fixBeamAttachments(guide01, guide02)
	if not guide01 or not guide02 then
		return
	end
	local att0 = guide01:FindFirstChild("Attachment0", true) or findFirstAttachment(guide01)
	local att1 = guide02:FindFirstChild("Attachment1", true) or findFirstAttachment(guide02)
	if not att0 or not att1 then
		return
	end
	for _, obj in ipairs(guide01:GetDescendants()) do
		if obj:IsA("Beam") then
			if not obj.Attachment0 or not obj.Attachment0:IsDescendantOf(guide01) then
				obj.Attachment0 = att0
			end
			if not obj.Attachment1 or not obj.Attachment1:IsDescendantOf(guide02) then
				obj.Attachment1 = att1
			end
		end
	end
	for _, obj in ipairs(guide02:GetDescendants()) do
		if obj:IsA("Beam") then
			if not obj.Attachment0 or not obj.Attachment0:IsDescendantOf(guide01) then
				obj.Attachment0 = att0
			end
			if not obj.Attachment1 or not obj.Attachment1:IsDescendantOf(guide02) then
				obj.Attachment1 = att1
			end
		end
	end
end

local function attachGuideToTarget(guideInstance, targetPart)
	if not guideInstance or not targetPart then
		return nil
	end
	local rootPart = resolveGuideRootPart(guideInstance)
	if not rootPart then
		return nil
	end
	guideInstance.Parent = targetPart
	if guideInstance:IsA("Model") then
		guideInstance:PivotTo(targetPart.CFrame)
	else
		rootPart.CFrame = targetPart.CFrame
	end
	rootPart.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = targetPart
	weld.Parent = rootPart
	return rootPart
end

local function cloneGuidePart(name)
	local guideFolder = ReplicatedStorage:FindFirstChild("GuideEffect")
	if not guideFolder then
		warn("[GuideService] GuideEffect folder missing")
		return nil
	end
	local source = guideFolder:FindFirstChild(name)
	if not source then
		warn(string.format("[GuideService] Guide part missing: %s", tostring(name)))
		return nil
	end
	return source:Clone()
end

local function findConveyorCapsule(player, capsuleId)
	local homeFolder = getHomeFolder(player)
	if not homeFolder then
		return nil
	end
	local conveyorFolder = homeFolder:FindFirstChild("ConveyorBelt")
	if not conveyorFolder then
		return nil
	end
	local capsuleFolder = conveyorFolder:FindFirstChild("Capsules")
	if not capsuleFolder then
		return nil
	end
	for _, child in ipairs(capsuleFolder:GetChildren()) do
		if (child:IsA("Model") or child:IsA("BasePart")) and child:GetAttribute("CapsuleId") == capsuleId then
			return child
		end
	end
	return nil
end

local function hasEquippedCapsule(player, capsuleId)
	local character = player.Character
	if not character then
		return false
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			local id = tonumber(child:GetAttribute("CapsuleId")) or child:GetAttribute("CapsuleId")
			if id == capsuleId then
				return true
			end
		end
	end
	return false
end

local function hasPlacedEgg(player)
	local placedEggs = DataService:GetPlacedEggs(player)
	if type(placedEggs) ~= "table" then
		return false
	end
	return #placedEggs > 0
end

local function hasReadyPlacedEgg(player)
	local homeFolder = getHomeFolder(player)
	if not homeFolder then
		return false
	end
	local placedFolder = homeFolder:FindFirstChild("PlacedCapsules")
	if not placedFolder then
		return false
	end
	for _, child in ipairs(placedFolder:GetChildren()) do
		if child:GetAttribute("OwnerUserId") == player.UserId and child:GetAttribute("HatchReady") == true then
			return true
		end
	end
	return false
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

local function getClaimButtonForFigurine(player, figurineId)
	local info = FigurineConfig.GetById and FigurineConfig.GetById(figurineId) or nil
	if not info or not info.ClaimButtonPath then
		return nil
	end
	local homeFolder = getHomeFolder(player)
	if not homeFolder then
		return nil
	end
	return resolveClaimButton(homeFolder, info.ClaimButtonPath)
end

local function getAnyOwnedFigurineId(player)
	local figurines = DataService:GetFigurines(player)
	if type(figurines) ~= "table" then
		return nil
	end
	local picked
	for id, owned in pairs(figurines) do
		if owned then
			local num = tonumber(id) or id
			if not picked or (tonumber(num) and num < picked) then
				picked = num
			end
		end
	end
	return picked
end

local function stepNeedsBeam(step)
	return step == 1 or step == 2 or step == 5
end

local function getPlayerState(player)
	local state = playerStates[player.UserId]
	if state then
		return state
	end
	state = {
		Active = true,
		Step = 0,
		Step4Ready = false,
		CollectFigurineId = nil,
		PendingCollectFigurineId = nil,
		WaitingForFocusExit = false,
		Guide01 = nil,
		Guide02 = nil,
		BeamOwner = nil,
		BeamTarget = nil,
		LastDisplay = nil,
	}
	playerStates[player.UserId] = state
	return state
end

local function clearBeam(state)
	if not state then
		return
	end
	if state.Guide01 then
		state.Guide01:Destroy()
	end
	if state.Guide02 then
		state.Guide02:Destroy()
	end
	state.Guide01 = nil
	state.Guide02 = nil
	state.BeamOwner = nil
	state.BeamTarget = nil
end

local function ensureBeam(player, state, target)
	if not player or not state then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local targetPart = resolveTargetPart(target)
	if not root or not targetPart then
		clearBeam(state)
		return
	end
	if state.Guide01
		and state.Guide02
		and state.Guide01.Parent
		and state.Guide02.Parent
		and state.BeamOwner == root
		and state.BeamTarget == targetPart then
		return
	end

	clearBeam(state)
	local guide01 = cloneGuidePart("Guide01")
	local guide02 = cloneGuidePart("Guide02")
	if not guide01 or not guide02 then
		return
	end
	attachGuideToTarget(guide01, targetPart)
	attachGuideToTarget(guide02, root)
	fixBeamAttachments(guide01, guide02)
	state.Guide01 = guide01
	state.Guide02 = guide02
	state.BeamOwner = root
	state.BeamTarget = targetPart
end

local function sendGuideState(player, state)
	if not pushGuideStateEvent or not player or not player.Parent then
		return
	end
	local step = state.Step or 0
	local showTips = false
	local text = ""
	local showFinger = false
	if step > 0 then
		if step == 4 then
			showTips = state.Step4Ready == true
		else
			showTips = true
		end
		if showTips then
			text = GUIDE_TEXT[step] or ""
		end
		showFinger = step == 3
	end

	local payload = {
		Step = step,
		ShowTips = showTips,
		Text = text,
		ShowFinger = showFinger,
		FingerCapsuleId = GUIDE_CAPSULE_ID,
	}

	local last = state.LastDisplay
	local changed = false
	if not last then
		changed = true
	else
		for key, value in pairs(payload) do
			if last[key] ~= value then
				changed = true
				break
			end
		end
	end

	if not changed then
		return
	end
	state.LastDisplay = payload
	pushGuideStateEvent:FireClient(player, payload)
end

local function setGuideStep(player, state, step, options)
	if not player or not state then
		return
	end
	local normalized = tonumber(step) or 0
	if normalized < 0 then
		normalized = 0
	end
	if normalized > GUIDE_STEP_MAX then
		normalized = GUIDE_STEP_MAX
	end
	DataService:SetGuideStep(player, normalized)
	state.Step = normalized
	state.Step4Ready = false
	state.PendingCollectFigurineId = nil
	state.WaitingForFocusExit = false
	if normalized == 5 then
		state.CollectFigurineId = options and options.CollectFigurineId or state.CollectFigurineId
	else
		state.CollectFigurineId = nil
	end
	if not stepNeedsBeam(normalized) then
		clearBeam(state)
	end
	sendGuideState(player, state)
end

local function refreshStep4Ready(player, state)
	if not player or not state or state.Step ~= 4 then
		return
	end
	local ready = hasReadyPlacedEgg(player)
	if state.Step4Ready ~= ready then
		state.Step4Ready = ready
		sendGuideState(player, state)
	end
end

local function updatePlayer(player, state)
	if not player or not player.Parent or not state then
		return
	end
	local step = state.Step
	if step <= 0 then
		clearBeam(state)
		sendGuideState(player, state)
		return
	end

	if step == 1 then
		local target = findConveyorCapsule(player, GUIDE_CAPSULE_ID)
		ensureBeam(player, state, target)
		sendGuideState(player, state)
		return
	end

	if step == 2 then
		if hasPlacedEgg(player) then
			setGuideStep(player, state, 4)
			return
		end
		local homeFolder = getHomeFolder(player)
		local idleFloor = getIdleFloor(homeFolder)
		ensureBeam(player, state, idleFloor)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if idleFloor and root and isWithinIdleFloor(idleFloor, root.Position) then
			setGuideStep(player, state, 3)
		else
			sendGuideState(player, state)
		end
		return
	end

	if step == 3 then
		if hasPlacedEgg(player) then
			setGuideStep(player, state, 4)
			return
		end
		if hasEquippedCapsule(player, GUIDE_CAPSULE_ID) then
			setGuideStep(player, state, 4)
			return
		end
		sendGuideState(player, state)
		return
	end

	if step == 4 then
		refreshStep4Ready(player, state)
		return
	end

	if step == 5 then
		if not state.CollectFigurineId then
			state.CollectFigurineId = getAnyOwnedFigurineId(player)
		end
		local targetButton = state.CollectFigurineId and getClaimButtonForFigurine(player, state.CollectFigurineId) or nil
		ensureBeam(player, state, targetButton)
		sendGuideState(player, state)
	end
end

function GuideService:Init()
	if loopStarted then
		return
	end
	loopStarted = true
	if focusExitEvent and not focusExitBound then
		focusExitBound = true
		focusExitEvent.OnServerEvent:Connect(function(player)
			GuideService:HandleCameraFocusExit(player)
		end)
	end
	task.spawn(function()
		while true do
			for userId, state in pairs(playerStates) do
				local player = Players:GetPlayerByUserId(userId)
				if not player then
					clearBeam(state)
					playerStates[userId] = nil
				else
					updatePlayer(player, state)
				end
			end
			task.wait(0.3)
		end
	end)
end

function GuideService:BindPlayer(player)
	if not player or not player.Parent then
		return
	end
	local state = getPlayerState(player)
	state.Active = true
	state.Step = DataService:GetGuideStep(player)
	state.Step4Ready = false
	state.CollectFigurineId = nil
	sendGuideState(player, state)
end

function GuideService:UnbindPlayer(player)
	if not player then
		return
	end
	local state = playerStates[player.UserId]
	if not state then
		return
	end
	clearBeam(state)
	playerStates[player.UserId] = nil
end

function GuideService:ResetGuide(player)
	if not player or not player.Parent then
		return
	end
	local state = getPlayerState(player)
	clearBeam(state)
	setGuideStep(player, state, 1)
end

function GuideService:HandleEggPurchased(player, capsuleId)
	if not player or not player.Parent then
		return
	end
	local state = getPlayerState(player)
	if state.Step ~= 1 then
		return
	end
	setGuideStep(player, state, 2)
end

function GuideService:HandleEggPlaced(player)
	if not player or not player.Parent then
		return
	end
	local state = getPlayerState(player)
	if state.Step <= 0 then
		return
	end
	if state.Step <= 3 then
		setGuideStep(player, state, 4)
	end
end

function GuideService:HandleEggOpened(player, figurineId)
	if not player or not player.Parent then
		return
	end
	local state = getPlayerState(player)
	if state.Step ~= 4 then
		return
	end
	state.PendingCollectFigurineId = tonumber(figurineId) or figurineId
	state.WaitingForFocusExit = true
	sendGuideState(player, state)
end

function GuideService:HandleCameraFocusExit(player)
	if not player or not player.Parent then
		return
	end
	local state = getPlayerState(player)
	if state.Step ~= 4 then
		return
	end
	if not state.WaitingForFocusExit then
		return
	end
	local figurineId = state.PendingCollectFigurineId
	state.PendingCollectFigurineId = nil
	state.WaitingForFocusExit = false
	setGuideStep(player, state, 5, { CollectFigurineId = figurineId })
end

function GuideService:HandleCoinsCollected(player, figurineId)
	if not player or not player.Parent then
		return
	end
	local state = getPlayerState(player)
	if state.Step ~= 5 then
		return
	end
	setGuideStep(player, state, 0)
end

return GuideService
