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
	MaxPlacedCapsules = 12,
	ClaimAllProductId = 3514031081,
	ClaimAllTenProductId = 3514031237,
	AutoCollectPassId = 1673138854,
	AutoCollectInterval = 1,
	AutoCollectDotInterval = 0.7,
	GachaSlideInTime = 0.35,
	GachaCoverHoldTime = 1,
	GachaFlipTime = 0,
	GachaResultHoldTime = 0.5,
	GachaLevelUpTime = 0.5,
	GachaSlideOutTime = 0.35,
	CameraFocusDelay = 0.5,
}

return GameConfig
