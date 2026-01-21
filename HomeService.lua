--[[
脚本名称: HomeService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/HomeService
版本: V1.9
职责: 家园分配与出生点绑定与基地玩家信息展示
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local FormatHelper = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FormatHelper"))

local HomeService = {}
HomeService.__index = HomeService

local homeSlots = {} -- [index] = {Folder, SpawnLocation, OwnerUserId}
local characterConnections = {} -- [userId] = RBXScriptConnection
local infoConnections = {} -- [userId] = RBXScriptConnection
local rng = Random.new()

local function formatHomeName(index)
	return string.format("%s%02d", GameConfig.HomeSlotPrefix, index)
end

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

local function ensureGoHomeEvent()
	local labubuEvents = ensureLabubuEvents()
	local event = labubuEvents:FindFirstChild("GoHome")
	if event and not event:IsA("RemoteEvent") then
		event:Destroy()
		event = nil
	end
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "GoHome"
		event.Parent = labubuEvents
	end
	return event
end

local goHomeEvent = ensureGoHomeEvent()
local goHomeBound = false

local function resolvePlayerInfoNodes(homeFolder)
	if not homeFolder then
		return nil
	end
	local base = homeFolder:FindFirstChild("Base")
	if not base then
		return nil
	end
	local playerInfo = base:FindFirstChild("PlayerInfo")
	if not playerInfo then
		return nil
	end
	local billboard = playerInfo:FindFirstChild("BillboardGui")
	if not billboard then
		return nil
	end
	local bg = billboard:FindFirstChild("Bg")
	if not bg or not bg:IsA("GuiObject") then
		return nil
	end
	local icon = bg:FindFirstChild("PlayerIcon")
	if icon and not icon:IsA("ImageLabel") then
		icon = nil
	end
	local nameLabel = bg:FindFirstChild("PlayerName")
	if nameLabel and not nameLabel:IsA("TextLabel") then
		nameLabel = nil
	end
	local speedLabel = bg:FindFirstChild("Speed")
	if speedLabel and not speedLabel:IsA("TextLabel") then
		speedLabel = nil
	end
	return bg, icon, nameLabel, speedLabel
end

local function resolveClaimAllCFrame(homeFolder)
	if not homeFolder then
		return nil
	end
	local base = homeFolder:FindFirstChild("Base")
	if not base then
		return nil
	end
	local claimAll = base:FindFirstChild("ClaimAll")
	if not claimAll then
		return nil
	end
	if claimAll:IsA("BasePart") then
		return claimAll.CFrame
	end
	if claimAll:IsA("Model") then
		return claimAll:GetPivot()
	end
	if claimAll:IsA("Attachment") then
		return claimAll.WorldCFrame
	end
	return nil
end

local function teleportToSlot(player, slot)
	if not player or not player.Parent then
		return
	end
	if not slot or not slot.SpawnLocation then
		return
	end
	if slot.OwnerUserId and slot.OwnerUserId ~= player.UserId then
		return
	end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	local spawnPos = slot.SpawnLocation.Position + Vector3.new(0, 3, 0)
	local claimAllCFrame = resolveClaimAllCFrame(slot.Folder)
	if claimAllCFrame then
		local targetPos = claimAllCFrame.Position
		local lookPos = Vector3.new(targetPos.X, spawnPos.Y, targetPos.Z)
		if (lookPos - spawnPos).Magnitude > 0.05 then
			rootPart.CFrame = CFrame.lookAt(spawnPos, lookPos)
			return
		end
	end
	rootPart.CFrame = slot.SpawnLocation.CFrame + Vector3.new(0, 3, 0)
end

local function updateSpeedLabel(player, speedLabel)
	if not speedLabel or not speedLabel.Parent then
		return
	end
	local speed = tonumber(player:GetAttribute("OutputSpeed")) or 0
	local speedText = FormatHelper.FormatCoinsShort(speed, true)
	speedLabel.Text = string.format("%s/S", speedText)
end

local function applyPlayerInfo(player, slot)
	if not slot or not slot.Folder then
		return
	end
	local bg, icon, nameLabel, speedLabel = resolvePlayerInfoNodes(slot.Folder)
	if not bg then
		warn(string.format("[HomeService] PlayerInfo missing: %s", tostring(slot.Folder.Name)))
		return
	end

	if nameLabel then
		nameLabel.Text = player.Name
	end
	if speedLabel then
		updateSpeedLabel(player, speedLabel)
	end
	if icon then
		icon.Image = ""
		task.spawn(function()
			local success, content = pcall(function()
				return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
			end)
			if not success then
				warn(string.format("[HomeService] GetUserThumbnailAsync failed: userId=%d err=%s", player.UserId, tostring(content)))
				return
			end
			if not icon.Parent then
				return
			end
			if slot.OwnerUserId ~= player.UserId then
				return
			end
			icon.Image = content
		end)
	end

	bg.Visible = true

	if infoConnections[player.UserId] then
		infoConnections[player.UserId]:Disconnect()
		infoConnections[player.UserId] = nil
	end
	if speedLabel then
		infoConnections[player.UserId] = player:GetAttributeChangedSignal("OutputSpeed"):Connect(function()
			updateSpeedLabel(player, speedLabel)
		end)
	end
end

local function clearPlayerInfo(slot)
	if not slot or not slot.Folder then
		return
	end
	local bg = resolvePlayerInfoNodes(slot.Folder)
	if bg then
		bg.Visible = false
	end
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
			clearPlayerInfo(homeSlots[i])
		else
			warn(string.format("HomeService missing folder: %s", formatHomeName(i)))
		end
	end

	if goHomeEvent and not goHomeBound then
		goHomeBound = true
		goHomeEvent.OnServerEvent:Connect(function(player)
			HomeService:TeleportHome(player)
		end)
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
	applyPlayerInfo(player, slot)
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
			local spawnPos = slot.SpawnLocation.Position + Vector3.new(0, 3, 0)
			local claimAllCFrame = resolveClaimAllCFrame(slot.Folder)
			if claimAllCFrame then
				local targetPos = claimAllCFrame.Position
				local lookPos = Vector3.new(targetPos.X, spawnPos.Y, targetPos.Z)
				if (lookPos - spawnPos).Magnitude > 0.05 then
					rootPart.CFrame = CFrame.lookAt(spawnPos, lookPos)
					return
				end
			end
			rootPart.CFrame = slot.SpawnLocation.CFrame + Vector3.new(0, 3, 0)
		end
	end)
end

function HomeService:TeleportHome(player)
	if not player or not player.Parent then
		return
	end
	local slotIndex = player:GetAttribute("HomeSlot")
	if not slotIndex then
		return
	end
	local slot = homeSlots[slotIndex]
	if not slot or not slot.SpawnLocation then
		return
	end
	if slot.OwnerUserId ~= player.UserId then
		return
	end
	teleportToSlot(player, slot)
end

function HomeService:ReleaseHome(player)
	local userId = player.UserId
	for index = 1, GameConfig.HomeSlotCount do
		local slot = homeSlots[index]
		if slot and slot.OwnerUserId == userId then
			clearPlayerInfo(slot)
			slot.OwnerUserId = nil
			setOwnerAttribute(slot, nil)
			break
		end
	end

	if characterConnections[userId] then
		characterConnections[userId]:Disconnect()
		characterConnections[userId] = nil
	end
	if infoConnections[userId] then
		infoConnections[userId]:Disconnect()
		infoConnections[userId] = nil
	end

	player.RespawnLocation = nil
	player:SetAttribute("HomeSlot", nil)
end

return HomeService
