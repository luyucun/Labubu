--[[
脚本名称: FigurineConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/FigurineConfig
版本: V1.6
职责: 手办基础配置
]]

local FigurineConfig = {}

FigurineConfig.Figurines = {
	{
		Id = 10001,
		Name = "绿叶布布1",
		BaseRate = 10,
		Quality = 1,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Green/Position1",
		ClaimButtonPath = "ButtonGreen/Button1",
	},
	{
		Id = 10002,
		Name = "绿叶布布2",
		BaseRate = 12,
		Quality = 1,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Green/Position2",
		ClaimButtonPath = "ButtonGreen/Button2",
	},
	{
		Id = 10003,
		Name = "绿叶布布3",
		BaseRate = 14,
		Quality = 1,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Green/Position3",
		ClaimButtonPath = "ButtonGreen/Button3",
	},
	{
		Id = 10004,
		Name = "绿叶布布4",
		BaseRate = 16,
		Quality = 1,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Green/Position4",
		ClaimButtonPath = "ButtonGreen/Button4",
	},
	{
		Id = 10005,
		Name = "绿叶布布5",
		BaseRate = 18,
		Quality = 1,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Green/Position5",
		ClaimButtonPath = "ButtonGreen/Button5",
	},
	{
		Id = 10006,
		Name = "绿叶布布6",
		BaseRate = 20,
		Quality = 1,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Green/Position6",
		ClaimButtonPath = "ButtonGreen/Button6",
	},
	{
		Id = 10007,
		Name = "绿叶布布7",
		BaseRate = 22,
		Quality = 1,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Green/Position7",
		ClaimButtonPath = "ButtonGreen/Button7",
	},
	{
		Id = 10008,
		Name = "绿叶布布8",
		BaseRate = 24,
		Quality = 1,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Green/Position8",
		ClaimButtonPath = "ButtonGreen/Button8",
	},
	{
		Id = 10009,
		Name = "绿叶布布9",
		BaseRate = 26,
		Quality = 1,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Green/Position9",
		ClaimButtonPath = "ButtonGreen/Button9",
	},
	{
		Id = 20001,
		Name = "水布布1",
		BaseRate = 50,
		Quality = 2,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Blue/Position1",
		ClaimButtonPath = "ButtonBlue/Button1",
	},
	{
		Id = 20002,
		Name = "水布布2",
		BaseRate = 55,
		Quality = 2,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Blue/Position2",
		ClaimButtonPath = "ButtonBlue/Button2",
	},
	{
		Id = 20003,
		Name = "水布布3",
		BaseRate = 60,
		Quality = 2,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Blue/Position3",
		ClaimButtonPath = "ButtonBlue/Button3",
	},
	{
		Id = 20004,
		Name = "水布布4",
		BaseRate = 65,
		Quality = 2,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Blue/Position4",
		ClaimButtonPath = "ButtonBlue/Button4",
	},
	{
		Id = 20005,
		Name = "水布布5",
		BaseRate = 70,
		Quality = 2,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Blue/Position5",
		ClaimButtonPath = "ButtonBlue/Button5",
	},
	{
		Id = 20006,
		Name = "水布布6",
		BaseRate = 75,
		Quality = 2,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Blue/Position6",
		ClaimButtonPath = "ButtonBlue/Button6",
	},
	{
		Id = 20007,
		Name = "水布布7",
		BaseRate = 80,
		Quality = 2,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Blue/Position7",
		ClaimButtonPath = "ButtonBlue/Button7",
	},
	{
		Id = 20008,
		Name = "水布布8",
		BaseRate = 85,
		Quality = 2,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Blue/Position8",
		ClaimButtonPath = "ButtonBlue/Button8",
	},
	{
		Id = 20009,
		Name = "水布布9",
		BaseRate = 90,
		Quality = 2,
		Rarity = 1,
		ModelName = "LBB01",
		ShowcasePath = "ShowCase/Blue/Position9",
		ClaimButtonPath = "ButtonBlue/Button9",
	},
}

local byId = {}
for _, info in ipairs(FigurineConfig.Figurines) do
	byId[info.Id] = info
end

function FigurineConfig.GetById(id)
	return byId[id]
end

return FigurineConfig
