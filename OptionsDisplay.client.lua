--[[
脚本名称: OptionsDisplay
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/UI/OptionsDisplay
版本: V1.0
职责: 音效/BGM开关设置与音效播放监听
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local AudioManager = require(modulesFolder:WaitForChild("AudioManager"))
local GuiResolver = require(modulesFolder:WaitForChild("GuiResolver"))

local COLOR_ON_START = Color3.fromRGB(0x55, 0xFF, 0x00)
local COLOR_ON_END = Color3.fromRGB(0xFF, 0xFF, 0x00)
local COLOR_OFF_START = Color3.fromRGB(0xCB, 0x00, 0x0E)
local COLOR_OFF_END = Color3.fromRGB(0xFF, 0x5D, 0x35)

local function getEvent(name)
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		return nil
	end
	local labubuEvents = eventsFolder:WaitForChild("LabubuEvents", 10)
	if not labubuEvents then
		return nil
	end
	local event = labubuEvents:WaitForChild(name, 10)
	if event and event:IsA("RemoteEvent") then
		return event
	end
	return nil
end

local updateAudioSettingsEvent = getEvent("UpdateAudioSettings")
if not updateAudioSettingsEvent then
	warn("[OptionsDisplay] UpdateAudioSettings event not found")
end

local playSfxEvent = getEvent("PlaySfx")
if playSfxEvent then
	playSfxEvent.OnClientEvent:Connect(function(kind)
		AudioManager.PlaySfx(kind)
	end)
else
	warn("[OptionsDisplay] PlaySfx event not found")
end

local function getBoolAttribute(name, defaultValue)
	local value = player:GetAttribute(name)
	if value == nil then
		return defaultValue == true
	end
	return value == true
end

local musicEnabled = getBoolAttribute("MusicEnabled", true)
local sfxEnabled = getBoolAttribute("SfxEnabled", true)

AudioManager.Init(musicEnabled, sfxEnabled)

local function applyToggleVisual(toggle, enabled)
	if not toggle then
		return
	end
	if toggle.Label and toggle.Label:IsA("TextLabel") then
		toggle.Label.Text = enabled and "On" or "Off"
	end
	if toggle.Gradient and toggle.Gradient:IsA("UIGradient") then
		local startColor = enabled and COLOR_ON_START or COLOR_OFF_START
		local endColor = enabled and COLOR_ON_END or COLOR_OFF_END
		toggle.Gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, startColor),
			ColorSequenceKeypoint.new(1, endColor),
		})
	end
end

local function syncServerSettings()
	if updateAudioSettingsEvent then
		updateAudioSettingsEvent:FireServer(musicEnabled, sfxEnabled)
	end
end

local musicToggle
local sfxToggle

local function setMusicEnabled(enabled, fromServer)
	musicEnabled = enabled == true
	AudioManager.SetMusicEnabled(musicEnabled)
	applyToggleVisual(musicToggle, musicEnabled)
	if not fromServer then
		syncServerSettings()
	end
end

local function setSfxEnabled(enabled, fromServer)
	sfxEnabled = enabled == true
	AudioManager.SetSfxEnabled(sfxEnabled)
	applyToggleVisual(sfxToggle, sfxEnabled)
	if not fromServer then
		syncServerSettings()
	end
end

player:GetAttributeChangedSignal("MusicEnabled"):Connect(function()
	local value = player:GetAttribute("MusicEnabled")
	if value == nil then
		return
	end
	setMusicEnabled(value == true, true)
end)

player:GetAttributeChangedSignal("SfxEnabled"):Connect(function()
	local value = player:GetAttribute("SfxEnabled")
	if value == nil then
		return
	end
	setSfxEnabled(value == true, true)
end)

local function resolveToggle(bg, name)
	if not bg then
		return nil
	end
	local group = bg:FindFirstChild(name)
	if not group then
		return nil
	end
	local button = group:FindFirstChild("CloseButton")
	if button and not button:IsA("GuiButton") then
		button = button:FindFirstChildWhichIsA("GuiButton", true)
	end
	if button and not button:IsA("GuiButton") then
		button = nil
	end
	local label = button and button:FindFirstChild("Text") or nil
	if label and not label:IsA("TextLabel") then
		label = nil
	end
	local gradient = button and button:FindFirstChild("UIGradient") or nil
	if gradient and not gradient:IsA("UIGradient") then
		gradient = nil
	end
	return {
		Button = button,
		Label = label,
		Gradient = gradient,
	}
end

local topRightGui = GuiResolver.WaitForLayer(playerGui, { "TopRightGui", "TopRightGUI", "TopRight", "TopRightUI" }, {
	"Options",
	"Invite",
	"Learderboard",
	"Leaderboard",
}, 30)
if not topRightGui then
	warn("[OptionsDisplay] TopRightGui not found")
end

local optionsButton
if topRightGui then
	local topBg = topRightGui:FindFirstChild("Bg")
	if topBg then
		optionsButton = GuiResolver.FindGuiButton(topBg, "Options")
	end
end
if not optionsButton then
	optionsButton = GuiResolver.FindGuiButton(playerGui, "Options")
end

local optionsGui = GuiResolver.WaitForLayer(playerGui, { "Options", "OptionsGui", "OptionsGUI" }, {
	"Music",
	"Sfx",
}, 30)
if not optionsGui then
	warn("[OptionsDisplay] Options gui not found")
end

local optionsBg = optionsGui and optionsGui:FindFirstChild("Bg")
if not optionsBg then
	optionsBg = optionsGui and optionsGui:WaitForChild("Bg", 10) or nil
end
if not optionsBg then
	warn("[OptionsDisplay] Options.Bg not found")
end

local closeButton
if optionsBg then
	local title = optionsBg:FindFirstChild("Title")
	local closeNode = title and title:FindFirstChild("CloseButton") or nil
	if closeNode and not closeNode:IsA("GuiButton") then
		closeNode = closeNode:FindFirstChildWhichIsA("GuiButton", true)
	end
	if closeNode and closeNode:IsA("GuiButton") then
		closeButton = closeNode
	end
end

if optionsBg then
	musicToggle = resolveToggle(optionsBg, "Music")
	sfxToggle = resolveToggle(optionsBg, "Sfx")
end

if optionsButton and optionsBg and optionsBg:IsA("GuiObject") then
	optionsButton.Activated:Connect(function()
		optionsBg.Visible = true
	end)
end

if closeButton and optionsBg and optionsBg:IsA("GuiObject") then
	closeButton.Activated:Connect(function()
		optionsBg.Visible = false
	end)
end

if musicToggle and musicToggle.Button then
	musicToggle.Button.Activated:Connect(function()
		setMusicEnabled(not musicEnabled, false)
	end)
end

if sfxToggle and sfxToggle.Button then
	sfxToggle.Button.Activated:Connect(function()
		setSfxEnabled(not sfxEnabled, false)
	end)
end

applyToggleVisual(musicToggle, musicEnabled)
applyToggleVisual(sfxToggle, sfxEnabled)
