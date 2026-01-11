--[[
脚本名称: FormatHelper
脚本类型: ModuleScript (共享模块)
脚本位置: ReplicatedStorage/Modules/FormatHelper
版本: V1.6
]]

--[[
格式化辅助工具模块
职责:
1. 提供各种数据格式化功能
2. 金币显示格式化
3. 数字缩写格式化(后续版本)
]]

local FormatHelper = {}

-- ==================== 金币格式化 ====================

--[[
格式化金币显示（原始格式）
@param amount number - 金币数量
@return string - 格式化后的字符串,如 "$100"
]]
function FormatHelper.FormatCoins(amount)
	if type(amount) ~= "number" then
		warn("[FormatHelper] FormatCoins: 参数必须是数字")
		return "$0"
	end

	if amount < 0 then
		amount = 0
	end

	return string.format("$%d", math.floor(amount))
end

--[[
格式化金币显示（大数值缩写版本）
规则：
- 0 ~ 9999: 原样显示，如 "1234"
- 10000 ~ 999999: 显示为 X.XK，如 "12.3K"（万级）
- 1000000 ~ 999999999: 显示为 X.XM，如 "1.5M"（百万级）
- 1000000000+: 显示为 X.XB，如 "2.3B"（十亿级）

@param amount number - 金币数量
@param showDollarSign boolean - 是否显示$符号（默认false）
@return string - 缩写后的字符串
]]
function FormatHelper.FormatCoinsShort(amount, showDollarSign)
	if type(amount) ~= "number" then
		return showDollarSign and "$0" or "0"
	end

	if amount < 0 then
		amount = 0
	end

	local result

	if amount >= 1e9 then
		local shortened = amount / 1e9
		if shortened >= 100 then
			result = string.format("%.0fB", shortened)
		elseif shortened >= 10 then
			result = string.format("%.1fB", shortened)
		else
			result = string.format("%.2fB", shortened)
		end
	elseif amount >= 1e6 then
		local shortened = amount / 1e6
		if shortened >= 100 then
			result = string.format("%.0fM", shortened)
		elseif shortened >= 10 then
			result = string.format("%.1fM", shortened)
		else
			result = string.format("%.2fM", shortened)
		end
	elseif amount >= 1e4 then
		local shortened = amount / 1e3
		if shortened >= 100 then
			result = string.format("%.0fK", shortened)
		elseif shortened >= 10 then
			result = string.format("%.1fK", shortened)
		else
			result = string.format("%.2fK", shortened)
		end
	else
		result = tostring(math.floor(amount))
	end

	result = result:gsub("%.?0+([KMBT])$", "%1")

	if showDollarSign then
		return "$" .. result
	end
	return result
end

-- ==================== 数字格式化 ====================

--[[
添加千分位分隔符
@param number number - 数字
@return string - 格式化后的字符串,如 "1,000,000"
]]
function FormatHelper.FormatNumberWithCommas(number)
	if type(number) ~= "number" then
		return "0"
	end

	local formatted = tostring(math.floor(number))
	local k

	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end

	return formatted
end

--[[
数字缩写格式化(K, M, B, T)
@param number number - 数字
@return string - 缩写后的字符串,如 "1.5K", "2.3M"
]]
function FormatHelper.FormatNumberShort(number)
	if type(number) ~= "number" then
		return "0"
	end

	if number < 0 then
		number = 0
	end

	local abbreviations = {
		{ value = 1e12, suffix = "T" },
		{ value = 1e9, suffix = "B" },
		{ value = 1e6, suffix = "M" },
		{ value = 1e3, suffix = "K" },
	}

	for _, abbr in ipairs(abbreviations) do
		if number >= abbr.value then
			local shortened = number / abbr.value
			return string.format("%.1f%s", shortened, abbr.suffix)
		end
	end

	return tostring(math.floor(number))
end

-- ==================== 时间格式化 ====================

--[[
格式化秒数为时分秒
@param seconds number - 秒数
@return string - 格式化后的时间字符串,如 "1:30:45" 或 "30:45"
]]
function FormatHelper.FormatTime(seconds)
	if type(seconds) ~= "number" or seconds < 0 then
		return "0:00"
	end

	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)

	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	else
		return string.format("%d:%02d", minutes, secs)
	end
end

--[[
格式化秒数为友好的时间描述
@param seconds number - 秒数
@return string - 友好的时间描述,如 "2小时30分" 或 "45秒"
]]
function FormatHelper.FormatTimeFriendly(seconds)
	if type(seconds) ~= "number" or seconds < 0 then
		return "0秒"
	end

	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)

	if hours > 0 then
		if minutes > 0 then
			return string.format("%d小时%d分", hours, minutes)
		else
			return string.format("%d小时", hours)
		end
	elseif minutes > 0 then
		if secs > 0 then
			return string.format("%d分%d秒", minutes, secs)
		else
			return string.format("%d分", minutes)
		end
	else
		return string.format("%d秒", secs)
	end
end

-- ==================== 百分比格式化 ====================

--[[
格式化百分比
@param value number - 数值(0-1)
@param decimals number - 小数位数(默认0)
@return string - 百分比字符串,如 "75%"
]]
function FormatHelper.FormatPercent(value, decimals)
	if type(value) ~= "number" then
		return "0%"
	end

	decimals = decimals or 0

	local percent = value * 100

	if decimals == 0 then
		return string.format("%d%%", math.floor(percent))
	else
		return string.format("%." .. decimals .. "f%%", percent)
	end
end

return FormatHelper
