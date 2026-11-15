--!strict
-- Lookups and small animations for the ScreenGuis built in Studio (StarterGui), shared by the
-- controllers so every button and popup moves the same way.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local WAIT_SECONDS = 10
local PRESS_SCALE = 0.9
local PRESS_INFO = TweenInfo.new(0.08)
local RELEASE_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local BOUNCE_SCALE = 1.25
local BOUNCE_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_IN_START = 0.6
local POP_IN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FLOAT_INFO = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FLOAT_RISE = UDim2.fromOffset(0, -50)

local Gui = {}

function Gui.waitFor(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, WAIT_SECONDS)
	assert(child, `Gui: {parent:GetFullName()}.{name} is missing`)
	return child
end

function Gui.screen(name: string): ScreenGui
	local playerGui = Gui.waitFor(Players.LocalPlayer, "PlayerGui")
	return Gui.waitFor(playerGui, name) :: ScreenGui
end

-- nil while the local character is dead or not spawned yet.
function Gui.localRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function scaleOf(object: GuiObject): UIScale
	local scale = object:FindFirstChildOfClass("UIScale")
	if scale then
		return scale
	end
	local created = Instance.new("UIScale")
	created.Parent = object
	return created
end

-- Squash on press, spring back on release: buttons feel physical on touch screens.
function Gui.bindPress(button: GuiButton)
	local scale = scaleOf(button)
	local function release()
		TweenService:Create(scale, RELEASE_INFO, { Scale = 1 }):Play()
	end
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, PRESS_INFO, { Scale = PRESS_SCALE }):Play()
	end)
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

function Gui.bounce(object: GuiObject)
	local scale = scaleOf(object)
	scale.Scale = BOUNCE_SCALE
	TweenService:Create(scale, BOUNCE_INFO, { Scale = 1 }):Play()
end

function Gui.popIn(object: GuiObject)
	local scale = scaleOf(object)
	scale.Scale = POP_IN_START
	TweenService:Create(scale, POP_IN_INFO, { Scale = 1 }):Play()
end

-- Clones a hidden template label, floats it up and fades it out.
function Gui.floatText(template: TextLabel, text: string, color: Color3?)
	local label = template:Clone()
	label.Text = text
	if color then
		label.TextColor3 = color
	end
	label.Visible = true
	label.Parent = template.Parent
	local tween = TweenService:Create(label, FLOAT_INFO, {
		Position = label.Position + FLOAT_RISE,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, FLOAT_INFO, { Transparency = 1 }):Play()
	end
	tween.Completed:Once(function()
		label:Destroy()
	end)
	tween:Play()
end

return Gui
