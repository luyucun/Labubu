--[[
脚本名称: PotionConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/PotionConfig
版本: V1.0
职责: 产速加成药水配置
]]

local PotionConfig = {}

PotionConfig.Potions = {
	{
		Id = 1001,
		Tier = 1,
		Name = "Potion 1",
		Bonus = 0.3,
		DurationMinutes = 30,
		DiamondPrice = 29,
		ProductId = 3524122858,
	},
	{
		Id = 1002,
		Tier = 2,
		Name = "Potion 2",
		Bonus = 0.5,
		DurationMinutes = 30,
		DiamondPrice = 89,
		ProductId = 3524122984,
	},
	{
		Id = 1003,
		Tier = 3,
		Name = "Potion 3",
		Bonus = 1,
		DurationMinutes = 30,
		DiamondPrice = 199,
		ProductId = 3524123226,
	},
}

local potionById = {}
local potionByTier = {}
local maxTier = 0

for _, info in ipairs(PotionConfig.Potions) do
	if info and info.Id then
		potionById[info.Id] = info
	end
	if info and info.Tier then
		potionByTier[info.Tier] = info
		if info.Tier > maxTier then
			maxTier = info.Tier
		end
	end
end

PotionConfig.MaxTier = maxTier

function PotionConfig.GetAll()
	return PotionConfig.Potions
end

function PotionConfig.GetById(id)
	local key = tonumber(id) or id
	return potionById[key]
end

function PotionConfig.GetByTier(tier)
	local key = tonumber(tier) or tier
	return potionByTier[key]
end

return PotionConfig
