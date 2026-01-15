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
		{ Id = 10001, CapsuleId = 1001, Weight = 20 },
		{ Id = 10002, CapsuleId = 1002, Weight = 20 },
		{ Id = 10003, CapsuleId = 1003, Weight = 20 },
		{ Id = 10004, CapsuleId = 1004, Weight = 20 },
		{ Id = 10005, CapsuleId = 1005, Weight = 20 },
		{ Id = 10006, CapsuleId = 1006, Weight = 20 },
		{ Id = 10007, CapsuleId = 1007, Weight = 20 },
		{ Id = 10008, CapsuleId = 2001, Weight = 20 },
		{ Id = 10009, CapsuleId = 2002, Weight = 20 },
		{ Id = 10010, CapsuleId = 2003, Weight = 20 },
		{ Id = 10011, CapsuleId = 2004, Weight = 20 },
		{ Id = 10012, CapsuleId = 2005, Weight = 20 },
		{ Id = 10013, CapsuleId = 2006, Weight = 20 },
		{ Id = 10014, CapsuleId = 2007, Weight = 20 },
		{ Id = 10015, CapsuleId = 3001, Weight = 20 },
		{ Id = 10016, CapsuleId = 3002, Weight = 20 },
		{ Id = 10017, CapsuleId = 3003, Weight = 20 },
		{ Id = 10018, CapsuleId = 3004, Weight = 20 },
		{ Id = 10019, CapsuleId = 3005, Weight = 20 },
		{ Id = 10020, CapsuleId = 3006, Weight = 20 },
		{ Id = 10021, CapsuleId = 3007, Weight = 20 },
		{ Id = 10022, CapsuleId = 4001, Weight = 20 },
		{ Id = 10023, CapsuleId = 4002, Weight = 20 },
		{ Id = 10024, CapsuleId = 4003, Weight = 20 },
		{ Id = 10025, CapsuleId = 4004, Weight = 20 },
		{ Id = 10026, CapsuleId = 4005, Weight = 20 },
		{ Id = 10027, CapsuleId = 4006, Weight = 20 },
		{ Id = 10028, CapsuleId = 4007, Weight = 20 },
		{ Id = 10029, CapsuleId = 5001, Weight = 20 },
		{ Id = 10030, CapsuleId = 5002, Weight = 20 },
		{ Id = 10031, CapsuleId = 5003, Weight = 20 },
		{ Id = 10032, CapsuleId = 5004, Weight = 20 },
		{ Id = 10033, CapsuleId = 5005, Weight = 20 },
		{ Id = 10034, CapsuleId = 5006, Weight = 20 },
		{ Id = 10035, CapsuleId = 5007, Weight = 20 },
	},
}

function CapsuleSpawnPoolConfig.GetPool(poolId)
	return CapsuleSpawnPoolConfig.Pools[poolId]
end

return CapsuleSpawnPoolConfig
