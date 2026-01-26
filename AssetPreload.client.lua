--[[
脚本名称: AssetPreload
脚本类型: LocalScript
脚本位置: ReplicatedFirst/AssetPreload
版本: V1.1
职责: 进入游戏前预加载所有图片资源
]]

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPack = game:GetService("StarterPack")
local StarterPlayer = game:GetService("StarterPlayer")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

local LOADING_IMAGES = {
	"rbxassetid://97379194248218",
	"rbxassetid://100148763396788",
	"rbxassetid://130504383522242",
	"rbxassetid://91249044330188",
}

local function resolveLoadingGui()
	local loadingGui = playerGui:FindFirstChild("Loading")
	if not loadingGui then
		loadingGui = playerGui:WaitForChild("Loading", 5)
	end
	if not loadingGui then
		local template = StarterGui:FindFirstChild("Loading")
		if template and template:IsA("ScreenGui") then
			loadingGui = template:Clone()
			loadingGui.ResetOnSpawn = false
			loadingGui.Parent = playerGui
		end
	end
	return loadingGui
end

local function resolveLoadingState()
	local loadingGui = resolveLoadingGui()
	if not loadingGui then
		return nil
	end
	local bg = loadingGui:FindFirstChild("Bg", true)
	local loadingImage = bg and bg:FindFirstChild("LoadingImage", true)
	local progressBg = bg and bg:FindFirstChild("ProgressBg", true)
	local progressBar = progressBg and progressBg:FindFirstChild("Progressbar", true)
	local numberLabel = progressBg and progressBg:FindFirstChild("Number", true)
	return {
		Gui = loadingGui,
		Bg = bg,
		LoadingImage = loadingImage,
		Progressbar = progressBar,
		Number = numberLabel,
	}
end

local function setLoadingVisible(state, visible)
	if not state then
		return
	end
	if state.Gui and state.Gui:IsA("LayerCollector") then
		state.Gui.Enabled = true
	end
	if state.Bg and state.Bg:IsA("GuiObject") then
		state.Bg.Visible = visible == true
	end
end

local function setLoadingProgress(state, progress)
	if not state then
		return
	end
	local clamped = math.clamp(progress or 0, 0, 1)
	if state.Progressbar and state.Progressbar:IsA("GuiObject") then
		local size = state.Progressbar.Size
		state.Progressbar.Size = UDim2.new(clamped, size.X.Offset, size.Y.Scale, size.Y.Offset)
	end
	if state.Number and state.Number:IsA("TextLabel") then
		state.Number.Text = string.format("%d%%", math.floor(clamped * 100 + 0.5))
	end
end

