--[[
脚本名称: GameConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/GameConfig
版本: V1.6
职责: 全局基础配置
]]

local GameConfig = {
	MaxPlayers = 8,
	StartCoins = 500,
	DataStoreName = "Labubu_PlayerData_V1",
	AutoSaveInterval = 120,
	HomeFolderName = "Home",
	HomeSlotPrefix = "Player",
	HomeSlotCount = 8,
	ConveyorSpawnInterval = 1,
	ConveyorMoveTime = 6,
	CapsuleSpawnPoolId = 1,
	FigurineCoinCapSeconds = 10800,
}

return GameConfig
