--[[
脚本名称: GroupRewardService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/GroupRewardService
版本: V1.0
职责: 群组奖励领取与发放
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local CapsuleConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CapsuleConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EggService = require(script.Parent:WaitForChild("EggService"))

local GroupRewardService = {}
GroupRewardService.__index = GroupRewardService

local GROUP_ID = tonumber(GameConfig.GroupRewardGroupId) or 0
local REWARD_CAPSULE_ID = tonumber(GameConfig.GroupRewardCapsuleId) or 1003
local REWARD_COUNT = tonumber(GameConfig.GroupRewardCapsuleCount) or 5
local CLAIM_COOLDOWN = 0.6

local claimCooldowns = {}

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

local requestGroupRewardEvent = ensureRemoteEvent("RequestGroupReward")
local errorHintEvent = ensureRemoteEvent("ErrorHint")
local playSfxEvent = ensureRemoteEvent("PlaySfx")

local function getCapsuleInfo(capsuleId)
	if type(CapsuleConfig.GetById) == "function" then
		return CapsuleConfig.GetById(capsuleId)
	end
	local list = CapsuleConfig.Capsules
	if type(list) ~= "table" and type(CapsuleConfig) == "table" then
		list = CapsuleConfig
	end
	if type(list) ~= "table" then
		return nil
	end
	for _, info in ipairs(list) do
		if info.Id == capsuleId then
			return info
		end
	end
	return nil
end

local function sendErrorHint(player, code, message)
	if not errorHintEvent or not player or not player.Parent then
		return
	end
	errorHintEvent:FireClient(player, code, message)
end

local function playWarningSfx(player)
	if not playSfxEvent or not player or not player.Parent then
		return
	end
	playSfxEvent:FireClient(player, "Warning")
end

local function isOnCooldown(player)
	local now = os.clock()
	local last = claimCooldowns[player.UserId] or 0
	if now - last < CLAIM_COOLDOWN then
		return true
	end
	claimCooldowns[player.UserId] = now
	return false
end

local function isPlayerInGroup(player)
	if not player or not player.Parent then
		return false
	end
	if not GROUP_ID or GROUP_ID <= 0 then
		return false
	end
	local ok, result = pcall(function()
		return player:IsInGroup(GROUP_ID)
	end)
	return ok and result == true
end

function GroupRewardService:GrantReward(player)
	if not player or not player.Parent then
		return false
	end
	if not DataService:GetData(player) then
		return false
	end
	if DataService:HasGroupRewardClaimed(player) then
		return false
	end

	DataService:SetGroupRewardClaimed(player, true)

	local info = getCapsuleInfo(REWARD_CAPSULE_ID)
	local count = math.max(0, REWARD_COUNT)
	for _ = 1, count do
		DataService:AddEgg(player, REWARD_CAPSULE_ID)
		if info then
			EggService:GiveCapsuleTool(player, info)
		end
	end

	return true
end

function GroupRewardService:Init()
	if requestGroupRewardEvent then
		requestGroupRewardEvent.OnServerEvent:Connect(function(player)
			if not player or not player.Parent then
				return
			end
			if not DataService:GetData(player) then
				return
			end
			if isOnCooldown(player) then
				return
			end
			if DataService:HasGroupRewardClaimed(player) then
				return
			end
			if not isPlayerInGroup(player) then
				sendErrorHint(player, "GroupReward", "Join the group for rewards!")
				playWarningSfx(player)
				return
			end
			if self:GrantReward(player) then
				sendErrorHint(player, "GroupReward", "Claim Successful!")
			end
		end)
	end
end

function GroupRewardService:BindPlayer(player)
	if not player or not player.Parent then
		return
	end
	claimCooldowns[player.UserId] = nil
end

function GroupRewardService:UnbindPlayer(player)
	if not player then
		return
	end
	claimCooldowns[player.UserId] = nil
end

return GroupRewardService
