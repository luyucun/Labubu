--[[
脚本名称: ErrorHint
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/ErrorHint
版本: V1.0
职责: 统一错误提示显示
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

local function showHint(message)
	if type(message) ~= "string" or message == "" then
		return
	end
	local ok = pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "System",
			Text = message,
			Duration = 3,
		})
	end)
	if ok then
		return
	end
	pcall(function()
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = message,
		})
	end)
end

local function connectErrorHint()
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		return
	end
	local labubuEvents = eventsFolder:WaitForChild("LabubuEvents", 10)
	if not labubuEvents then
		return
	end
	local event = labubuEvents:WaitForChild("ErrorHint", 10)
	if not event or not event:IsA("RemoteEvent") then
		return
	end
	event.OnClientEvent:Connect(function(code, message)
		showHint(message or tostring(code))
	end)
end

connectErrorHint()
