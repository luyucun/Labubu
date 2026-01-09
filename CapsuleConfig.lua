--[[
脚本名称: CapsuleConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/CapsuleConfig
版本: V1.3.1
职责: 盲盒配置
]]

local CapsuleConfig = {}

CapsuleConfig.Capsules = {
	{
		Id = 1001,
		Name = "Leaf",
		Quality = 1,
		Rarity = 1,
		ModelName = "Leaf",
		Price = 120,
		OpenSeconds = 10,
	},
	{
		Id = 1002,
		Name = "Water",
		Quality = 2,
		Rarity = 2,
		ModelName = "Water",
		Price = 140,
		OpenSeconds = 15,
	},
	{
		Id = 1003,
		Name = "Lunar",
		Quality = 3,
		Rarity = 1,
		ModelName = "Lunar",
		Price = 160,
		OpenSeconds = 20,
	},
	{
		Id = 1004,
		Name = "Solar",
		Quality = 4,
		Rarity = 2,
		ModelName = "Solar",
		Price = 180,
		OpenSeconds = 25,
	},
	{
		Id = 1005,
		Name = "Flame",
		Quality = 5,
		Rarity = 1,
		ModelName = "Flame",
		Price = 200,
		OpenSeconds = 30,
	},
	{
		Id = 1006,
		Name = "Heart",
		Quality = 6,
		Rarity = 2,
		ModelName = "Heart",
		Price = 220,
		OpenSeconds = 35,
	},
	{
		Id = 1007,
		Name = "Celestial",
		Quality = 7,
		Rarity = 1,
		ModelName = "Celestial",
		Price = 240,
		OpenSeconds = 40,
	},
}

local byId = {}
for _, info in ipairs(CapsuleConfig.Capsules) do
	byId[info.Id] = info
end

function CapsuleConfig.GetById(id)
	return byId[id]
end

return CapsuleConfig
