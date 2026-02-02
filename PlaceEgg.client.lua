--[[
脚本名称: PlaceEgg
脚本类型: LocalScript
脚本位置: StarterPlayer/StarterPlayerScripts/PlaceEgg
版本: V1.0
职责: 盲盒放置时上报点击位置
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local function getPlaceEggEvent()
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		return nil
	end
	local labubuEvents = eventsFolder:WaitForChild("LabubuEvents", 10)
	if not labubuEvents then
		return nil
	end
	local event = labubuEvents:WaitForChild("PlaceEgg", 10)
	if event and event:IsA("RemoteEvent") then
		return event
	end
	return nil
end

local placeEggEvent = getPlaceEggEvent()
if not placeEggEvent then
	warn("[PlaceEgg] PlaceEgg event not found")
	return
end

local function getFootWorldPosition()
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not root then
		return nil
	end
	return root.Position
end

local toolConnections = {}

local function bindTool(tool)
	if toolConnections[tool] then
		return
	end
	if not tool:IsA("Tool") then
		return
	end
	if tool:GetAttribute("CapsuleId") == nil then
		return
	end

	toolConnections[tool] = tool.Activated:Connect(function()
		local position = getFootWorldPosition()
		if not position then
			return
		end
		local capsuleId = tool:GetAttribute("CapsuleId")
		if capsuleId == nil then
			return
		end
		placeEggEvent:FireServer(capsuleId, position)
	end)

	tool.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end
		local conn = toolConnections[tool]
		if conn then
			conn:Disconnect()
			toolConnections[tool] = nil
		end
	end)
end

local function bindContainer(container)
	if not container then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		bindTool(child)
	end
	container.ChildAdded:Connect(bindTool)
end

local backpack = player:WaitForChild("Backpack")
bindContainer(backpack)

local function onCharacterAdded(character)
	bindContainer(character)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
