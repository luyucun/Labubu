--[[
脚本名称: AssetPreload
脚本类型: LocalScript
脚本位置: ReplicatedFirst/AssetPreload
版本: V1.4
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

-- 需要预加载的模型文件夹列表
local MODEL_FOLDERS = {
	"LBB",      -- 手办模型
	"Capsule",  -- 盲盒模型
	"Effect",   -- 特效
}

local CONFIG_WAIT_SECONDS = 30
local MODEL_FOLDER_WAIT_SECONDS = 30
local WAIT_INTERVAL_SECONDS = 0.2

local function waitForChildSafe(parent, name, timeoutSeconds)
	if not parent then
		return nil
	end
	local child = parent:FindFirstChild(name)
	if child then
		return child
	end
	local timeout = tonumber(timeoutSeconds) or 0
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		child = parent:FindFirstChild(name)
		if child then
			return child
		end
		task.wait(WAIT_INTERVAL_SECONDS)
	end
	return parent:FindFirstChild(name)
end

local function waitForModelFolders()
	for _, folderName in ipairs(MODEL_FOLDERS) do
		local folder = waitForChildSafe(ReplicatedStorage, folderName, MODEL_FOLDER_WAIT_SECONDS)
		if not folder then
			warn("[AssetPreload] Model folder not found: " .. tostring(folderName))
		end
	end
end

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
	local configFolder = waitForChildSafe(ReplicatedStorage, "Config", CONFIG_WAIT_SECONDS)
	if not configFolder then
		warn("[AssetPreload] Config folder not found in ReplicatedStorage")
		return
	end

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
			if ok and result then
				scanTable(result)
			end
		end
	end
end

-- 手动收集所有已知的图片资源（确保不遗漏）
local function collectKnownAssets(assets, seen)
	local function addAsset(assetId)
		if type(assetId) == "string" and assetId ~= "" and not seen[assetId] then
			seen[assetId] = true
			table.insert(assets, assetId)
		end
	end

	local configFolder = waitForChildSafe(ReplicatedStorage, "Config", CONFIG_WAIT_SECONDS)
	if not configFolder then
		warn("[AssetPreload] Config folder not found in ReplicatedStorage")
		return
	end

	-- Loading图片
	for _, img in ipairs(LOADING_IMAGES) do
		addAsset(img)
	end

	-- 从CapsuleConfig收集
	local capsuleConfig = configFolder:FindFirstChild("CapsuleConfig")
	if capsuleConfig then
		local ok, config = pcall(require, capsuleConfig)
		if ok and config and config.Capsules then
			for _, capsule in ipairs(config.Capsules) do
				addAsset(capsule.Icon)
				addAsset(capsule.DisplayImage)
			end
		end
	end

	-- 从FigurineConfig收集
	local figurineConfig = configFolder:FindFirstChild("FigurineConfig")
	if figurineConfig then
		local ok, config = pcall(require, figurineConfig)
		if ok and config and config.Figurines then
			for _, figurine in ipairs(config.Figurines) do
				addAsset(figurine.Icon)
			end
		end
	end

	-- 从QualityConfig收集
	local qualityConfig = configFolder:FindFirstChild("QualityConfig")
	if qualityConfig then
		local ok, config = pcall(require, qualityConfig)
		if ok and config and config.Icons then
			for _, icon in pairs(config.Icons) do
				addAsset(icon)
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

-- 收集模型实例用于预加载（返回实例数组，与资源字符串分开处理）
local function collectModelInstances()
	local instances = {}
	local seen = {}

	local function addInstance(instance)
		if not instance or seen[instance] then
			return
		end
		seen[instance] = true
		table.insert(instances, instance)
	end

	-- 遍历所有模型文件夹
	for _, folderName in ipairs(MODEL_FOLDERS) do
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		if folder then
			-- 添加文件夹下所有模型
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("Model") or descendant:IsA("MeshPart") or descendant:IsA("BasePart") then
					addInstance(descendant)
				end
			end
		end
	end

	-- 预加载UI模板
	local templates = {
		"OpenProgresTemplate",
		"CapsuleInfo",
		"InfoPart",
	}
	for _, templateName in ipairs(templates) do
		local template = ReplicatedStorage:FindFirstChild(templateName)
		if template then
			addInstance(template)
		end
	end

	return instances
end

local function preloadAssets(assets, onProgress, startProgress, endProgress)
	startProgress = startProgress or 0
	endProgress = endProgress or 1
	local batchSize = 40
	local total = #assets
	if total <= 0 then
		if onProgress then
			onProgress(endProgress)
		end
		return true
	end
	local loaded = 0
	local progressRange = endProgress - startProgress
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
				onProgress(startProgress + (loaded / total) * progressRange)
			end
		else
			for _, asset in ipairs(batch) do
				pcall(function()
					ContentProvider:PreloadAsync({ asset })
				end)
				loaded += 1
				if onProgress then
					onProgress(startProgress + (loaded / total) * progressRange)
				end
			end
		end
	end
	return true
end

-- 预加载实例（模型等）
local function preloadInstances(instances, onProgress, startProgress, endProgress)
	startProgress = startProgress or 0
	endProgress = endProgress or 1
	local total = #instances
	if total <= 0 then
		if onProgress then
			onProgress(endProgress)
		end
		return true
	end
	local loaded = 0
	local progressRange = endProgress - startProgress
	local batchSize = 10
	for startIndex = 1, total, batchSize do
		local batch = {}
		for index = startIndex, math.min(total, startIndex + batchSize - 1) do
			table.insert(batch, instances[index])
		end
		pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)
		loaded += #batch
		if onProgress then
			onProgress(startProgress + (loaded / total) * progressRange)
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

-- 收集所有图片资源ID
local allAssets = {}
local seen = {}

-- 1. 手动收集已知配置中的图片资源（最可靠）
collectKnownAssets(allAssets, seen)

-- 2. 从配置表递归收集资源（补充）
collectAssetsFromConfigs(allAssets, seen)

-- 3. 等待游戏加载完成
if not game:IsLoaded() then
	game.Loaded:Wait()
end
task.wait()

-- 4. 从实例中收集图片资源
waitForModelFolders()
collectAssetsFromInstances(allAssets, seen)

-- 5. 收集模型实例（单独处理）
local modelInstances = collectModelInstances()

-- 输出调试信息
print("[AssetPreload] Collected " .. #allAssets .. " image assets, " .. #modelInstances .. " model instances")

-- 进度回调
local function updateProgress(progress)
	if not loadingState then
		return
	end
	setLoadingProgress(loadingState, progress)
end

-- 分阶段预加载：
-- 阶段1: 图片资源 (0% - 60%)
-- 阶段2: 模型实例 (60% - 100%)
preloadAssets(allAssets, updateProgress, 0, 0.6)
preloadInstances(modelInstances, updateProgress, 0.6, 1)

if loadingState then
	setLoadingProgress(loadingState, 1)
	task.wait(0.2) -- 短暂停留让玩家看到100%
	setLoadingVisible(loadingState, false)
end

setPreloadState(true)
