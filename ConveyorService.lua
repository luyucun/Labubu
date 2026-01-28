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
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))

local capsuleByQualityRarity = {}
do
	local list = CapsuleConfig.Capsules
	if type(list) == "table" then
		for _, info in ipairs(list) do
			local quality = tonumber(info.Quality)
			local rarity = tonumber(info.Rarity)
			if quality and rarity then
				capsuleByQualityRarity[quality] = capsuleByQualityRarity[quality] or {}
				capsuleByQualityRarity[quality][rarity] = info
			end
		end
	end
end

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

local function refreshCapsuleBillboards(capsuleFolder, userId)
	if not capsuleFolder then
		return
	end
	for _, obj in ipairs(capsuleFolder:GetChildren()) do
		if obj:IsA("Model") or obj:IsA("BasePart") then
			if not userId or obj:GetAttribute("OwnerUserId") == userId then
				EggService:RefreshCapsuleInfo(obj)
			end
		end
	end
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
		warn("[ConveyorService] CapsuleConfig missing GetById")
		return nil
	end

	for _, info in ipairs(list) do
		if info.Id == capsuleId then
			return info
		end
	end
	return nil
end

local function pickWeightedEntry(list)
	if type(list) ~= "table" or #list == 0 then
		return nil
	end

	local totalWeight = 0
	for _, entry in ipairs(list) do
		local weight = tonumber(entry.Weight) or 0
		if weight > 0 then
			totalWeight += weight
		end
	end
	if totalWeight <= 0 then
		return nil
	end

	local roll = rng:NextNumber(0, totalWeight)
	local acc = 0
	for _, entry in ipairs(list) do
		local weight = tonumber(entry.Weight) or 0
		if weight > 0 then
			acc += weight
			if roll <= acc then
				return entry
			end
		end
	end

	return list[#list]
end

local function getUnlockedPoolId(outputSpeed)
	local defaultPoolId = tonumber(GameConfig.CapsuleSpawnPoolId) or 1
	local unlocks = CapsuleSpawnPoolConfig.GetUnlocks and CapsuleSpawnPoolConfig.GetUnlocks()
	if type(unlocks) ~= "table" or #unlocks == 0 then
		return defaultPoolId
	end

	local speed = tonumber(outputSpeed) or 0
	local bestPoolId = nil
	local bestUnlockSpeed = nil
	for _, entry in ipairs(unlocks) do
		local unlockSpeed = tonumber(entry.UnlockOutputSpeed) or 0
		local poolId = tonumber(entry.PoolId)
		if poolId and unlockSpeed <= speed then
			if not bestUnlockSpeed or unlockSpeed >= bestUnlockSpeed then
				bestUnlockSpeed = unlockSpeed
				bestPoolId = poolId
			end
		end
	end

	return bestPoolId or defaultPoolId
end

local function rollRarity()
	local mutation = CapsuleSpawnPoolConfig.GetRarityMutation and CapsuleSpawnPoolConfig.GetRarityMutation()
	local entry = pickWeightedEntry(mutation)
	if not entry then
		return 1
	end
	return tonumber(entry.Rarity) or 1
end

local function applyRarityMutation(baseCapsuleInfo)
	if not baseCapsuleInfo then
		return nil
	end

	local quality = tonumber(baseCapsuleInfo.Quality)
	if not quality then
		return baseCapsuleInfo
	end

	local rarity = rollRarity()
	local rarityTable = capsuleByQualityRarity[quality]
	if not rarityTable then
		return baseCapsuleInfo
	end

	return rarityTable[rarity] or rarityTable[1] or baseCapsuleInfo
end

local function applyExtraMutation(player, capsuleInfo)
	if not capsuleInfo or not ProgressionService then
		return capsuleInfo
	end
	local rarity = tonumber(capsuleInfo.Rarity) or 0
	if rarity <= 0 or rarity >= 5 then
		return capsuleInfo
	end
	local chance = ProgressionService:GetRarityUpgradeChance(player, rarity)
	if chance <= 0 then
		return capsuleInfo
	end
	if rng:NextNumber() > chance then
		return capsuleInfo
	end
	local quality = tonumber(capsuleInfo.Quality) or 0
	local rarityTable = capsuleByQualityRarity[quality]
	if not rarityTable then
		return capsuleInfo
	end
	return rarityTable[rarity + 1] or capsuleInfo
end

local function pickRandomCapsule(poolId)
	local pool = CapsuleSpawnPoolConfig.GetPool(poolId)
	if not pool then
		warn(string.format("[ConveyorService] Spawn pool not found: %s", tostring(poolId)))
		return nil
	end

	local entry = pickWeightedEntry(pool)
	if not entry then
		return nil
	end

	local capsuleInfo = getCapsuleInfo(entry.CapsuleId)
	if not capsuleInfo then
		warn(string.format("[ConveyorService] Capsule config missing: %s", tostring(entry.CapsuleId)))
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
			model:Destroy()
		end
	end)
end

function ConveyorService:StartForPlayer(player, homeSlot)
	local homeFolder = homeSlot and homeSlot.Folder
	if not homeFolder then
		warn("[ConveyorService] homeFolder is nil")
		return
	end

	local conveyorFolder = homeFolder:FindFirstChild("ConveyorBelt")
	if not conveyorFolder then
		warn("[ConveyorService] ConveyorBelt not found")
		return
	end

	local startMarker = conveyorFolder:FindFirstChild("Start", true)
	local endMarker = conveyorFolder:FindFirstChild("End", true)
	if not startMarker or not endMarker then
		warn(string.format("[ConveyorService] Start/End not found: Start=%s, End=%s", tostring(startMarker), tostring(endMarker)))
		return
	end

	local startCFrame = resolveCFrame(startMarker)
	local endCFrame = resolveCFrame(endMarker)
	if not startCFrame or not endCFrame then
		warn("[ConveyorService] Start/End must be BasePart/Attachment/Model")
		return
	end

	local capsuleFolder = getCapsuleFolder(conveyorFolder)
	refreshCapsuleBillboards(capsuleFolder, player.UserId)

	local state = { Active = true }
	running[player.UserId] = state

	task.spawn(function()
		while state.Active and player.Parent do
			local poolId = getUnlockedPoolId(player:GetAttribute("OutputSpeed"))
			local baseCapsuleInfo = pickRandomCapsule(poolId)
			local capsuleInfo = applyRarityMutation(baseCapsuleInfo)
			if capsuleInfo then
				capsuleInfo = applyExtraMutation(player, capsuleInfo)
			end
			if capsuleInfo then
				local model = EggService:CreateConveyorCapsule(capsuleInfo, player.UserId)
				if model then
					model.Parent = capsuleFolder
					moveCapsule(model, startCFrame, endCFrame)
				else
					warn(string.format("[ConveyorService] CreateConveyorCapsule returned nil for: %s", capsuleInfo.Name))
				end
			else
				warn("[ConveyorService] pickRandomCapsule returned nil")
			end
			task.wait(GameConfig.ConveyorSpawnInterval)
		end
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
