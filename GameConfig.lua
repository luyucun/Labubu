--[[
脚本名称: GameConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/GameConfig
版本: V1.6
职责: 全局基础配置
]]

local GameConfig = {
	MaxPlayers = 8,
	StartCoins = 200,
	DataStoreName = "Labubu_PlayerData_V1",
	AutoSaveInterval = 120,
	HomeFolderName = "Home",
	HomeSlotPrefix = "Player",
	HomeSlotCount = 8,
	ConveyorSpawnInterval = 2.4,
	ConveyorMoveTime = 15,
	CapsuleSpawnPoolId = 1,
	FigurineCoinCapSeconds = 10800,
	OfflineCapSeconds = 7200,
	MaxPlacedCapsules = 15,
	ClaimAllProductId = 3514031081,
	ClaimAllTenProductId = 3514031237,
	AutoCollectPassId = 1673138854,
	StarterPackPassId = 1693176659,
	GroupRewardGroupId = 602157319,
	GroupRewardCapsuleId = 1003,
	GroupRewardCapsuleCount = 5,
	CoinAddMinOutputSpeed = 20,
	CoinAddProducts = {
		{
			ButtonName = "CoinAdd01",
			ProductId = 3521138526,
			Seconds = 1800,
		},
		{
			ButtonName = "CoinAdd02",
			ProductId = 3521779177,
			Seconds = 7200,
		},
		{
			ButtonName = "CoinAdd03",
			ProductId = 3521779711,
			Seconds = 36000,
		},
	},
	OutputMultiplierProducts = {
		{ Multiplier = 2, ProductId = 3522025794, Price = 19 },
		{ Multiplier = 4, ProductId = 3522026011, Price = 49 },
		{ Multiplier = 6, ProductId = 3522026281, Price = 89 },
		{ Multiplier = 8, ProductId = 3522026559, Price = 139 },
		{ Multiplier = 10, ProductId = 3522026859, Price = 199 },
		{ Multiplier = 12, ProductId = 3522027227, Price = 269 },
		{ Multiplier = 14, ProductId = 3522027539, Price = 349 },
		{ Multiplier = 16, ProductId = 3522027869, Price = 439 },
		{ Multiplier = 18, ProductId = 3522028113, Price = 539 },
		{ Multiplier = 20, ProductId = 3522030207, Price = 649 },
		{ Multiplier = 22, ProductId = 3522030413, Price = 769 },
		{ Multiplier = 24, ProductId = 3522030729, Price = 899 },
		{ Multiplier = 26, ProductId = 3522031063, Price = 1039 },
	},
	AutoCollectInterval = 1,
	AutoCollectDotInterval = 0.7,
	GachaSlideInTime = 0.35,
	GachaCoverHoldTime = 1.2,
	GachaFlipTime = 0,
	GachaResultHoldTime = 1.5,
	GachaLevelUpTime = 0.8,
	GachaSlideOutTime = 0.35,
	CameraFocusDelay = 0.5,
}

return GameConfig
