--[[
脚本名称: FigurinePoolConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/FigurinePoolConfig
版本: V1.5
职责: 手办卡池配置
]]

local FigurinePoolConfig = {}

FigurinePoolConfig.Pools = {
	[9001] = {
		{ FigurineId = 10001, Weight = 20 },
		{ FigurineId = 10002, Weight = 20 },
		{ FigurineId = 10003, Weight = 20 },
		{ FigurineId = 10004, Weight = 20 },
		{ FigurineId = 10005, Weight = 20 },
		{ FigurineId = 10006, Weight = 20 },
		{ FigurineId = 10007, Weight = 20 },
		{ FigurineId = 10008, Weight = 20 },
		{ FigurineId = 10009, Weight = 20 },
	},
	[9002] = {
		{ FigurineId = 20001, Weight = 20 },
		{ FigurineId = 20002, Weight = 20 },
		{ FigurineId = 20003, Weight = 20 },
		{ FigurineId = 20004, Weight = 20 },
		{ FigurineId = 20005, Weight = 20 },
		{ FigurineId = 20006, Weight = 20 },
		{ FigurineId = 20007, Weight = 20 },
		{ FigurineId = 20008, Weight = 20 },
		{ FigurineId = 20009, Weight = 20 },
	},
}

function FigurinePoolConfig.GetPool(poolId)
	return FigurinePoolConfig.Pools[poolId]
end

return FigurinePoolConfig
