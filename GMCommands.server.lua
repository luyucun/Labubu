--[[
脚本名称: GMCommands
脚本类型: Script
脚本位置: ServerScriptService/Server/GMCommands
版本: V1.2
职责: GM命令管理（加金币/清金币/命令列表）
]]

local Players = game:GetService("Players")

local DataService = require(script.Parent:WaitForChild("DataService"))
local EggService = require(script.Parent:WaitForChild("EggService"))
local FigurineService = require(script.Parent:WaitForChild("FigurineService"))

local commands = {}

local function registerCommand(name, desc, handler)
	commands[name] = {
		Desc = desc,
		Handler = handler,
	}
end

local function listCommands(player)
	local list = {}
	for name, info in pairs(commands) do
		table.insert(list, string.format("/%s - %s", name, info.Desc))
	end
	table.sort(list)
	print(string.format("[GM] Commands for %s:\n%s", player.Name, table.concat(list, "\n")))
end

registerCommand("addcoins", "增加金币，格式: /addcoins 100", function(player, args)
	local amount = tonumber(args[2])
	if not amount then
		warn("[GM] addcoins 参数错误，格式: /addcoins 100")
		return
	end

	if amount <= 0 then
		warn("[GM] addcoins 数值必须大于0")
		return
	end

	DataService:AddCoins(player, amount)
end)

registerCommand("clearcoins", "清空自己金币，格式: /clearcoins", function(player, args)
	DataService:SetCoins(player, 0)
end)

registerCommand("resetdata", "清空自己所有数据，格式: /resetdata", function(player, args)
	DataService:ResetPlayerData(player)
	EggService:ClearPlayerState(player)
	FigurineService:UnbindPlayer(player)
	FigurineService:BindPlayer(player)
end)

registerCommand("gmhelp", "查看GM命令列表，格式: /gmhelp", function(player, args)
	listCommands(player)
end)

registerCommand("gm", "查看GM命令列表，格式: /gm", function(player, args)
	listCommands(player)
end)

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		if type(message) ~= "string" then
			return
		end

		if message:sub(1, 1) ~= "/" then
			return
		end

		local parts = string.split(message, " ")
		local cmdName = string.lower(string.sub(parts[1], 2))
		local command = commands[cmdName]
		if not command then
			return
		end

		command.Handler(player, parts)
	end)
end)
