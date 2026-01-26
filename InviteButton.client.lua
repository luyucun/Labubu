--[[
脚本名称: InviteButton
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/InviteButton
版本: V1.0
职责: 邀请好友按钮弹出系统邀请界面
]]

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local GuiResolver = require(modulesFolder:WaitForChild("GuiResolver"))

local topRightGui = GuiResolver.WaitForLayer(playerGui, { "TopRightGui", "TopRightGUI", "TopRight", "TopRightUI" }, {
	"Options",
	"Invite",
	"Learderboard",
	"Leaderboard",
}, 30)
if not topRightGui then
	warn("[InviteButton] TopRightGui not found")
end

local function resolveInviteButton(root)
	local direct = root:FindFirstChild("Invite")
	if direct and not direct:IsA("GuiButton") then
		direct = direct:FindFirstChildWhichIsA("GuiButton", true)
	end
	if direct and direct:IsA("GuiButton") then
		return direct
	end
	local descendant = root:FindFirstChild("Invite", true)
	if descendant then
		if descendant:IsA("GuiButton") then
			return descendant
		end
		local nested = descendant:FindFirstChildWhichIsA("GuiButton", true)
		if nested then
			return nested
		end
	end
	return nil
end

local inviteButton = topRightGui and resolveInviteButton(topRightGui) or nil
if not inviteButton then
	inviteButton = GuiResolver.FindGuiButton(playerGui, "Invite")
end
if not inviteButton then
	warn("[InviteButton] Invite button not found")
	return
end

local function promptInvite()
	local ok = pcall(function()
		SocialService:PromptGameInvite(player)
	end)
	if ok then
		return
	end
	pcall(function()
		StarterGui:SetCore("PromptGameInvite", player)
	end)
end

inviteButton.Activated:Connect(promptInvite)
