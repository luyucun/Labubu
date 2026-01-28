--[[
脚本名称: FigurinePoolConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/FigurinePoolConfig
版本: V2.2
职责: 手办卡池配置
]]

local FigurinePoolConfig = {}

FigurinePoolConfig.Pools = {
	[90001] = {
		{ FigurineId = 10001, Weight = 402 },
		{ FigurineId = 10002, Weight = 213 },
		{ FigurineId = 10003, Weight = 136 },
		{ FigurineId = 10004, Weight = 92 },
		{ FigurineId = 10005, Weight = 64 },
		{ FigurineId = 10006, Weight = 44 },
		{ FigurineId = 10007, Weight = 28 },
		{ FigurineId = 10008, Weight = 16 },
		{ FigurineId = 10009, Weight = 6 },
	},
	[90002] = {
		{ FigurineId = 20001, Weight = 402 },
		{ FigurineId = 20002, Weight = 213 },
		{ FigurineId = 20003, Weight = 136 },
		{ FigurineId = 20004, Weight = 92 },
		{ FigurineId = 20005, Weight = 64 },
		{ FigurineId = 20006, Weight = 44 },
		{ FigurineId = 20007, Weight = 28 },
		{ FigurineId = 20008, Weight = 16 },
		{ FigurineId = 20009, Weight = 6 },
	},
	[90003] = {
		{ FigurineId = 30001, Weight = 402 },
		{ FigurineId = 30002, Weight = 213 },
		{ FigurineId = 30003, Weight = 136 },
		{ FigurineId = 30004, Weight = 92 },
		{ FigurineId = 30005, Weight = 64 },
		{ FigurineId = 30006, Weight = 44 },
		{ FigurineId = 30007, Weight = 28 },
		{ FigurineId = 30008, Weight = 16 },
		{ FigurineId = 30009, Weight = 6 },
	},
	[90004] = {
		{ FigurineId = 40001, Weight = 402 },
		{ FigurineId = 40002, Weight = 213 },
		{ FigurineId = 40003, Weight = 136 },
		{ FigurineId = 40004, Weight = 92 },
		{ FigurineId = 40005, Weight = 64 },
		{ FigurineId = 40006, Weight = 44 },
		{ FigurineId = 40007, Weight = 28 },
		{ FigurineId = 40008, Weight = 16 },
		{ FigurineId = 40009, Weight = 6 },
	},
	[90005] = {
		{ FigurineId = 50001, Weight = 433 },
		{ FigurineId = 50002, Weight = 225 },
		{ FigurineId = 50003, Weight = 142 },
		{ FigurineId = 50004, Weight = 95 },
		{ FigurineId = 50005, Weight = 64 },
		{ FigurineId = 50006, Weight = 42 },
		{ FigurineId = 50007, Weight = 26 },
	},
	[90006] = {
		{ FigurineId = 60001, Weight = 433 },
		{ FigurineId = 60002, Weight = 225 },
		{ FigurineId = 60003, Weight = 142 },
		{ FigurineId = 60004, Weight = 95 },
		{ FigurineId = 60005, Weight = 64 },
		{ FigurineId = 60006, Weight = 42 },
		{ FigurineId = 60007, Weight = 26 },
	},
	[90007] = {
		{ FigurineId = 70001, Weight = 468 },
		{ FigurineId = 70002, Weight = 236 },
		{ FigurineId = 70003, Weight = 144 },
		{ FigurineId = 70004, Weight = 93 },
		{ FigurineId = 70005, Weight = 60 },
	},
}

function FigurinePoolConfig.GetPool(poolId)
	return FigurinePoolConfig.Pools[poolId]
end

return FigurinePoolConfig
