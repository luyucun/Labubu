--[[
脚本名称: Bootstrap
脚本类型: Script
脚本位置: ServerScriptService/Server/Bootstrap
版本: V1.5
职责: 玩家进入/离开流程串联
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EggService = require(script.Parent:WaitForChild("EggService"))
local FigurineService = require(script.Parent:WaitForChild("FigurineService"))
local HomeService = require(script.Parent:WaitForChild("HomeService"))
local ConveyorService = require(script.Parent:WaitForChild("ConveyorService"))

Players.CharacterAutoLoads = false

HomeService:Init()
DataService:StartAutoSave()

game:BindToClose(function()
	DataService:SaveAll(true)
end)

Players.PlayerAdded:Connect(function(player)
	print(string.format("[Bootstrap] PlayerAdded: %s (userId=%d)", player.Name, player.UserId))

	if #Players:GetPlayers() > GameConfig.MaxPlayers then
		player:Kick("服务器已满")
		return
	end

	local homeSlot = HomeService:AssignHome(player)
	print(string.format("[Bootstrap] AssignHome returned: %s", tostring(homeSlot)))
	if not homeSlot then
		player:Kick("服务器已满")
		return
	end
	print(string.format("[Bootstrap] homeSlot.Folder = %s", tostring(homeSlot.Folder)))

	DataService:LoadPlayer(player)
	print("[Bootstrap] DataService:LoadPlayer done")

	EggService:BindPlayer(player)
	print("[Bootstrap] EggService:BindPlayer done")

	FigurineService:BindPlayer(player)
	print("[Bootstrap] FigurineService:BindPlayer done")

	print("[Bootstrap] Calling ConveyorService:StartForPlayer...")
	local success, err = pcall(function()
		ConveyorService:StartForPlayer(player, homeSlot)
	end)
	if not success then
		warn(string.format("[Bootstrap] ConveyorService:StartForPlayer ERROR: %s", tostring(err)))
	else
		print("[Bootstrap] ConveyorService:StartForPlayer done")
	end

	player:LoadCharacterAsync()
end)

Players.PlayerRemoving:Connect(function(player)
	ConveyorService:StopForPlayer(player)
	EggService:UnbindPlayer(player)
	FigurineService:UnbindPlayer(player)
	DataService:UnloadPlayer(player, true)
	HomeService:ReleaseHome(player)
end)
