--[[
脚本名称: CapsuleSpawnPoolConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/CapsuleSpawnPoolConfig
版本: V1.3.1
职责: 盲盒刷新池配置
]]

local CapsuleSpawnPoolConfig = {}

CapsuleSpawnPoolConfig.Pools = {
	[1] = {
		{ Id = 10001, CapsuleId = 1001, Weight = 30 },
		{ Id = 10002, CapsuleId = 1002, Weight = 20 },
		{ Id = 10003, CapsuleId = 1003, Weight = 8 },
		{ Id = 10004, CapsuleId = 1004, Weight = 6 },
		{ Id = 10005, CapsuleId = 1005, Weight = 4 },
		{ Id = 10006, CapsuleId = 1006, Weight = 2 },
		{ Id = 10007, CapsuleId = 1007, Weight = 1 },
	},
}

function CapsuleSpawnPoolConfig.GetPool(poolId)
	return CapsuleSpawnPoolConfig.Pools[poolId]
end

return CapsuleSpawnPoolConfig
