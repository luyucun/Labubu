--[[
脚本名称: StarterPackService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/StarterPackService
版本: V1.0
职责: 新手礼包通行证购买与奖励发放
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local CapsuleConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CapsuleConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EggService = require(script.Parent:WaitForChild("EggService"))

local StarterPackService = {}
StarterPackService.__index = StarterPackService

local PURCHASE_COOLDOWN = 0.5
local purchaseCooldowns = {}

local STARTER_PACK_REWARDS = {
	{ Id = 1003, Count = 2 },
	{ Id = 1004, Count = 2 },
	{ Id = 1005, Count = 2 },
}

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

local requestStarterPackPurchaseEvent = ensureRemoteEvent("RequestStarterPackPurchase")
local pushStarterPackStateEvent = ensureRemoteEvent("PushStarterPackState")
local pushStarterPackRewardEvent = ensureRemoteEvent("PushStarterPackReward")

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

local function ownsStarterPack(player)
	local passId = tonumber(GameConfig.StarterPackPassId)
	if not passId or passId <= 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and owns == true
end

function StarterPackService:PushState(player)
	if not pushStarterPackStateEvent or not player or not player.Parent then
		return
	end
	pushStarterPackStateEvent:FireClient(player, {
		Purchased = DataService:HasStarterPackPurchased(player),
	})
end

function StarterPackService:GrantStarterPack(player)
	if not player or not player.Parent then
		return false
	end
	if DataService:HasStarterPackPurchased(player) then
		return false
	end

	DataService:SetStarterPackPurchased(player, true)

	local rewards = {}
	for _, reward in ipairs(STARTER_PACK_REWARDS) do
		local capsuleId = tonumber(reward.Id)
		local count = tonumber(reward.Count) or 0
		if capsuleId and count > 0 then
			local info = getCapsuleInfo(capsuleId)
			for _ = 1, count do
				DataService:AddEgg(player, capsuleId)
				if info then
					EggService:GiveCapsuleTool(player, info)
				end
			end
			table.insert(rewards, { Id = capsuleId, Count = count })
		end
	end

	self:PushState(player)
	if pushStarterPackRewardEvent then
		pushStarterPackRewardEvent:FireClient(player, rewards)
	end
	return true
end

function StarterPackService:Init()
	if requestStarterPackPurchaseEvent then
		requestStarterPackPurchaseEvent.OnServerEvent:Connect(function(player)
			if not player or not player.Parent then
				return
			end
			if DataService:HasStarterPackPurchased(player) then
				self:PushState(player)
				return
			end
			if ownsStarterPack(player) then
				self:GrantStarterPack(player)
				return
			end
			local now = os.clock()
			local last = purchaseCooldowns[player.UserId] or 0
			if now - last < PURCHASE_COOLDOWN then
				return
			end
			purchaseCooldowns[player.UserId] = now
			local passId = tonumber(GameConfig.StarterPackPassId)
			if not passId or passId <= 0 then
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, passId)
		end)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if passId ~= GameConfig.StarterPackPassId then
			return
		end
		if not purchased then
			return
		end
		self:GrantStarterPack(player)
	end)
end

function StarterPackService:BindPlayer(player)
	if not player or not player.Parent then
		return
	end
	if DataService:HasStarterPackPurchased(player) then
		self:PushState(player)
		return
	end
	if ownsStarterPack(player) then
		self:GrantStarterPack(player)
		return
	end
	self:PushState(player)
end

function StarterPackService:UnbindPlayer(player)
	purchaseCooldowns[player.UserId] = nil
end

return StarterPackService
