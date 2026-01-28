--[[
脚本名称: CapsuleSpawnPoolConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/CapsuleSpawnPoolConfig
版本: V2.2
职责: 盲盒刷新池配置
]]

local CapsuleSpawnPoolConfig = {}

CapsuleSpawnPoolConfig.Pools = {
	[1] = {
		{ Id = 10001, CapsuleId = 1001, Weight = 4000 },
		{ Id = 10002, CapsuleId = 1002, Weight = 1000 },
		{ Id = 10003, CapsuleId = 1003, Weight = 400 },
		{ Id = 10004, CapsuleId = 1004, Weight = 200 },
		{ Id = 10005, CapsuleId = 1005, Weight = 100 },
		{ Id = 10006, CapsuleId = 1006, Weight = 0 },
		{ Id = 10007, CapsuleId = 1007, Weight = 0 },
	},
	[2] = {
		{ Id = 20001, CapsuleId = 1001, Weight = 4000 },
		{ Id = 20002, CapsuleId = 1002, Weight = 1500 },
		{ Id = 20003, CapsuleId = 1003, Weight = 600 },
		{ Id = 20004, CapsuleId = 1004, Weight = 300 },
		{ Id = 20005, CapsuleId = 1005, Weight = 100 },
		{ Id = 20006, CapsuleId = 1006, Weight = 30 },
		{ Id = 20007, CapsuleId = 1007, Weight = 30 },
	},
	[3] = {
		{ Id = 30001, CapsuleId = 1001, Weight = 4000 },
		{ Id = 30002, CapsuleId = 1002, Weight = 1500 },
		{ Id = 30003, CapsuleId = 1003, Weight = 800 },
		{ Id = 30004, CapsuleId = 1004, Weight = 400 },
		{ Id = 30005, CapsuleId = 1005, Weight = 150 },
		{ Id = 30006, CapsuleId = 1006, Weight = 80 },
		{ Id = 30007, CapsuleId = 1007, Weight = 50 },
	},
}

CapsuleSpawnPoolConfig.Unlocks = {
	{ Id = 1001, PoolId = 1, UnlockOutputSpeed = 0 },
	{ Id = 1002, PoolId = 2, UnlockOutputSpeed = 200 },
	{ Id = 1003, PoolId = 3, UnlockOutputSpeed = 2000 },
}

CapsuleSpawnPoolConfig.RarityMutation = {
	{ Id = 1001, Rarity = 1, Weight = 8275 },
	{ Id = 1002, Rarity = 2, Weight = 1000 },
	{ Id = 1003, Rarity = 3, Weight = 400 },
	{ Id = 1004, Rarity = 4, Weight = 200 },
	{ Id = 1005, Rarity = 5, Weight = 100 },
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
