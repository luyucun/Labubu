--[[
脚本名称: BackpackVisibility
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Modules/BackpackVisibility
版本: V1.0
职责: 统一管理背包隐藏计数与显示状态
]]

local StarterGui = game:GetService("StarterGui")

local BackpackVisibility = {}

local SOURCE_PREFIX = "BackpackHideSource_"

local function setCoreBackpackEnabled(enabled)
	local ok, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
	end)
	if not ok then
		warn(string.format("[BackpackVisibility] SetCoreGuiEnabled failed: %s", tostring(err)))
	end
end

local function getCoreBackpackEnabled()
	local ok, result = pcall(function()
		return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
	end)
	if ok then
		return result
	end
	return nil
end

local function getHideCounter(playerGui)
	local counter = playerGui:FindFirstChild("BackpackHideCount")
	if not counter then
		counter = Instance.new("IntValue")
		counter.Name = "BackpackHideCount"
		counter.Value = 0
		counter.Parent = playerGui
	end
	return counter
end

local function computeHideCount(playerGui)
	local count = 0
	for name, value in pairs(playerGui:GetAttributes()) do
		if value == true and string.sub(name, 1, #SOURCE_PREFIX) == SOURCE_PREFIX then
			count += 1
		end
	end
	return count
end

local function applyVisibility(playerGui, prevCount, newCount)
	local backpackGui = playerGui:FindFirstChild("BackpackGui")
	if newCount > 0 then
		if backpackGui then
			backpackGui:SetAttribute("BackpackForceHidden", true)
			if backpackGui:IsA("LayerCollector") then
				backpackGui.Enabled = false
			end
		end
		if prevCount <= 0 then
			local corePrev = getCoreBackpackEnabled()
			if type(corePrev) == "boolean" then
				playerGui:SetAttribute("BackpackHideCorePrev", corePrev)
			end
			if backpackGui and backpackGui:IsA("LayerCollector") then
				playerGui:SetAttribute("BackpackHideGuiPrev", backpackGui.Enabled)
			end
			setCoreBackpackEnabled(false)
		end
	else
		if prevCount > 0 then
			local corePrev = playerGui:GetAttribute("BackpackHideCorePrev")
			if type(corePrev) == "boolean" then
				setCoreBackpackEnabled(corePrev)
			end
			if backpackGui and backpackGui:IsA("LayerCollector") then
				local guiPrev = playerGui:GetAttribute("BackpackHideGuiPrev")
				if type(guiPrev) == "boolean" then
					backpackGui.Enabled = guiPrev
				else
					backpackGui.Enabled = true
				end
			end
			playerGui:SetAttribute("BackpackHideCorePrev", nil)
			playerGui:SetAttribute("BackpackHideGuiPrev", nil)
		end
		if backpackGui then
			backpackGui:SetAttribute("BackpackForceHidden", false)
		end
	end
end

function BackpackVisibility.Reconcile(playerGui)
	if not playerGui then
		return
	end
	local counter = getHideCounter(playerGui)
	local prevCount = counter.Value
	local newCount = computeHideCount(playerGui)
	counter.Value = newCount
	applyVisibility(playerGui, prevCount, newCount)
end

function BackpackVisibility.SetHidden(playerGui, source, hidden)
	if not playerGui or type(source) ~= "string" or source == "" then
		return
	end
	local attrName = SOURCE_PREFIX .. source
	local current = playerGui:GetAttribute(attrName) == true
	local target = hidden == true
	if current == target then
		return
	end
	playerGui:SetAttribute(attrName, target)
	BackpackVisibility.Reconcile(playerGui)
end

return BackpackVisibility
