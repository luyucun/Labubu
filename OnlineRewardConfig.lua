--[[
脚本名称: OnlineRewardConfig
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Config/OnlineRewardConfig
版本: V1.0
职责: 在线奖励配置（每日UTC0点重置）
]]

local OnlineRewardConfig = {}

-- Kind: "Capsule"(盲盒) / "Potion"(药水)
OnlineRewardConfig.Rewards = {
	{ Id = 1, Seconds = 180, Kind = "Capsule", ItemId = 1003, Count = 1 },
	{ Id = 2, Seconds = 360, Kind = "Potion", ItemId = 1001, Count = 1 },
	{ Id = 3, Seconds = 600, Kind = "Capsule", ItemId = 1003, Count = 1 },
	{ Id = 4, Seconds = 900, Kind = "Capsule", ItemId = 1003, Count = 1 },
	{ Id = 5, Seconds = 1500, Kind = "Capsule", ItemId = 1006, Count = 1 },
	{ Id = 6, Seconds = 2400, Kind = "Capsule", ItemId = 1003, Count = 2 },
	{ Id = 7, Seconds = 3000, Kind = "Potion", ItemId = 1002, Count = 1 },
	{ Id = 8, Seconds = 3600, Kind = "Capsule", ItemId = 1003, Count = 2 },
	{ Id = 9, Seconds = 4500, Kind = "Capsule", ItemId = 1003, Count = 2 },
	{ Id = 10, Seconds = 5400, Kind = "Capsule", ItemId = 1006, Count = 1 },
}

local rewardsById = {}
local maxId = 0

for _, info in ipairs(OnlineRewardConfig.Rewards) do
	if info and info.Id then
		rewardsById[tonumber(info.Id) or info.Id] = info
		if info.Id > maxId then
			maxId = info.Id
		end
	end
end

OnlineRewardConfig.MaxId = maxId

function OnlineRewardConfig.GetAll()
	return OnlineRewardConfig.Rewards
end

function OnlineRewardConfig.GetById(id)
	local key = tonumber(id) or id
	return rewardsById[key]
end

return OnlineRewardConfig
