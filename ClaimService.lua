--[[
脚本名称: ClaimService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/ClaimService
版本: V2.9
职责: 领取全部/十倍领取/自动领取付费功能
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local FormatHelper = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FormatHelper"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local FigurineService = require(script.Parent:WaitForChild("FigurineService"))
local EggService = require(script.Parent:WaitForChild("EggService"))

local ClaimService = {}
ClaimService.__index = ClaimService

local playerStates = {}
local CLAIM_COOLDOWN = 0.5
local LABEL_UPDATE_INTERVAL = 1
local AUTO_COLLECT_INTERVAL = GameConfig.AutoCollectInterval or 1
local DOT_INTERVAL = GameConfig.AutoCollectDotInterval or 0.7
local DISABLED_FOLDER_NAME = "MonetizationDisabled"
local CLAIM_EFFECT_DEFAULT_COUNT = 25
local CLAIM_EFFECT_FOLDER_NAME = "Effect"
local CLAIM_EFFECT_TEMPLATE_NAME = "EffectTouchMoney"
local coinPurchaseRequests = {} -- [userId] = { [productId] = speed }
local coinPurchaseCooldowns = {}
local COIN_PURCHASE_COOLDOWN = 0.5
local multiplierPurchaseRequests = {} -- [userId] = { ProductId = number, Multiplier = number }
local multiplierPurchaseCooldowns = {}
local MULTIPLIER_PURCHASE_COOLDOWN = 0.5

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

local function ensurePlaySfxEvent()
	local labubuEvents = ensureLabubuEvents()
	local event = labubuEvents:FindFirstChild("PlaySfx")
	if event and not event:IsA("RemoteEvent") then
		event:Destroy()
		event = nil
	end
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "PlaySfx"
		event.Parent = labubuEvents
	end
	return event
end

local playSfxEvent = ensurePlaySfxEvent()

local function buildCoinAddProductMap()
	local map = {}
	local list = GameConfig.CoinAddProducts
	if type(list) ~= "table" then
		return map
	end
	for _, entry in ipairs(list) do
		if type(entry) == "table" then
			local productId = tonumber(entry.ProductId)
			local seconds = tonumber(entry.Seconds)
			if productId and seconds and seconds > 0 then
				map[productId] = {
					Seconds = seconds,
					ButtonName = entry.ButtonName,
				}
			end
		end
	end
	return map
end

local COIN_ADD_PRODUCTS = buildCoinAddProductMap()

local function ensureCoinPurchaseEvent()
	local labubuEvents = ensureLabubuEvents()
	local event = labubuEvents:FindFirstChild("RequestCoinPurchase")
	if event and not event:IsA("RemoteEvent") then
		event:Destroy()
		event = nil
	end
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "RequestCoinPurchase"
		event.Parent = labubuEvents
	end
	return event
end

local coinPurchaseEvent = ensureCoinPurchaseEvent()

local function buildMultiplierProducts()
	local list = GameConfig.OutputMultiplierProducts
	if type(list) ~= "table" then
		return {}, {}
	end
	local products = {}
	local byProductId = {}
	for _, entry in ipairs(list) do
		if type(entry) == "table" then
			local multiplier = tonumber(entry.Multiplier)
			local productId = tonumber(entry.ProductId)
			local price = tonumber(entry.Price)
			if multiplier and productId and price then
				local info = {
					Multiplier = multiplier,
					ProductId = productId,
					Price = price,
				}
				table.insert(products, info)
				byProductId[productId] = info
			end
		end
	end
	table.sort(products, function(a, b)
		return a.Multiplier < b.Multiplier
	end)
	return products, byProductId
end

local MULTIPLIER_PRODUCTS, MULTIPLIER_BY_PRODUCT = buildMultiplierProducts()

local function getNextMultiplierEntry(currentMultiplier)
	for _, entry in ipairs(MULTIPLIER_PRODUCTS) do
		if entry.Multiplier > currentMultiplier then
			return entry
		end
	end
	return nil
end

local function ensureOutputMultiplierEvent()
	local labubuEvents = ensureLabubuEvents()
	local event = labubuEvents:FindFirstChild("RequestOutputMultiplierPurchase")
	if event and not event:IsA("RemoteEvent") then
		event:Destroy()
		event = nil
	end
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "RequestOutputMultiplierPurchase"
		event.Parent = labubuEvents
	end
	return event
end

local outputMultiplierEvent = ensureOutputMultiplierEvent()

local function fireCollectSfx(player)
	if not playSfxEvent or not player or not player.Parent then
		return
	end
	playSfxEvent:FireClient(player, "Collect")
end

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

local function resolveNodeByPath(root, path)
	if not root or type(path) ~= "string" or path == "" then
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
	return current
end

local cachedClaimEffect

local function resolveClaimEffectTemplate()
	if cachedClaimEffect and cachedClaimEffect.Parent then
		return cachedClaimEffect
	end
	local function findIn(container)
		if not container then
			return nil
		end
		local folder = container:FindFirstChild(CLAIM_EFFECT_FOLDER_NAME)
		if folder then
			local template = folder:FindFirstChild(CLAIM_EFFECT_TEMPLATE_NAME)
			if template then
				return template
			end
		end
		return container:FindFirstChild(CLAIM_EFFECT_TEMPLATE_NAME)
	end
	cachedClaimEffect = findIn(ServerStorage) or findIn(ReplicatedStorage)
	return cachedClaimEffect
end

local function cloneEffectChildren(template, targetParent)
	if not template or not targetParent then
		return nil
	end
	local clones = {}
	local children = template:GetChildren()
	if #children == 0 then
		local clone = template:Clone()
		clone.Parent = targetParent
		table.insert(clones, clone)
		return clones
	end
	for _, child in ipairs(children) do
		local clone = child:Clone()
		clone.Parent = targetParent
		table.insert(clones, clone)
	end
	return clones
end

local function collectEmittersFromInstances(instances)
	if not instances then
		return nil
	end
	local emitters = {}
	for _, obj in ipairs(instances) do
		if obj:IsA("ParticleEmitter") then
			table.insert(emitters, obj)
		end
		for _, child in ipairs(obj:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				table.insert(emitters, child)
			end
		end
	end
	if #emitters == 0 then
		return nil
	end
	return emitters
end

local function emitBurst(emitters)
	if not emitters then
		return
	end
	for _, emitter in ipairs(emitters) do
		if emitter and emitter.Parent then
			local count = tonumber(emitter:GetAttribute("BurstCount")) or CLAIM_EFFECT_DEFAULT_COUNT
			if count > 0 then
				emitter:Emit(count)
			end
		end
	end
end

local function enableEmitters(emitters)
	if not emitters then
		return nil
	end
	local burstOnly = {}
	for _, emitter in ipairs(emitters) do
		if emitter then
			emitter.Enabled = true
			if emitter.Rate <= 0 then
				table.insert(burstOnly, emitter)
			end
		end
	end
	if #burstOnly == 0 then
		return nil
	end
	return burstOnly
end

local function getPlayerFromHit(hit)
	if not hit then
		return nil
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function getPlayerState(player)
	local state = playerStates[player.UserId]
	if not state then
		state = {
			Player = player,
			Active = true,
			Connections = {},
			TouchStates = {},
			LabelLoopStarted = false,
			AutoLoopStarted = false,
			DotsToken = 0,
			AutoEffectToken = 0,
			AutoEffectInstances = nil,
			AutoEffectBurstEmitters = nil,
		}
		playerStates[player.UserId] = state
	end
	return state
end

local function getCoinAddInfo(productId)
	local normalized = tonumber(productId) or productId
	return COIN_ADD_PRODUCTS[normalized]
end

local function pushCoinPurchaseRequest(player, productId, speed)
	if not player then
		return
	end
	local userId = player.UserId
	local userRequests = coinPurchaseRequests[userId]
	if not userRequests then
		userRequests = {}
		coinPurchaseRequests[userId] = userRequests
	end
	userRequests[productId] = speed
end

local function popCoinPurchaseRequest(player, productId)
	if not player then
		return nil
	end
	local userRequests = coinPurchaseRequests[player.UserId]
	if not userRequests then
		return nil
	end
	local speed = userRequests[productId]
	userRequests[productId] = nil
	if next(userRequests) == nil then
		coinPurchaseRequests[player.UserId] = nil
	end
	return speed
end

local function setMultiplierPurchaseRequest(player, entry)
	if not player or not entry then
		return
	end
	multiplierPurchaseRequests[player.UserId] = {
		ProductId = entry.ProductId,
		Multiplier = entry.Multiplier,
	}
end

local function popMultiplierPurchaseRequest(player, productId)
	if not player then
		return nil
	end
	local pending = multiplierPurchaseRequests[player.UserId]
	if not pending then
		return nil
	end
	if productId and pending.ProductId ~= productId then
		return nil
	end
	multiplierPurchaseRequests[player.UserId] = nil
	return pending
end

local function getDisabledRoot()
	local root = ServerStorage:FindFirstChild(DISABLED_FOLDER_NAME)
	if not root then
		root = Instance.new("Folder")
		root.Name = DISABLED_FOLDER_NAME
		root.Parent = ServerStorage
	end
	return root
end

local function getDisabledFolder(homeFolder)
	if not homeFolder then
		return nil
	end
	local root = getDisabledRoot()
	local folder = root:FindFirstChild(homeFolder.Name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = homeFolder.Name
		folder.Parent = root
	end
	return folder
end

local function resolveNodes(state)
	local player = state.Player
	local homeFolder = getHomeFolder(player)
	state.HomeFolder = homeFolder
	if not homeFolder then
		return
	end

	local base = homeFolder:FindFirstChild("Base")
	state.Base = base

	local disabled = getDisabledFolder(homeFolder)
	state.DisabledFolder = disabled

	state.ClaimAll = base and base:FindFirstChild("ClaimAll") or (disabled and disabled:FindFirstChild("ClaimAll"))
	state.ClaimAllTen = base and base:FindFirstChild("ClaimAllTen") or (disabled and disabled:FindFirstChild("ClaimAllTen"))
	state.Auto = base and base:FindFirstChild("Auto")

	if state.ClaimAll then
		state.ClaimAllTouch = state.ClaimAll:FindFirstChild("Touch", true)
		state.ClaimAllCash = state.ClaimAll:FindFirstChild("CashNum", true)
	end

	if state.ClaimAllTen then
		state.ClaimAllTenTouch = state.ClaimAllTen:FindFirstChild("Touch", true)
		state.ClaimAllTenCash = state.ClaimAllTen:FindFirstChild("CashNum", true)
	end

	state.AutoTouch = resolveNodeByPath(homeFolder, "Base/Auto/Touch")
	state.AutoInactive = resolveNodeByPath(homeFolder, "Base/Auto/AutoCollect/Inactive")
	state.AutoActive = resolveNodeByPath(homeFolder, "Base/Auto/AutoCollect/Active")
	state.AutoCollectingLabel = resolveNodeByPath(homeFolder, "Base/Auto/AutoCollect/Active/Collecting")
end

local function updateClaimLabels(state)
	local player = state.Player
	if not player or not player.Parent then
		return
	end
	local total = FigurineService:GetTotalPendingCoins(player)
	local text = FormatHelper.FormatCoinsShort(total, true)
	if state.ClaimAllCash and state.ClaimAllCash:IsA("TextLabel") then
		state.ClaimAllCash.Text = text
	end
	if state.ClaimAllTenCash and state.ClaimAllTenCash:IsA("TextLabel") then
		local tenText = FormatHelper.FormatCoinsShort(total * 10, true)
		state.ClaimAllTenCash.Text = tenText
	end
end

local function startLabelLoop(state)
	if state.LabelLoopStarted then
		return
	end
	state.LabelLoopStarted = true

	task.spawn(function()
		while state.Active and state.Player.Parent do
			updateClaimLabels(state)
			task.wait(LABEL_UPDATE_INTERVAL)
		end
		state.LabelLoopStarted = false
	end)
end

local function stopCollectingDots(state)
	state.DotsToken += 1
end

local function stopAutoEffectLoop(state)
	state.AutoEffectToken += 1
end

local function startAutoEffectLoop(state)
	local emitters = state.AutoEffectBurstEmitters
	if not emitters then
		return
	end
	stopAutoEffectLoop(state)
	local token = state.AutoEffectToken
	task.spawn(function()
		while state.Active and token == state.AutoEffectToken do
			emitBurst(emitters)
			task.wait(AUTO_COLLECT_INTERVAL)
		end
	end)
end

local function startCollectingDots(state)
	stopCollectingDots(state)
	if not state.AutoCollectingLabel or not state.AutoCollectingLabel:IsA("TextLabel") then
		return
	end
	state.AutoCollectingLabel.Text = "Collecting"
	local token = state.DotsToken
	task.spawn(function()
		local dotCount = 0
		while state.Active and token == state.DotsToken and state.AutoCollectingLabel and state.AutoCollectingLabel.Parent do
			dotCount = (dotCount % 3) + 1
			state.AutoCollectingLabel.Text = "Collecting" .. string.rep(".", dotCount)
			task.wait(DOT_INTERVAL)
		end
	end)
end

local function removeAutoCollectEffect(state)
	stopAutoEffectLoop(state)
	if state.AutoEffectInstances then
		for _, inst in ipairs(state.AutoEffectInstances) do
			if inst and inst.Parent then
				inst:Destroy()
			end
		end
	end
	state.AutoEffectInstances = nil
	state.AutoEffectBurstEmitters = nil
end

local function attachAutoCollectEffect(state)
	if state.AutoEffectInstances then
		return
	end
	if not state.AutoTouch or not state.AutoTouch:IsA("BasePart") then
		return
	end
	local template = resolveClaimEffectTemplate()
	if not template then
		return
	end
	local clones = cloneEffectChildren(template, state.AutoTouch)
	if not clones or #clones == 0 then
		return
	end
	local emitters = collectEmittersFromInstances(clones)
	state.AutoEffectInstances = clones
	state.AutoEffectBurstEmitters = enableEmitters(emitters)
	emitBurst(state.AutoEffectBurstEmitters)
	startAutoEffectLoop(state)
end

local function startAutoCollectLoop(state)
	if state.AutoLoopStarted then
		return
	end
	state.AutoLoopStarted = true
	task.spawn(function()
		while state.Active and state.Player.Parent and DataService:HasAutoCollect(state.Player) do
			FigurineService:CollectAllCoins(state.Player, 1)
			task.wait(AUTO_COLLECT_INTERVAL)
		end
		state.AutoLoopStarted = false
	end)
end

local function bindTouch(state, part, onTrigger)
	if not part or not part:IsA("BasePart") then
		return
	end
	if state.Connections[part] then
		return
	end

	local touchState = {
		IsTouching = false,
		LastTrigger = 0,
		TouchingParts = {},
	}
	state.TouchStates[part] = touchState

	local function onTouched(hit)
		local hitPlayer = getPlayerFromHit(hit)
		if hitPlayer ~= state.Player then
			return
		end
		if hit and not touchState.TouchingParts[hit] then
			touchState.TouchingParts[hit] = true
		end
		if touchState.IsTouching then
			return
		end
		local now = os.clock()
		if now - touchState.LastTrigger < CLAIM_COOLDOWN then
			touchState.IsTouching = true
			return
		end
		touchState.IsTouching = true
		touchState.LastTrigger = now
		onTrigger()
	end

	local function onTouchEnded(hit)
		local hitPlayer = getPlayerFromHit(hit)
		if hitPlayer ~= state.Player then
			return
		end
		if hit then
			touchState.TouchingParts[hit] = nil
		end
		if next(touchState.TouchingParts) == nil then
			touchState.IsTouching = false
		end
	end

	local connTouched = part.Touched:Connect(onTouched)
	local connEnded = part.TouchEnded:Connect(onTouchEnded)
	state.Connections[part] = { connTouched, connEnded }
end

local function ensureGamePassOwnership(player)
	if DataService:HasAutoCollect(player) then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GameConfig.AutoCollectPassId)
	end)
	if ok and owns then
		DataService:SetAutoCollect(player, true)
	end
end

function ClaimService:ApplyAutoCollectState(player, enabled)
	local state = getPlayerState(player)
	resolveNodes(state)

	local homeFolder = state.HomeFolder
	local base = state.Base
	if homeFolder then
		local disabled = getDisabledFolder(homeFolder)
		state.DisabledFolder = disabled
		if enabled then
			if state.ClaimAll and state.ClaimAll.Parent ~= disabled then
				state.ClaimAll.Parent = disabled
			end
			if state.ClaimAllTen and state.ClaimAllTen.Parent ~= disabled then
				state.ClaimAllTen.Parent = disabled
			end
		else
			if state.ClaimAll and base and state.ClaimAll.Parent ~= base then
				state.ClaimAll.Parent = base
			end
			if state.ClaimAllTen and base and state.ClaimAllTen.Parent ~= base then
				state.ClaimAllTen.Parent = base
			end
		end
	end

	if state.AutoInactive and state.AutoInactive:IsA("GuiObject") then
		state.AutoInactive.Visible = not enabled
	end
	if state.AutoActive and state.AutoActive:IsA("GuiObject") then
		state.AutoActive.Visible = enabled
	end

	if enabled then
		startCollectingDots(state)
		startAutoCollectLoop(state)
		attachAutoCollectEffect(state)
	else
		stopCollectingDots(state)
		removeAutoCollectEffect(state)
	end
end

function ClaimService:Init()
	if coinPurchaseEvent then
		coinPurchaseEvent.OnServerEvent:Connect(function(player, productId)
			if not player or not player.Parent then
				return
			end
			local normalizedProductId = tonumber(productId)
			if not normalizedProductId then
				return
			end
			if not getCoinAddInfo(normalizedProductId) then
				return
			end
			local now = os.clock()
			local last = coinPurchaseCooldowns[player.UserId] or 0
			if now - last < COIN_PURCHASE_COOLDOWN then
				return
			end
			coinPurchaseCooldowns[player.UserId] = now
			local speed = tonumber(player:GetAttribute("OutputSpeed")) or 0
			if speed < 0 then
				speed = 0
			end
			local minSpeed = tonumber(GameConfig.CoinAddMinOutputSpeed) or 20
			if speed < minSpeed then
				return
			end
			pushCoinPurchaseRequest(player, normalizedProductId, speed)
			MarketplaceService:PromptProductPurchase(player, normalizedProductId)
		end)
	end

	if outputMultiplierEvent then
		outputMultiplierEvent.OnServerEvent:Connect(function(player)
			if not player or not player.Parent then
				return
			end
			if #MULTIPLIER_PRODUCTS == 0 then
				return
			end
			local now = os.clock()
			local last = multiplierPurchaseCooldowns[player.UserId] or 0
			if now - last < MULTIPLIER_PURCHASE_COOLDOWN then
				return
			end
			multiplierPurchaseCooldowns[player.UserId] = now
			local currentMultiplier = DataService:GetOutputMultiplier(player)
			local nextEntry = getNextMultiplierEntry(currentMultiplier)
			if not nextEntry then
				return
			end
			setMultiplierPurchaseRequest(player, nextEntry)
			MarketplaceService:PromptProductPurchase(player, nextEntry.ProductId)
		end)
	end

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		if receiptInfo.ProductId == GameConfig.ClaimAllProductId then
			local grant = FigurineService:CollectAllCoins(player, 1)
			if grant > 0 then
				fireCollectSfx(player)
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		if receiptInfo.ProductId == GameConfig.ClaimAllTenProductId then
			local grant = FigurineService:CollectAllCoins(player, 10)
			if grant > 0 then
				fireCollectSfx(player)
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local productId = tonumber(receiptInfo.ProductId)
		local coinAddInfo = productId and getCoinAddInfo(productId) or nil
		if coinAddInfo then
			local speed = popCoinPurchaseRequest(player, productId)
			if speed == nil then
				speed = tonumber(player:GetAttribute("OutputSpeed")) or 0
			end
			if speed < 0 then
				speed = 0
			end
			local seconds = tonumber(coinAddInfo.Seconds) or 0
			local coins = speed * seconds
			if coins < 0 then
				coins = 0
			end
			coins = math.ceil(coins - 1e-9)
			if coins > 0 then
				DataService:AddCoins(player, coins)
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local multiplierEntry = productId and MULTIPLIER_BY_PRODUCT[productId] or nil
		if multiplierEntry then
			local pending = popMultiplierPurchaseRequest(player, productId)
			if pending and pending.ProductId == productId then
				local currentMultiplier = DataService:GetOutputMultiplier(player)
				local expected = getNextMultiplierEntry(currentMultiplier)
				if expected and expected.ProductId == productId and pending.Multiplier > currentMultiplier then
					DataService:SetOutputMultiplier(player, pending.Multiplier)
				end
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
			local currentMultiplier = DataService:GetOutputMultiplier(player)
			local expected = getNextMultiplierEntry(currentMultiplier)
			if expected and expected.ProductId == productId then
				DataService:SetOutputMultiplier(player, expected.Multiplier)
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		if EggService:HandlePaidOpenReceipt(player, receiptInfo.ProductId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if passId ~= GameConfig.AutoCollectPassId then
			return
		end
		if not purchased then
			return
		end
		DataService:SetAutoCollect(player, true)
		self:ApplyAutoCollectState(player, true)
	end)
end

function ClaimService:BindPlayer(player)
	local state = getPlayerState(player)
	state.Active = true

	resolveNodes(state)
	ensureGamePassOwnership(player)

	if state.ClaimAllTouch then
		bindTouch(state, state.ClaimAllTouch, function()
			if DataService:HasAutoCollect(player) then
				return
			end
			MarketplaceService:PromptProductPurchase(player, GameConfig.ClaimAllProductId)
		end)
	end

	if state.ClaimAllTenTouch then
		bindTouch(state, state.ClaimAllTenTouch, function()
			if DataService:HasAutoCollect(player) then
				return
			end
			MarketplaceService:PromptProductPurchase(player, GameConfig.ClaimAllTenProductId)
		end)
	end

	if state.AutoTouch then
		bindTouch(state, state.AutoTouch, function()
			if DataService:HasAutoCollect(player) then
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, GameConfig.AutoCollectPassId)
		end)
	end

	local enabled = DataService:HasAutoCollect(player)
	self:ApplyAutoCollectState(player, enabled)
	startLabelLoop(state)
	updateClaimLabels(state)
end

function ClaimService:UnbindPlayer(player)
	local state = playerStates[player.UserId]
	if not state then
		return
	end
	state.Active = false
	stopCollectingDots(state)
	removeAutoCollectEffect(state)
	for _, conns in pairs(state.Connections) do
		for _, conn in ipairs(conns) do
			conn:Disconnect()
		end
	end
	playerStates[player.UserId] = nil
	coinPurchaseRequests[player.UserId] = nil
	coinPurchaseCooldowns[player.UserId] = nil
	multiplierPurchaseRequests[player.UserId] = nil
	multiplierPurchaseCooldowns[player.UserId] = nil
end

return ClaimService
