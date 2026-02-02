--[[
脚本名称: PotionService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/PotionService
版本: V1.0
职责: 药水购买/使用/倒计时同步与产速加成更新
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PotionConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PotionConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local PotionService = {}
PotionService.__index = PotionService

local playerStates = {} -- [userId] = {Active, LoopStarted}
local purchaseCooldowns = {}
local actionCooldowns = {}
local PURCHASE_COOLDOWN = 0.5
local ACTION_COOLDOWN = 0.2

local productToPotionId = {}
for _, info in ipairs(PotionConfig.GetAll()) do
	if info and info.ProductId and info.Id then
		productToPotionId[tonumber(info.ProductId)] = info.Id
	end
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

local function ensureErrorHintEvent()
	return ensureRemoteEvent("ErrorHint")
end

local requestPotionPurchaseEvent = ensureRemoteEvent("RequestPotionPurchase")
local requestPotionActionEvent = ensureRemoteEvent("RequestPotionAction")
local pushPotionStateEvent = ensureRemoteEvent("PushPotionState")
local errorHintEvent = ensureErrorHintEvent()

local function sendErrorHint(player, code, message)
	if not player or not player.Parent or not errorHintEvent then
		return
	end
	errorHintEvent:FireClient(player, code, message)
end

local function getPlayerState(player)
	local state = playerStates[player.UserId]
	if state then
		return state
	end
	state = {
		Active = true,
		LoopStarted = false,
	}
	playerStates[player.UserId] = state
	return state
end

local function hasActivePotion(player, now)
	if not player then
		return false
	end
	local timestamp = now or os.time()
	for _, info in ipairs(PotionConfig.GetAll()) do
		if info and info.Id then
			if DataService:GetPotionEndTime(player, info.Id) > timestamp then
				return true
			end
		end
	end
	return false
end

function PotionService:PushState(player)
	if not pushPotionStateEvent or not player or not player.Parent then
		return
	end
	local counts = DataService:GetPotionCounts(player) or {}
	local endTimes = DataService:GetPotionEndTimes(player) or {}
	pushPotionStateEvent:FireClient(player, {
		Counts = counts,
		EndTimes = endTimes,
		ServerTime = os.time(),
	})
end

function PotionService:HandleDevPurchaseRequest(player, potionId)
	if not player or not player.Parent then
		return
	end
	local now = os.clock()
	local last = purchaseCooldowns[player.UserId] or 0
	if now - last < PURCHASE_COOLDOWN then
		return
	end
	purchaseCooldowns[player.UserId] = now

	local info = PotionConfig.GetById(potionId)
	if not info then
		return
	end
	local productId = tonumber(info.ProductId)
	if not productId or productId <= 0 then
		return
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

function PotionService:HandleActionRequest(player, potionId, action)
	if not player or not player.Parent then
		return
	end
	local now = os.clock()
	local last = actionCooldowns[player.UserId] or 0
	if now - last < ACTION_COOLDOWN then
		return
	end
	actionCooldowns[player.UserId] = now

	local info = PotionConfig.GetById(potionId)
	if not info then
		return
	end

	if action == "Buy" then
		local price = tonumber(info.DiamondPrice) or 0
		if price <= 0 then
			return
		end
		local diamonds = DataService:GetDiamonds(player)
		if diamonds < price then
			sendErrorHint(player, "DiamondNotEnough", "Diamond Not Enough!")
			return
		end
		DataService:AddDiamonds(player, -price)
		DataService:AddPotionCount(player, info.Id, 1)
		self:PushState(player)
		return
	end

	if action == "Use" then
		local count = DataService:GetPotionCount(player, info.Id)
		if count <= 0 then
			return
		end
		DataService:AddPotionCount(player, info.Id, -1)
		local durationSeconds = (tonumber(info.DurationMinutes) or 0) * 60
		if durationSeconds > 0 then
			DataService:ApplyPotionDuration(player, info.Id, durationSeconds)
		end
		self:PushState(player)
	end
end

function PotionService:HandleReceipt(player, productId)
	local potionId = productId and productToPotionId[tonumber(productId)] or nil
	if not potionId or not player then
		return false
	end
	DataService:AddPotionCount(player, potionId, 1)
	self:PushState(player)
	return true
end

function PotionService:StartPotionLoop(player)
	local state = getPlayerState(player)
	if state.LoopStarted then
		return
	end
	state.LoopStarted = true
	state.Active = true
	task.spawn(function()
		while state.Active and player.Parent do
			local now = os.time()
			if DataService:ClearExpiredPotions(player, now) then
				self:PushState(player)
			end
			local delaySeconds = hasActivePotion(player, now) and 1 or 2
			task.wait(delaySeconds)
		end
		state.LoopStarted = false
	end)
end

function PotionService:Init()
	if requestPotionPurchaseEvent then
		requestPotionPurchaseEvent.OnServerEvent:Connect(function(player, potionId)
			self:HandleDevPurchaseRequest(player, potionId)
		end)
	end
	if requestPotionActionEvent then
		requestPotionActionEvent.OnServerEvent:Connect(function(player, potionId, action)
			self:HandleActionRequest(player, potionId, action)
		end)
	end
end

function PotionService:BindPlayer(player)
	self:PushState(player)
	self:StartPotionLoop(player)
end

function PotionService:UnbindPlayer(player)
	local state = playerStates[player.UserId]
	if state then
		state.Active = false
	end
	playerStates[player.UserId] = nil
	purchaseCooldowns[player.UserId] = nil
	actionCooldowns[player.UserId] = nil
end

return PotionService