local function setRandomLoadingImage(state)
	if not state or not state.LoadingImage or #LOADING_IMAGES == 0 then
		return nil
	end
	if state.LoadingImage:IsA("ImageLabel") or state.LoadingImage:IsA("ImageButton") then
		local image = LOADING_IMAGES[math.random(1, #LOADING_IMAGES)]
		state.LoadingImage.Image = image
		return image
	end
	return nil
end

local function preloadLoadingImage(image)
	if type(image) ~= "string" or image == "" then
		return
	end
	pcall(function()
		ContentProvider:PreloadAsync({ image })
	end)
end

local function setPreloadState(ready)
	if player and player.Parent then
		player:SetAttribute("AssetsPreloaded", ready == true)
	end
end

local function isAssetId(value)
	if type(value) ~= "string" or value == "" then
		return false
	end
	if value:find("rbxassetid://") then
		return true
	end
	if value:find("rbxasset://") then
		return true
	end
	if value:find("http://www.roblox.com/asset") or value:find("https://www.roblox.com/asset") then
		return true
	end
	return false
end

local function collectAssetsFromConfigs(assets, seen)
	local configFolder = ReplicatedStorage:WaitForChild("Config")
	local visited = {}
	local function scanTable(value)
		if type(value) ~= "table" then
			if isAssetId(value) and not seen[value] then
				seen[value] = true
				table.insert(assets, value)
			end
			return
		end
		if visited[value] then
			return
		end
		visited[value] = true
		for _, child in pairs(value) do
			scanTable(child)
		end
	end
	for _, module in ipairs(configFolder:GetChildren()) do
		if module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			if ok then
				scanTable(result)
			end
		end
	end
end

local function collectAssetsFromInstances(assets, seen)
	assets = assets or {}
	seen = seen or {}
	local function addAsset(value)
		if not isAssetId(value) then
			return
		end
		if seen[value] then
			return
		end
		seen[value] = true
		table.insert(assets, value)
	end

	local function addFromInstance(instance)
		if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
			addAsset(instance.Image)
		elseif instance:IsA("Decal") or instance:IsA("Texture") then
			addAsset(instance.Texture)
		elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam") then
			addAsset(instance.Texture)
		elseif instance:IsA("MeshPart") then
			addAsset(instance.TextureID)
			addAsset(instance.MeshId)
		elseif instance:IsA("SpecialMesh") then
			addAsset(instance.MeshId)
			addAsset(instance.TextureId)
		elseif instance:IsA("SurfaceAppearance") then
			addAsset(instance.ColorMap)
			addAsset(instance.MetalnessMap)
			addAsset(instance.NormalMap)
			addAsset(instance.RoughnessMap)
		elseif instance:IsA("Sky") then
			addAsset(instance.SkyboxBk)
			addAsset(instance.SkyboxDn)
			addAsset(instance.SkyboxFt)
			addAsset(instance.SkyboxLf)
			addAsset(instance.SkyboxRt)
			addAsset(instance.SkyboxUp)
		end
	end

	local function scan(container)
		if not container then
			return
		end
		for _, instance in ipairs(container:GetDescendants()) do
			addFromInstance(instance)
		end
	end

	scan(ReplicatedStorage)
	scan(StarterGui)
	scan(StarterPlayer)
	scan(StarterPack)
	scan(Lighting)
	scan(workspace)
	scan(playerGui)

	return assets
end

local function resolveModelResource(modelRoot, resource)
	if not modelRoot or type(resource) ~= "string" or resource == "" then
		return nil
	end
	local current = modelRoot
	for _, segment in ipairs(string.split(resource, "/")) do
		if segment ~= "" then
			current = current:FindFirstChild(segment)
			if not current then
				return nil
			end
		end
	end
	return current
end

local function collectPreloadInstances(instances, seenInstances)
	if type(instances) ~= "table" then
		return
	end
	seenInstances = seenInstances or {}
	local function addInstance(instance)
		if not instance or seenInstances[instance] then
			return
		end
		seenInstances[instance] = true
		table.insert(instances, instance)
	end

	local modelRoot = ReplicatedStorage:FindFirstChild("LBB")
	local configModule = ReplicatedStorage:FindFirstChild("Config")
	configModule = configModule and configModule:FindFirstChild("FigurineConfig")
	if not modelRoot or not configModule then
		return
	end

	local ok, config = pcall(require, configModule)
	if not ok then
		return
	end

	local list = config.Figurines or config
	if type(list) ~= "table" then
		return
	end

	for _, info in ipairs(list) do
		local resource = info and (info.ModelResource or info.ModelName)
		local source = resolveModelResource(modelRoot, resource)
		if source then
			addInstance(source)
		end
	end
end

local function preloadAssets(assets, onProgress)
	local batchSize = 40
	local total = #assets
	if total <= 0 then
		if onProgress then
			onProgress(1, 1)
		end
		return true
	end
	local loaded = 0
	for startIndex = 1, total, batchSize do
		local batch = {}
		for index = startIndex, math.min(total, startIndex + batchSize - 1) do
			table.insert(batch, assets[index])
		end
		local ok = pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)
		if ok then
			loaded += #batch
			if onProgress then
				onProgress(loaded, total)
			end
		else
			for _, asset in ipairs(batch) do
				pcall(function()
					ContentProvider:PreloadAsync({ asset })
				end)
				loaded += 1
				if onProgress then
					onProgress(loaded, total)
				end
			end
		end
	end
	return true
end

setPreloadState(false)
if script.Parent ~= ReplicatedFirst then
	warn("[AssetPreload] Script should be placed under ReplicatedFirst.")
end
ReplicatedFirst:RemoveDefaultLoadingScreen()

math.randomseed(os.clock() * 100000)
local loadingState = resolveLoadingState()
local selectedLoadingImage = nil
if loadingState then
	selectedLoadingImage = setRandomLoadingImage(loadingState)
	setLoadingProgress(loadingState, 0)
	setLoadingVisible(loadingState, true)
	preloadLoadingImage(selectedLoadingImage)
end

local allAssets = {}
local seen = {}
collectAssetsFromConfigs(allAssets, seen)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

task.wait()

collectAssetsFromInstances(allAssets, seen)
collectPreloadInstances(allAssets, {})

local function updateProgress(loaded, total)
	if not loadingState then
		return
	end
	if total <= 0 then
		setLoadingProgress(loadingState, 1)
		return
	end
	setLoadingProgress(loadingState, loaded / total)
end

preloadAssets(allAssets, updateProgress)
if loadingState then
	setLoadingProgress(loadingState, 1)
	setLoadingVisible(loadingState, false)
end

setPreloadState(true)
