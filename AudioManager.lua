--[[
脚本名称: AudioManager
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Modules/AudioManager
版本: V1.0
职责: BGM与音效的播放与开关控制
]]

local SoundService = game:GetService("SoundService")

local AudioManager = {}

local BGM_ID = "rbxassetid://85493154394720"
local SFX_IDS = {
	Collect = "rbxassetid://307631257",
	Unlock = "rbxassetid://3072176098",
	Warning = "rbxassetid://3072176098",
}

local state = {
	MusicEnabled = true,
	SfxEnabled = true,
}

local sounds = {
	Bgm = nil,
	Sfx = {},
}

local function getAudioFolder()
	local folder = SoundService:FindFirstChild("LabubuAudio")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LabubuAudio"
		folder.Parent = SoundService
	end
	return folder
end

local function getOrCreateSound(name, soundId, looped)
	local folder = getAudioFolder()
	local sound = folder:FindFirstChild(name)
	if sound and not sound:IsA("Sound") then
		sound:Destroy()
		sound = nil
	end
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.Parent = folder
	end
	sound.SoundId = soundId or ""
	sound.Looped = looped == true
	return sound
end

local function ensureBgm()
	local bgm = sounds.Bgm
	if not bgm or not bgm.Parent then
		bgm = getOrCreateSound("BGM", BGM_ID, true)
		sounds.Bgm = bgm
	else
		bgm.SoundId = BGM_ID
		bgm.Looped = true
	end
	return bgm
end

function AudioManager.Init(musicEnabled, sfxEnabled)
	if musicEnabled ~= nil then
		state.MusicEnabled = musicEnabled == true
	end
	if sfxEnabled ~= nil then
		state.SfxEnabled = sfxEnabled == true
	end
	if state.MusicEnabled then
		AudioManager.SetMusicEnabled(true)
	else
		local bgm = ensureBgm()
		bgm:Stop()
	end
end

function AudioManager.SetMusicEnabled(enabled)
	state.MusicEnabled = enabled == true
	local bgm = ensureBgm()
	if state.MusicEnabled then
		if not bgm.IsPlaying then
			bgm:Play()
		end
	else
		bgm:Stop()
	end
end

function AudioManager.SetSfxEnabled(enabled)
	state.SfxEnabled = enabled == true
end

function AudioManager.PlaySfx(kind)
	if not state.SfxEnabled then
		return
	end
	local soundId = SFX_IDS[kind] or kind
	if type(soundId) ~= "string" or soundId == "" then
		return
	end
	local name = "Sfx_" .. tostring(kind or "Custom")
	local sound = sounds.Sfx[name]
	if not sound or not sound.Parent then
		sound = getOrCreateSound(name, soundId, false)
		sounds.Sfx[name] = sound
	else
		sound.SoundId = soundId
	end
	sound.TimePosition = 0
	sound:Play()
end

return AudioManager
