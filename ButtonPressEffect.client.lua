--[[
脚本名称: ButtonPressEffect
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/ButtonPressEffect
版本: V1.0
职责: 统一为所有按钮绑定按下缩放效果
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local modules = ReplicatedStorage:WaitForChild("Modules")
local ButtonPressEffect = require(modules:WaitForChild("ButtonPressEffect"))

ButtonPressEffect.BindToRoot(playerGui)
