--[[
脚本名称: QualityConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/QualityConfig
版本: V1.0
职责: 品质相关配置（图标）
]]

local QualityConfig = {}

QualityConfig.Icons = {
	[1] = "rbxassetid://108955563208582",
	[2] = "rbxassetid://133424751984403",
	[3] = "rbxassetid://97174425150192",
	[4] = "rbxassetid://130407159333392",
	[5] = "rbxassetid://137727751536051",
	[6] = "rbxassetid://115976015958196",
	[7] = "rbxassetid://110967078953865",
}

function QualityConfig.GetIcon(quality)
	return QualityConfig.Icons[tonumber(quality) or 0] or ""
end

return QualityConfig
