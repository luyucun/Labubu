--[[
脚本名称: HomeService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/HomeService
版本: V1.1
职责: 家园分配与出生点绑定
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))

local HomeService = {}
HomeService.__index = HomeService

local homeSlots = {} -- [index] = {Folder, SpawnLocation, OwnerUserId}
local characterConnections = {} -- [userId] = RBXScriptConnection
local rng = Random.new()

local function formatHomeName(index)
	return string.format("%s%02d", GameConfig.HomeSlotPrefix, index)
end

function HomeService:Init()
	local homeRoot = Workspace:WaitForChild(GameConfig.HomeFolderName)
	for i = 1, GameConfig.HomeSlotCount do
		local folder = homeRoot:FindFirstChild(formatHomeName(i))
		if folder then
			local spawnLocation = folder:FindFirstChild("SpawnLocation")
			homeSlots[i] = {
				Folder = folder,
				SpawnLocation = spawnLocation,
				OwnerUserId = nil,
			}
		else
			warn(string.format("HomeService missing folder: %s", formatHomeName(i)))
		end
	end
end

local function setOwnerAttribute(slot, userId)
	if slot.Folder then
		slot.Folder:SetAttribute("OwnerUserId", userId)
	end
	if slot.SpawnLocation then
		slot.SpawnLocation:SetAttribute("OwnerUserId", userId)
	end
end

function HomeService:AssignHome(player)
	local available = {}
	for index = 1, GameConfig.HomeSlotCount do
		local slot = homeSlots[index]
		if slot and not slot.OwnerUserId then
			table.insert(available, index)
		end
	end

	if #available == 0 then
		return nil
	end

	local pickIndex = available[rng:NextInteger(1, #available)]
	local slot = homeSlots[pickIndex]
	slot.OwnerUserId = player.UserId
	setOwnerAttribute(slot, player.UserId)
	player:SetAttribute("HomeSlot", pickIndex)
	self:ApplySpawn(player, slot)
	print(string.format("[HomeService] Assign home: userId=%d slot=%s", player.UserId, formatHomeName(pickIndex)))
	return slot
end

function HomeService:ApplySpawn(player, slot)
	if not slot or not slot.SpawnLocation then
		return
	end

	player.RespawnLocation = slot.SpawnLocation

	if characterConnections[player.UserId] then
		characterConnections[player.UserId]:Disconnect()
	end

	characterConnections[player.UserId] = player.CharacterAdded:Connect(function(character)
		local rootPart = character:WaitForChild("HumanoidRootPart", 5)
		if rootPart then
			rootPart.CFrame = slot.SpawnLocation.CFrame + Vector3.new(0, 3, 0)
		end
	end)
end

function HomeService:ReleaseHome(player)
	local userId = player.UserId
	for index = 1, GameConfig.HomeSlotCount do
		local slot = homeSlots[index]
		if slot and slot.OwnerUserId == userId then
			slot.OwnerUserId = nil
			setOwnerAttribute(slot, nil)
			break
		end
	end

	if characterConnections[userId] then
		characterConnections[userId]:Disconnect()
		characterConnections[userId] = nil
	end

	player.RespawnLocation = nil
	player:SetAttribute("HomeSlot", nil)
end

return HomeService
