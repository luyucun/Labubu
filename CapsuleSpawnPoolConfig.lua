--[[
脚本名称: CapsuleSpawnPoolConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/CapsuleSpawnPoolConfig
版本: V2.1
职责: 盲盒刷新池配置
]]

local CapsuleSpawnPoolConfig = {}

CapsuleSpawnPoolConfig.Pools = {
	[1] = {
		{ Id = 10001, CapsuleId = 1001, Weight = 100 },
		{ Id = 10002, CapsuleId = 1002, Weight = 80 },
		{ Id = 10003, CapsuleId = 1003, Weight = 20 },
		{ Id = 10004, CapsuleId = 1004, Weight = 20 },
		{ Id = 10005, CapsuleId = 1005, Weight = 20 },
		{ Id = 10006, CapsuleId = 1006, Weight = 20 },
		{ Id = 10007, CapsuleId = 1007, Weight = 20 },
	},
	[2] = {
		{ Id = 10001, CapsuleId = 1001, Weight = 20 },
		{ Id = 10002, CapsuleId = 1002, Weight = 20 },
		{ Id = 10003, CapsuleId = 1003, Weight = 100 },
		{ Id = 10004, CapsuleId = 1004, Weight = 80 },
		{ Id = 10005, CapsuleId = 1005, Weight = 20 },
		{ Id = 10006, CapsuleId = 1006, Weight = 20 },
		{ Id = 10007, CapsuleId = 1007, Weight = 20 },
	},
	[3] = {
		{ Id = 10001, CapsuleId = 1001, Weight = 20 },
		{ Id = 10002, CapsuleId = 1002, Weight = 20 },
		{ Id = 10003, CapsuleId = 1003, Weight = 20 },
		{ Id = 10004, CapsuleId = 1004, Weight = 20 },
		{ Id = 10005, CapsuleId = 1005, Weight = 100 },
		{ Id = 10006, CapsuleId = 1006, Weight = 80 },
		{ Id = 10007, CapsuleId = 1007, Weight = 20 },
	},
}

CapsuleSpawnPoolConfig.Unlocks = {
	{ Id = 1001, PoolId = 1, UnlockOutputSpeed = 0 },
	{ Id = 1002, PoolId = 2, UnlockOutputSpeed = 300 },
	{ Id = 1003, PoolId = 3, UnlockOutputSpeed = 600 },
}

CapsuleSpawnPoolConfig.RarityMutation = {
	{ Id = 1001, Rarity = 1, Weight = 80 },
	{ Id = 1002, Rarity = 2, Weight = 30 },
	{ Id = 1003, Rarity = 3, Weight = 15 },
	{ Id = 1004, Rarity = 4, Weight = 5 },
	{ Id = 1005, Rarity = 5, Weight = 1 },
}

function CapsuleSpawnPoolConfig.GetPool(poolId)
	return CapsuleSpawnPoolConfig.Pools[poolId]
end

function CapsuleSpawnPoolConfig.GetUnlocks()
	return CapsuleSpawnPoolConfig.Unlocks
end

function CapsuleSpawnPoolConfig.GetRarityMutation()
	return CapsuleSpawnPoolConfig.RarityMutation
end

return CapsuleSpawnPoolConfig
