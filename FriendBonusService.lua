--[[
脚本名称: FriendBonusService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/FriendBonusService
版本: V1.0
职责: 同服好友加成统计与产出加成同步
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local FigurineConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FigurineConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local FriendBonusService = {}
FriendBonusService.__index = FriendBonusService

local BONUS_PER_FRIEND = 0.1

local function toNumber(value, defaultValue)
	local num = tonumber(value)
	if not num then
		return defaultValue
	end
	return num
end

local function getBonusFactorFromCount(count)
	local finalCount = math.max(0, toNumber(count, 0))
	return 1 + finalCount * BONUS_PER_FRIEND
end

local function safeIsFriend(player, otherUserId)
	if not player or not otherUserId then
		return false
	end
	local ok, result = pcall(function()
		return player:IsFriendsWith(otherUserId)
	end)
	return ok and result == true
end

local function computeFriendCounts(players)
	local counts = {}
	for _, player in ipairs(players) do
		counts[player] = 0
	end
	for i = 1, #players - 1 do
		local playerA = players[i]
		for j = i + 1, #players do
			local playerB = players[j]
			if safeIsFriend(playerA, playerB.UserId) then
				counts[playerA] += 1
				counts[playerB] += 1
			end
		end
	end
	return counts
end

local function adjustCollectTimesForBonusChange(player, oldFactor, newFactor)
	if not player or not player.Parent then
		return
	end
	if oldFactor == newFactor then
		return
	end
	local figurines = DataService:GetFigurines(player)
	if type(figurines) ~= "table" then
		return
	end
	local now = os.time()
	local capSeconds = toNumber(GameConfig.FigurineCoinCapSeconds, 0)
	for figurineId, owned in pairs(figurines) do
		if owned then
			local info = FigurineConfig.GetById(toNumber(figurineId, figurineId))
			if info then
				local state = DataService:EnsureFigurineState(player, figurineId)
				local lastCollect = toNumber(state and state.LastCollectTime, now)
				local elapsed = math.max(0, now - lastCollect)
				if capSeconds > 0 then
					elapsed = math.min(elapsed, capSeconds)
				end
				local baseRate = DataService:CalculateFigurineRate(info, state)
				if baseRate > 0 then
					local oldRate = baseRate * oldFactor
					local newRate = baseRate * newFactor
					if newRate > 0 then
						local pending = oldRate * elapsed
						local targetElapsed = pending / newRate
						if capSeconds > 0 then
							targetElapsed = math.min(targetElapsed, capSeconds)
						end
						local newLastCollect = now - targetElapsed
						DataService:SetFigurineLastCollectTime(player, figurineId, newLastCollect)
					end
				end
			end
		end
	end
end

local function applyFriendCount(player, newCount)
	if not player or not player.Parent then
		return
	end
	local oldCountAttr = player:GetAttribute("FriendBonusCount")
	local oldCount = toNumber(oldCountAttr, nil)
	local shouldAdjust = oldCount ~= nil and oldCount ~= newCount
	if shouldAdjust then
		adjustCollectTimesForBonusChange(player, getBonusFactorFromCount(oldCount), getBonusFactorFromCount(newCount))
	end
	player:SetAttribute("FriendBonusCount", newCount)
	player:SetAttribute("FriendBonusPercent", math.max(0, newCount) * 10)
end

function FriendBonusService:GetBonusFactor(player)
	if not player then
		return 1
	end
	return getBonusFactorFromCount(player:GetAttribute("FriendBonusCount"))
end

function FriendBonusService:RefreshAll()
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end
	local counts = computeFriendCounts(players)
	for _, player in ipairs(players) do
		applyFriendCount(player, counts[player] or 0)
	end
end

function FriendBonusService:Init()
	self:RefreshAll()
end

function FriendBonusService:HandlePlayerAdded()
	self:RefreshAll()
end

function FriendBonusService:HandlePlayerRemoving()
	task.delay(0.1, function()
		self:RefreshAll()
	end)
end

return FriendBonusService
