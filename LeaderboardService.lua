--[[
脚本名称: LeaderboardService
脚本类型: ModuleScript
脚本位置: ServerScriptService/Server/LeaderboardService
版本: V1.1
职责: 服务器内排行榜（总产速/总游戏时间）
]]

local LeaderboardService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FormatHelper = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FormatHelper"))

local connectionsByPlayer = {}

local function normalizeNumber(value)
	local num = tonumber(value)
	if not num or num < 0 then
		return 0
	end
	return num
end

local function ensureLeaderstats(player)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end

	local outputValue = folder:FindFirstChild("OutputSpeed")
	if not outputValue or not outputValue:IsA("StringValue") then
		if outputValue then
			outputValue:Destroy()
		end
		outputValue = Instance.new("StringValue")
		outputValue.Name = "OutputSpeed"
		outputValue.Parent = folder
	end

	local playtimeValue = folder:FindFirstChild("TotalPlayTime")
	if not playtimeValue or not playtimeValue:IsA("StringValue") then
		if playtimeValue then
			playtimeValue:Destroy()
		end
		playtimeValue = Instance.new("StringValue")
		playtimeValue.Name = "TotalPlayTime"
		playtimeValue.Parent = folder
	end

	return outputValue, playtimeValue
end

local function formatOutputSpeed(value)
	local speed = normalizeNumber(value)
	return string.format("%s/s", FormatHelper.FormatNumberShort(speed))
end

local function formatPlaytimeHours(value)
	local seconds = normalizeNumber(value)
	local hours = seconds / 3600
	local text = string.format("%.1f", hours)
	text = text:gsub("%.0$", "")
	return text .. "h"
end

local function setOutputSpeed(valueObject, value)
	if valueObject and valueObject:IsA("StringValue") then
		valueObject.Value = formatOutputSpeed(value)
	end
end

local function setTotalPlayTime(valueObject, value)
	if valueObject and valueObject:IsA("StringValue") then
		valueObject.Value = formatPlaytimeHours(value)
	end
end

function LeaderboardService:BindPlayer(player)
	if not player or not player.Parent then
		return
	end

	self:UnbindPlayer(player)

	local outputValue, playtimeValue = ensureLeaderstats(player)
	setOutputSpeed(outputValue, player:GetAttribute("OutputSpeed"))
	setTotalPlayTime(playtimeValue, player:GetAttribute("TotalPlayTime"))

	local connections = {}
	connections.OutputSpeed = player:GetAttributeChangedSignal("OutputSpeed"):Connect(function()
		setOutputSpeed(outputValue, player:GetAttribute("OutputSpeed"))
	end)
	connections.TotalPlayTime = player:GetAttributeChangedSignal("TotalPlayTime"):Connect(function()
		setTotalPlayTime(playtimeValue, player:GetAttribute("TotalPlayTime"))
	end)
	connectionsByPlayer[player] = connections
end

function LeaderboardService:UnbindPlayer(player)
	local connections = connectionsByPlayer[player]
	if not connections then
		return
	end
	for _, conn in pairs(connections) do
		conn:Disconnect()
	end
	connectionsByPlayer[player] = nil
end

return LeaderboardService
