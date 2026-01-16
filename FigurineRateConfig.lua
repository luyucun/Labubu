--[[
脚本名称: FigurineRateConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/FigurineRateConfig
版本: V2.2
职责: 手办产速系数配置
]]

local FigurineRateConfig = {}

FigurineRateConfig.QualityCoeffs = {
	[1] = 0.05,
	[2] = 0.08,
	[3] = 0.12,
	[4] = 0.18,
	[5] = 0.25,
	[6] = 0.35,
	[7] = 0.5,
}

FigurineRateConfig.RarityCoeffs = {
	[1] = 1,
	[2] = 1.25,
	[3] = 1.8,
	[4] = 2.6,
	[5] = 4.6,
}

function FigurineRateConfig.GetQualityCoeff(quality)
	local value = FigurineRateConfig.QualityCoeffs[quality]
	if type(value) ~= "number" then
		return 0
	end
	return value
end

function FigurineRateConfig.GetRarityCoeff(rarity)
	local value = FigurineRateConfig.RarityCoeffs[rarity]
	if type(value) ~= "number" then
		return 1
	end
	return value
end

function FigurineRateConfig.GetMaxRarity()
	local maxValue = 1
	for rarity in pairs(FigurineRateConfig.RarityCoeffs) do
		if rarity > maxValue then
			maxValue = rarity
		end
	end
	return maxValue
end

return FigurineRateConfig
