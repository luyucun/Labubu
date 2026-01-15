--[[
脚本名称: UpgradeConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/UpgradeConfig
版本: V2.1
职责: 手办升级经验表配置
]]

local UpgradeConfig = {}

UpgradeConfig.LevelExp = {
	[1] = 2,
	[2] = 3,
	[3] = 5,
	[4] = 8,
	[5] = 12,
	[6] = 18,
	[7] = 26,
	[8] = 38,
	[9] = 55,
	[10] = 80,
	[11] = 115,
	[12] = 165,
	[13] = 235,
	[14] = 335,
	[15] = 455,
}

local maxLevel = 1
for level in pairs(UpgradeConfig.LevelExp) do
	if level > maxLevel then
		maxLevel = level
	end
end

function UpgradeConfig.GetRequiredExp(level)
	return UpgradeConfig.LevelExp[level]
end

function UpgradeConfig.GetMaxLevel()
	return maxLevel
end

return UpgradeConfig
