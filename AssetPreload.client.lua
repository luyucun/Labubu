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

local function createLoadingGui()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PreloadGui"
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 10000
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.Parent = playerGui

	local blocker = Instance.new("TextButton")
	blocker.Name = "Blocker"
	blocker.BackgroundColor3 = Color3.new(0, 0, 0)
	blocker.BackgroundTransparency = 0
	blocker.Text = ""
	blocker.AutoButtonColor = false
	blocker.Active = true
	blocker.Selectable = true
	blocker.Size = UDim2.new(1, 0, 1, 0)
	blocker.Position = UDim2.new(0, 0, 0, 0)
	blocker.ZIndex = 10000
	blocker.Parent = screenGui

	local label = Instance.new("TextLabel")
	label.Name = "LoadingText"
	label.BackgroundTransparency = 1
	label.Text = "Loading..."
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 24
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, 0.5, 0)
	label.Size = UDim2.new(0, 240, 0, 50)
	label.ZIndex = 10001
	label.Parent = blocker

	return screenGui
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

local function preloadAssets(assets)
	local batchSize = 60
	local total = #assets
	if total <= 0 then
		return true
	end
	for startIndex = 1, total, batchSize do
		local batch = {}
		for index = startIndex, math.min(total, startIndex + batchSize - 1) do
			table.insert(batch, assets[index])
		end
		local ok = pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)
		if not ok then
			for _, asset in ipairs(batch) do
				pcall(function()
					ContentProvider:PreloadAsync({ asset })
				end)
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

local loadingGui = createLoadingGui()

local configAssets = {}
local seen = {}
collectAssetsFromConfigs(configAssets, seen)
if #configAssets > 0 then
	preloadAssets(configAssets)
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

task.wait()

local instanceAssets = {}
collectAssetsFromInstances(instanceAssets, seen)
if #instanceAssets > 0 then
	preloadAssets(instanceAssets)
end

if loadingGui then
	loadingGui:Destroy()
end

setPreloadState(true)
