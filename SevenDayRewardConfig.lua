--[[
脚本名称: SevenDayRewardConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/SevenDayRewardConfig
版本: V1.0
职责: 七日登录奖励配置（UTC0刷新）
]]

local SevenDayRewardConfig = {}

SevenDayRewardConfig.UnlockCapsuleOpenTotal = 10
SevenDayRewardConfig.UnlockAllPrimaryProductId = 3489888670
SevenDayRewardConfig.UnlockAllProductIds = {
	3489888670,
	3535358435,
}

-- Kind: "Capsule"(盲盒) / "Potion"(药水)
SevenDayRewardConfig.Rewards = {
	{ Day = 1, Kind = "Capsule", ItemId = 1004, Count = 1 },
	{ Day = 2, Kind = "Potion", ItemId = 1001, Count = 1 },
	{ Day = 3, Kind = "Capsule", ItemId = 1004, Count = 2 },
	{ Day = 4, Kind = "Potion", ItemId = 1001, Count = 2 },
	{ Day = 5, Kind = "Capsule", ItemId = 1005, Count = 1 },
	{ Day = 6, Kind = "Capsule", ItemId = 1005, Count = 1 },
	{ Day = 7, Kind = "Capsule", ItemId = 1007, Count = 2 },
}

local rewardsByDay = {}
local maxDay = 0
for _, info in ipairs(SevenDayRewardConfig.Rewards) do
	if info and info.Day then
		local day = tonumber(info.Day) or info.Day
		rewardsByDay[day] = info
		if type(day) == "number" and day > maxDay then
			maxDay = day
		end
	end
end

local unlockAllProducts = {}
for _, productId in ipairs(SevenDayRewardConfig.UnlockAllProductIds) do
	local id = tonumber(productId) or productId
	if id then
		unlockAllProducts[id] = true
	end
end

function SevenDayRewardConfig.GetAll()
	return SevenDayRewardConfig.Rewards
end

function SevenDayRewardConfig.GetByDay(day)
	local key = tonumber(day) or day
	return rewardsByDay[key]
end

function SevenDayRewardConfig.GetDayCount()
	return maxDay
end

function SevenDayRewardConfig.GetPrimaryUnlockAllProductId()
	return tonumber(SevenDayRewardConfig.UnlockAllPrimaryProductId)
end

function SevenDayRewardConfig.IsUnlockAllProductId(productId)
	local id = tonumber(productId) or productId
	if not id then
		return false
	end
	return unlockAllProducts[id] == true
end

return SevenDayRewardConfig
