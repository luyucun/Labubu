--[[
脚本名称: FigurinePoolConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/FigurinePoolConfig
版本: V2.1
职责: 手办卡池配置
]]

local FigurinePoolConfig = {}

FigurinePoolConfig.Pools = {
	[99001] = {
		{ FigurineId = 10001, Weight = 20 },
		{ FigurineId = 10002, Weight = 20 },
		{ FigurineId = 10003, Weight = 20 },
		{ FigurineId = 10004, Weight = 20 },
		{ FigurineId = 10005, Weight = 20 },
		{ FigurineId = 10006, Weight = 20 },
		{ FigurineId = 10007, Weight = 20 },
		{ FigurineId = 10008, Weight = 20 },
		{ FigurineId = 10009, Weight = 20 },
		{ FigurineId = 20001, Weight = 20 },
		{ FigurineId = 20002, Weight = 20 },
		{ FigurineId = 20003, Weight = 20 },
		{ FigurineId = 20004, Weight = 20 },
		{ FigurineId = 20005, Weight = 20 },
		{ FigurineId = 20006, Weight = 20 },
		{ FigurineId = 20007, Weight = 20 },
		{ FigurineId = 20008, Weight = 20 },
		{ FigurineId = 20009, Weight = 20 },
		{ FigurineId = 30001, Weight = 20 },
		{ FigurineId = 30002, Weight = 20 },
		{ FigurineId = 30003, Weight = 20 },
		{ FigurineId = 30004, Weight = 20 },
		{ FigurineId = 30005, Weight = 20 },
		{ FigurineId = 30006, Weight = 20 },
		{ FigurineId = 30007, Weight = 20 },
		{ FigurineId = 30008, Weight = 20 },
		{ FigurineId = 30009, Weight = 20 },
		{ FigurineId = 40001, Weight = 20 },
		{ FigurineId = 40002, Weight = 20 },
		{ FigurineId = 40003, Weight = 20 },
		{ FigurineId = 40004, Weight = 20 },
		{ FigurineId = 40005, Weight = 20 },
		{ FigurineId = 40006, Weight = 20 },
		{ FigurineId = 40007, Weight = 20 },
		{ FigurineId = 40008, Weight = 20 },
		{ FigurineId = 40009, Weight = 20 },
		{ FigurineId = 50001, Weight = 20 },
		{ FigurineId = 50002, Weight = 20 },
		{ FigurineId = 50003, Weight = 20 },
		{ FigurineId = 50004, Weight = 20 },
		{ FigurineId = 50005, Weight = 20 },
		{ FigurineId = 50006, Weight = 20 },
		{ FigurineId = 50007, Weight = 20 },
		{ FigurineId = 60001, Weight = 20 },
		{ FigurineId = 60002, Weight = 20 },
		{ FigurineId = 60003, Weight = 20 },
		{ FigurineId = 60004, Weight = 20 },
		{ FigurineId = 60005, Weight = 20 },
		{ FigurineId = 60006, Weight = 20 },
		{ FigurineId = 60007, Weight = 20 },
		{ FigurineId = 70001, Weight = 20 },
		{ FigurineId = 70002, Weight = 20 },
		{ FigurineId = 70003, Weight = 20 },
		{ FigurineId = 70004, Weight = 20 },
		{ FigurineId = 70005, Weight = 20 },
	},
}

function FigurinePoolConfig.GetPool(poolId)
	return FigurinePoolConfig.Pools[poolId]
end

return FigurinePoolConfig
