--[[
脚本名称: ConveyorService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/ConveyorService
版本: V1.3.1
职责: 传送带刷新盲盒与移动销毁
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local CapsuleConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CapsuleConfig"))
local CapsuleSpawnPoolConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CapsuleSpawnPoolConfig"))

local EggService = require(script.Parent:WaitForChild("EggService"))

local ConveyorService = {}
ConveyorService.__index = ConveyorService

local rng = Random.new()
local running = {} -- [userId] = {Active = bool}

local function getCapsuleFolder(conveyorFolder)
	local folder = conveyorFolder:FindFirstChild("Capsules")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Capsules"
		folder.Parent = conveyorFolder
	end
	return folder
end

local function pickRandomCapsule(poolId)
	local pool = CapsuleSpawnPoolConfig.GetPool(poolId)
	if not pool then
		warn(string.format("[ConveyorService] Spawn pool not found: %s", tostring(poolId)))
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
				local capsuleInfo = CapsuleConfig.GetById(entry.CapsuleId)
				if not capsuleInfo then
					warn(string.format("[ConveyorService] Capsule config missing: %s", tostring(entry.CapsuleId)))
					return nil
				end
				return capsuleInfo
			end
		end
	end

	local lastEntry = pool[#pool]
	if not lastEntry then
		return nil
	end
	local capsuleInfo = CapsuleConfig.GetById(lastEntry.CapsuleId)
	if not capsuleInfo then
		warn(string.format("[ConveyorService] Capsule config missing: %s", tostring(lastEntry.CapsuleId)))
		return nil
	end
	return capsuleInfo
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

local function moveCapsule(model, startCFrame, endCFrame)
	local capsuleName = model:GetAttribute("CapsuleName") or model.Name
	local capsuleId = model:GetAttribute("CapsuleId") or 0
	print(string.format("[ConveyorService] moveCapsule start: %s (id=%d)", capsuleName, capsuleId))

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = startCFrame
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

	local tweenInfo = TweenInfo.new(GameConfig.ConveyorMoveTime, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(cframeValue, tweenInfo, { Value = endCFrame })
	tween:Play()
	tween.Completed:Connect(function()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		cframeValue:Destroy()
		if model and model.Parent then
			local endPos = model:GetPivot().Position
			print(string.format("[ConveyorService] Capsule destroyed (reached end): %s (id=%d), endPos=(%.1f,%.1f,%.1f)",
				capsuleName, capsuleId, endPos.X, endPos.Y, endPos.Z))
			model:Destroy()
		end
	end)
end

function ConveyorService:StartForPlayer(player, homeSlot)
	print(string.format("[ConveyorService] StartForPlayer called: userId=%d", player.UserId))

	local homeFolder = homeSlot and homeSlot.Folder
	if not homeFolder then
		warn("[ConveyorService] homeFolder is nil")
		return
	end
	print(string.format("[ConveyorService] homeFolder found: %s", homeFolder:GetFullName()))

	local conveyorFolder = homeFolder:FindFirstChild("ConveyorBelt")
	if not conveyorFolder then
		warn("[ConveyorService] ConveyorBelt not found")
		return
	end
	print(string.format("[ConveyorService] ConveyorBelt found: %s", conveyorFolder:GetFullName()))

	local startMarker = conveyorFolder:FindFirstChild("Start", true)
	local endMarker = conveyorFolder:FindFirstChild("End", true)
	if not startMarker or not endMarker then
		warn(string.format("[ConveyorService] Start/End not found: Start=%s, End=%s", tostring(startMarker), tostring(endMarker)))
		return
	end
	print(string.format("[ConveyorService] Markers found: Start=%s, End=%s", startMarker:GetFullName(), endMarker:GetFullName()))

	local startCFrame = resolveCFrame(startMarker)
	local endCFrame = resolveCFrame(endMarker)
	if not startCFrame or not endCFrame then
		warn("[ConveyorService] Start/End must be BasePart/Attachment/Model")
		return
	end
	print(string.format("[ConveyorService] StartPos=(%.1f,%.1f,%.1f), EndPos=(%.1f,%.1f,%.1f)",
		startCFrame.Position.X, startCFrame.Position.Y, startCFrame.Position.Z,
		endCFrame.Position.X, endCFrame.Position.Y, endCFrame.Position.Z))

	local state = { Active = true }
	running[player.UserId] = state
	print(string.format("[ConveyorService] Spawn loop starting for userId=%d", player.UserId))

	task.spawn(function()
		local spawnCount = 0
		while state.Active and player.Parent do
			local capsuleInfo = pickRandomCapsule(GameConfig.CapsuleSpawnPoolId)
			if capsuleInfo then
				local model = EggService:CreateConveyorCapsule(capsuleInfo, player.UserId)
				if model then
					spawnCount += 1
					model.Parent = getCapsuleFolder(conveyorFolder)
					local pos = model:GetPivot().Position
					print(string.format("[ConveyorService] Capsule #%d spawned: name=%s, id=%d, pos=(%.1f,%.1f,%.1f)",
						spawnCount, capsuleInfo.Name, capsuleInfo.Id, pos.X, pos.Y, pos.Z))
					moveCapsule(model, startCFrame, endCFrame)
				else
					warn(string.format("[ConveyorService] CreateConveyorCapsule returned nil for: %s", capsuleInfo.Name))
				end
			else
				warn("[ConveyorService] pickRandomCapsule returned nil")
			end
			task.wait(GameConfig.ConveyorSpawnInterval)
		end
		print(string.format("[ConveyorService] Spawn loop ended for userId=%d, total spawned=%d", player.UserId, spawnCount))
	end)
end

function ConveyorService:StopForPlayer(player)
	local state = running[player.UserId]
	if state then
		state.Active = false
		running[player.UserId] = nil
	end

	local homeFolder = Workspace:FindFirstChild(GameConfig.HomeFolderName)
	if not homeFolder then
		return
	end
	for _, folder in ipairs(homeFolder:GetChildren()) do
		local conveyorFolder = folder:FindFirstChild("ConveyorBelt")
		if conveyorFolder then
			local capsuleFolder = conveyorFolder:FindFirstChild("Capsules")
			if capsuleFolder then
				for _, obj in ipairs(capsuleFolder:GetChildren()) do
					if obj:GetAttribute("OwnerUserId") == player.UserId then
						obj:Destroy()
					end
				end
			end
		end
	end
end

return ConveyorService
