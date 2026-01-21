--[[
脚本名称: ButtonPressEffect
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Modules/ButtonPressEffect
版本: V1.0
职责: 统一按钮按下缩放效果
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ButtonPressEffect = {}
ButtonPressEffect.DefaultPressScale = 0.92
ButtonPressEffect.DefaultTweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local buttonStates = setmetatable({}, { __mode = "k" })
local activeInputs = {}
local globalInputBound = false

local function getPressScale(button)
	local scale = button:FindFirstChild("PressScale")
	if not (scale and scale:IsA("UIScale")) then
		scale = Instance.new("UIScale")
		scale.Name = "PressScale"
		scale.Scale = 1
		scale.Parent = button
	end
	return scale
end

local function getState(button, options)
	local state = buttonStates[button]
	if state then
		return state
	end

	local scale = getPressScale(button)
	state = {
		Scale = scale,
		BaseScale = scale.Scale,
		PressScale = ButtonPressEffect.DefaultPressScale,
		TweenInfo = ButtonPressEffect.DefaultTweenInfo,
		PressedCount = 0,
	}
	if options then
		if type(options.PressScale) == "number" then
			state.PressScale = options.PressScale
		end
		if typeof(options.TweenInfo) == "TweenInfo" then
			state.TweenInfo = options.TweenInfo
		end
	end
	buttonStates[button] = state
	return state
end

local function applyScale(state, factor)
	local scale = state.Scale
	if not scale then
		return
	end
	local target = state.BaseScale * factor
	TweenService:Create(scale, state.TweenInfo, { Scale = target }):Play()
end

local function releaseInput(input)
	local button = activeInputs[input]
	if not button then
		return
	end
	activeInputs[input] = nil
	local state = buttonStates[button]
	if not state then
		return
	end
	state.PressedCount = math.max(0, state.PressedCount - 1)
	if state.PressedCount == 0 then
		applyScale(state, 1)
	end
end

local function ensureGlobalInputEnded()
	if globalInputBound then
		return
	end
	globalInputBound = true
	UserInputService.InputEnded:Connect(releaseInput)
end

local function shouldHandleInput(input)
	local inputType = input.UserInputType
	return inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch
end

function ButtonPressEffect.BindButton(button, options)
	if not button or not button:IsA("GuiButton") then
		return
	end
	if buttonStates[button] then
		return
	end

	local state = getState(button, options)
	ensureGlobalInputEnded()

	button.InputBegan:Connect(function(input)
		if not shouldHandleInput(input) then
			return
		end
		state.PressedCount += 1
		activeInputs[input] = button
		applyScale(state, state.PressScale)
	end)

	button.InputEnded:Connect(releaseInput)
	button.AncestryChanged:Connect(function(_, parent)
		if not parent then
			buttonStates[button] = nil
		end
	end)
end

function ButtonPressEffect.BindToRoot(root, options)
	if not root then
		return
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			ButtonPressEffect.BindButton(descendant, options)
		end
	end
	root.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("GuiButton") then
			ButtonPressEffect.BindButton(descendant, options)
		end
	end)
end

return ButtonPressEffect
