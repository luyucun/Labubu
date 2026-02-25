--[[
脚本名称: AssetPreload
脚本类型: LocalScript
脚本位置: ReplicatedFirst/AssetPreload
版本: V2.1
职责: 快速首屏加载 - 仅阻塞关键图片与玩家数据，其余资源后台预加载
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- 常量配置
--------------------------------------------------------------------------------
local LOADING_IMAGES = {
	"rbxassetid://97379194248218",
	"rbxassetid://100148763396788",
	"rbxassetid://130504383522242",
	"rbxassetid://91249044330188",
}


-- 需要后台预加载的模型文件夹（首屏不阻塞）
local BACKGROUND_MODEL_FOLDERS = {
	"LBB",
	"Effect",
	"GuideEffect",
}

-- 首屏仅预加载 Leaf/Water（品质1/2）手办图标
local EARLY_FIGURINE_QUALITIES = {
	[1] = true, -- Leaf 品质
	[2] = true, -- Water 品质
}

-- 需要预加载的UI模板
local UI_TEMPLATES = {
	"OpenProgresTemplate",
	"CapsuleInfo",
	"InfoPart",
}

-- 超时配置
local CONFIG_WAIT_TIMEOUT = 30
local DATA_WAIT_TIMEOUT = 90
local CHARACTER_WAIT_TIMEOUT = 60

-- 进度分配
local PROGRESS_IMAGE_START = 0
local PROGRESS_IMAGE_END = 0.15
local PROGRESS_DATA_START = 0.15
local PROGRESS_DATA_END = 0.85
local PROGRESS_CHARACTER_START = 0.85
local PROGRESS_CHARACTER_END = 1.0

--------------------------------------------------------------------------------
-- 工具函数
--------------------------------------------------------------------------------
local function waitForChildSafe(parent, name, timeout)
	if not parent then
		return nil
	end
	local child = parent:FindFirstChild(name)
	if child then
		return child
	end
	local deadline = os.clock() + (timeout or 10)
	while os.clock() < deadline do
		child = parent:FindFirstChild(name)
		if child then
			return child
		end
		task.wait(0.1)
	end
	return parent:FindFirstChild(name)
end

local function isAssetId(value)
	if type(value) ~= "string" or value == "" then
		return false
	end
	return value:find("rbxassetid://") ~= nil
		or value:find("rbxasset://") ~= nil
		or value:find("roblox.com/asset") ~= nil
end

--------------------------------------------------------------------------------
-- Loading界面控制
--------------------------------------------------------------------------------
local loadingState = nil

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

local function initLoadingState()
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

local function setLoadingVisible(visible)
	if not loadingState then
		return
	end
	if loadingState.Gui and loadingState.Gui:IsA("LayerCollector") then
		loadingState.Gui.Enabled = true
	end
	if loadingState.Bg and loadingState.Bg:IsA("GuiObject") then
		loadingState.Bg.Visible = visible == true
	end
end

local function setLoadingProgress(progress)
	if not loadingState then
		return
	end
	local clamped = math.clamp(progress or 0, 0, 1)
	if loadingState.Progressbar and loadingState.Progressbar:IsA("GuiObject") then
		local size = loadingState.Progressbar.Size
		loadingState.Progressbar.Size = UDim2.new(clamped, size.X.Offset, size.Y.Scale, size.Y.Offset)
	end
	if loadingState.Number and loadingState.Number:IsA("TextLabel") then
		loadingState.Number.Text = string.format("%d%%", math.floor(clamped * 100 + 0.5))
	end
end

local function setRandomLoadingImage()
	if not loadingState or not loadingState.LoadingImage or #LOADING_IMAGES == 0 then
		return nil
	end
	if loadingState.LoadingImage:IsA("ImageLabel") or loadingState.LoadingImage:IsA("ImageButton") then
		local image = LOADING_IMAGES[math.random(1, #LOADING_IMAGES)]
		loadingState.LoadingImage.Image = image
		return image
	end
	return nil
end

local function createGuiBlocker(rootGui)
	if not rootGui then
		return nil
	end
	local states = {}
	local active = true

	local function captureAndDisable(gui)
		if not active or not gui or not gui:IsA("LayerCollector") then
			return
		end
		if gui.Name == "Loading" then
			return
		end
		if states[gui] == nil then
			states[gui] = gui.Enabled
		end
		gui.Enabled = false
	end

	for _, child in ipairs(rootGui:GetChildren()) do
		captureAndDisable(child)
	end

	local conn
	conn = rootGui.ChildAdded:Connect(function(child)
		captureAndDisable(child)
	end)

	return {
		Restore = function()
			active = false
			if conn then
				conn:Disconnect()
			end
			for gui, enabled in pairs(states) do
				if gui and gui.Parent then
					gui.Enabled = enabled
				end
			end
		end,
	}
end

local function ensureTopRightVisible()
	local names = { "TopRightGui", "TopRightGUI", "TopRight", "TopRightUI" }
	local topRight = nil
	for _, name in ipairs(names) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("LayerCollector") then
			topRight = gui
			break
		end
	end
	if not topRight then
		for _, name in ipairs(names) do
			local desc = playerGui:FindFirstChild(name, true)
			if desc and desc:IsA("LayerCollector") then
				topRight = desc
				break
			end
		end
	end
	if topRight and topRight:IsA("LayerCollector") then
		topRight.Enabled = true
		local bg = topRight:FindFirstChild("Bg", true)
		if bg and bg:IsA("GuiObject") then
			bg.Visible = true
		end
	end
end

--------------------------------------------------------------------------------
-- 资源收集
--------------------------------------------------------------------------------
local function addUniqueAsset(assets, seen, assetId)
	if type(assetId) == "string" and assetId ~= "" and isAssetId(assetId) and not seen[assetId] then
		seen[assetId] = true
		table.insert(assets, assetId)
	end
end

local function mergeAssets(baseAssets, extraAssets)
	local merged = {}
	local seen = {}
	for _, assetId in ipairs(baseAssets or {}) do
		addUniqueAsset(merged, seen, assetId)
	end
	for _, assetId in ipairs(extraAssets or {}) do
		addUniqueAsset(merged, seen, assetId)
	end
	return merged
end


-- 首屏阻塞预加载：Loading图 + Leaf/Water手办图标
local function collectBlockingImageAssets()
	local assets = {}
	local seen = {}

	for _, img in ipairs(LOADING_IMAGES) do
		addUniqueAsset(assets, seen, img)
	end

	local configFolder = waitForChildSafe(ReplicatedStorage, "Config", CONFIG_WAIT_TIMEOUT)
	if not configFolder then
		warn("[AssetPreload] Config folder not found")
		return assets
	end

	local figurineConfig = configFolder:FindFirstChild("FigurineConfig")
	if figurineConfig then
		local ok, config = pcall(require, figurineConfig)
		if ok and config and config.Figurines then
			for _, figurine in ipairs(config.Figurines) do
				local quality = tonumber(figurine.Quality) or 0
				if EARLY_FIGURINE_QUALITIES[quality] then
					addUniqueAsset(assets, seen, figurine.Icon)
				end
			end
		end
	end

	return assets
end


-- 后台预加载：其余配置图片资源
local function collectDeferredConfigAssets()
	local assets = {}
	local seen = {}

	local configFolder = waitForChildSafe(ReplicatedStorage, "Config", CONFIG_WAIT_TIMEOUT)
	if not configFolder then
		warn("[AssetPreload] Config folder not found")
		return assets
	end

	local capsuleConfig = configFolder:FindFirstChild("CapsuleConfig")
	if capsuleConfig then
		local ok, config = pcall(require, capsuleConfig)
		if ok and config and config.Capsules then
			for _, capsule in ipairs(config.Capsules) do
				addUniqueAsset(assets, seen, capsule.Icon)
				addUniqueAsset(assets, seen, capsule.DisplayImage)
			end
		end
	end

	local figurineConfig = configFolder:FindFirstChild("FigurineConfig")
	if figurineConfig then
		local ok, config = pcall(require, figurineConfig)
		if ok and config and config.Figurines then
			for _, figurine in ipairs(config.Figurines) do
				local quality = tonumber(figurine.Quality) or 0
				if not EARLY_FIGURINE_QUALITIES[quality] then
					addUniqueAsset(assets, seen, figurine.Icon)
				end
			end
		end
	end

	local qualityConfig = configFolder:FindFirstChild("QualityConfig")
	if qualityConfig then
		local ok, config = pcall(require, qualityConfig)
		if ok and config and config.Icons then
			for _, icon in pairs(config.Icons) do
				addUniqueAsset(assets, seen, icon)
			end
		end
	end

	local progressionConfig = configFolder:FindFirstChild("ProgressionConfig")
	if progressionConfig then
		local ok, config = pcall(require, progressionConfig)
		if ok and config and config.Achievements then
			for _, achievement in ipairs(config.Achievements) do
				addUniqueAsset(assets, seen, achievement.Icon)
			end
		end
	end

	return assets
end

local function collectInstanceAssets(containers)
	local assets = {}
	local seen = {}

	local function addAsset(value)
		if not isAssetId(value) or seen[value] then
			return
		end
		seen[value] = true
		table.insert(assets, value)
	end

	local function scanInstance(instance)
		-- 这里只收集图片/纹理资源，避免把模型网格也算进来。
		if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
			addAsset(instance.Image)
		elseif instance:IsA("Decal") or instance:IsA("Texture") then
			addAsset(instance.Texture)
		elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam") then
			addAsset(instance.Texture)
		end
	end

	local function scanContainer(container)
		if not container then
			return
		end
		for _, instance in ipairs(container:GetDescendants()) do
			scanInstance(instance)
		end
	end

	for _, container in ipairs(containers) do
		scanContainer(container)
	end

	return assets
end

local function collectModelInstances(folderNames, includeTemplates)
	local instances = {}
	local seen = {}

	local function addInstance(instance)
		if not instance or seen[instance] then
			return
		end
		seen[instance] = true
		table.insert(instances, instance)
	end

	-- 模型文件夹
	for _, folderName in ipairs(folderNames or {}) do
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		if folder then
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("Model") or descendant:IsA("MeshPart") or descendant:IsA("BasePart") then
					addInstance(descendant)
				end
			end
		end
	end

	-- UI模板
	if includeTemplates then
		for _, templateName in ipairs(UI_TEMPLATES) do
			local template = ReplicatedStorage:FindFirstChild(templateName)
			if template then
				addInstance(template)
				for _, descendant in ipairs(template:GetDescendants()) do
					addInstance(descendant)
				end
			end
		end
	end

	return instances
end

--------------------------------------------------------------------------------
-- 预加载执行
--------------------------------------------------------------------------------

local function preloadBatch(items, onProgress, startProgress, endProgress)
	local total = #items
	if total <= 0 then
		if onProgress then
			onProgress(endProgress)
		end
		return
	end

	local batchSize = 30
	local loaded = 0
	local progressRange = endProgress - startProgress

	local function isStringBatch(batch)
		for _, item in ipairs(batch) do
			if type(item) ~= "string" then
				return false
			end
		end
		return #batch > 0
	end

	local function preloadStringBatchWithRetry(batch)
		local pending = batch
		for attempt = 1, 3 do
			pcall(function()
				ContentProvider:PreloadAsync(pending)
			end)

			local retry = {}
			for _, contentId in ipairs(pending) do
				local ok, status = pcall(function()
					return ContentProvider:GetAssetFetchStatus(contentId)
				end)
				if not ok or status ~= Enum.AssetFetchStatus.Success then
					table.insert(retry, contentId)
				end
			end

			if #retry <= 0 then
				return
			end
			pending = retry
			task.wait(0.05 * attempt)
		end
	end

	for startIndex = 1, total, batchSize do
		local batch = {}
		for index = startIndex, math.min(total, startIndex + batchSize - 1) do
			table.insert(batch, items[index])
		end

		if isStringBatch(batch) then
			preloadStringBatchWithRetry(batch)
		else
			pcall(function()
				ContentProvider:PreloadAsync(batch)
			end)
		end

		loaded = loaded + #batch
		if onProgress then
			onProgress(startProgress + (loaded / total) * progressRange)
		end
		-- 每个批次后让出一帧，减少后台预加载造成的卡顿。
		task.wait()
	end
end

--------------------------------------------------------------------------------
-- 数据等待
--------------------------------------------------------------------------------
local function waitForPlayerData(timeout)
	local startTime = os.clock()
	local eventsFolder = waitForChildSafe(ReplicatedStorage, "Events", 10)
	if not eventsFolder then
		warn("[AssetPreload] Events folder not found")
		return false
	end

	local labubuEvents = waitForChildSafe(eventsFolder, "LabubuEvents", 10)
	if not labubuEvents then
		warn("[AssetPreload] LabubuEvents folder not found")
		return false
	end

	-- 等待PushInitData事件存在
	local pushInitData = waitForChildSafe(labubuEvents, "PushInitData", 10)

	-- 等待玩家数据就绪标记
	while os.clock() - startTime < timeout do
		if player:GetAttribute("DataReady") == true then
			return true
		end
		task.wait(0.1)
	end

	-- 超时后检查是否有角色（作为备用判断）
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		return true
	end

	warn("[AssetPreload] Timeout waiting for player data")
	return false
end

local function startPlayerDataWait(timeout)
	local done = false
	local result = false
	task.spawn(function()
		result = waitForPlayerData(timeout)
		done = true
	end)
	return function()
		while not done do
			task.wait(0.1)
		end
		return result
	end
end

local function waitForCharacter(timeout)
	local startTime = os.clock()
	while os.clock() - startTime < timeout do
		local character = player.Character
		if character and character.Parent then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoid and rootPart then
				return true
			end
		end
		task.wait(0.1)
	end
	return false
end

local function ensureCameraSubject()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
end
--------------------------------------------------------------------------------
-- 后台预加载
--------------------------------------------------------------------------------
local function startDeferredPreload()
	-- 延迟启动，避免与刚进场的玩法逻辑争用带宽与CPU。
	task.delay(1, function()
		local deferredImages = collectDeferredConfigAssets()

		-- 后台补齐UI与模板相关资源。
		local uiContainers = { StarterGui }
		for _, templateName in ipairs(UI_TEMPLATES) do
			local template = ReplicatedStorage:FindFirstChild(templateName)
			if template then
				table.insert(uiContainers, template)
			end
		end
		deferredImages = mergeAssets(deferredImages, collectInstanceAssets(uiContainers))
		preloadBatch(deferredImages, nil, 0, 1)

		-- 后台补齐模型资源（明确不含Capsule）。
		local backgroundModels = collectModelInstances(BACKGROUND_MODEL_FOLDERS, false)
		preloadBatch(backgroundModels, nil, 0, 1)
	end)
end

--------------------------------------------------------------------------------
-- 主流程
--------------------------------------------------------------------------------
local function main()
	-- 标记未完成
	player:SetAttribute("AssetsPreloaded", false)
	local guiBlocker = createGuiBlocker(playerGui)

	-- 移除默认Loading
	ReplicatedFirst:RemoveDefaultLoadingScreen()

	-- 初始化Loading界面
	math.randomseed(os.clock() * 100000)
	loadingState = initLoadingState()

	if loadingState then
		local loadingImage = setRandomLoadingImage()
		setLoadingProgress(0)
		setLoadingVisible(true)

		-- 先预加载Loading图片本身
		if loadingImage then
			pcall(function()
				ContentProvider:PreloadAsync({ loadingImage })
			end)
		end
	end

	-- 等待游戏基础加载
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	task.wait()

	local waitForDataDone = startPlayerDataWait(DATA_WAIT_TIMEOUT)


	-- 阶段1：最小阻塞资源
	local imageAssets = collectBlockingImageAssets()
	preloadBatch(imageAssets, setLoadingProgress, PROGRESS_IMAGE_START, PROGRESS_IMAGE_END)


	-- 阶段2：等待玩家数据
	setLoadingProgress(PROGRESS_DATA_START)

	if waitForDataDone then
		waitForDataDone()
	else
		waitForPlayerData(DATA_WAIT_TIMEOUT)
	end
	setLoadingProgress(PROGRESS_DATA_END)


	-- 阶段3：等待角色就绪
	setLoadingProgress(PROGRESS_CHARACTER_START)

	local characterReady = waitForCharacter(CHARACTER_WAIT_TIMEOUT)
	if characterReady then
		ensureCameraSubject()
	end

	setLoadingProgress(PROGRESS_CHARACTER_END)

	-- 完成
	task.wait(0.2) -- 短暂停留让玩家看到100%

	-- 标记完成
	player:SetAttribute("AssetsPreloaded", true)

	-- 关闭Loading界面
	if loadingState then
		setLoadingVisible(false)
	end
	if guiBlocker then
		guiBlocker.Restore()
	end
	ensureTopRightVisible()


	-- 后台补齐剩余资源
	startDeferredPreload()
end

-- 执行主流程
main()


