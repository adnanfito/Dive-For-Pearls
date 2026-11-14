--!strict
-- Renders the dive HUD (StarterGui.DiveGui, built in Studio) from the state the server sends, and
-- sends the Up request. At the Depth Limit it floats the diver back up so the limit feels smooth;
-- the server enforces the same limit on its own.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gui = require("../Gui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local LOW_OXYGEN_FRACTION = 0.2 -- GDD: the oxygen warning starts at 20%
local PRESSURE_MESSAGE_SECONDS = 1.5
local OXYGEN_COLOR = Color3.fromRGB(80, 190, 255)
local LOW_OXYGEN_COLOR = Color3.fromRGB(230, 70, 70)

type Ui = {
	gui: ScreenGui,
	oxygenFill: GuiObject,
	oxygenLabel: TextLabel,
	depthLabel: TextLabel,
	shellLabel: TextLabel,
	fullIcon: GuiObject,
	pressureLabel: GuiObject,
	upButton: GuiButton,
}

local DiveController = {}

local function findUi(): Ui
	local gui = Gui.screen("DiveGui")
	local top = Gui.waitFor(gui, "Top")
	local bar = Gui.waitFor(top, "OxygenBar")
	local shellPanel = Gui.waitFor(gui, "ShellPanel")
	return {
		gui = gui,
		oxygenFill = Gui.waitFor(bar, "Fill") :: GuiObject,
		oxygenLabel = Gui.waitFor(bar, "Label") :: TextLabel,
		depthLabel = Gui.waitFor(top, "DepthLabel") :: TextLabel,
		shellLabel = Gui.waitFor(shellPanel, "ShellLabel") :: TextLabel,
		fullIcon = Gui.waitFor(shellPanel, "FullIcon") :: GuiObject,
		pressureLabel = Gui.waitFor(gui, "PressureLabel") :: GuiObject,
		upButton = Gui.waitFor(gui, "UpButton") :: GuiButton,
	}
end

local function render(ui: Ui, state: Types.DiveState)
	ui.gui.Enabled = state.diving
	if not state.diving then
		ui.pressureLabel.Visible = false
		return
	end
	local fraction = state.oxygenLeft / Economy.DIVE_OXYGEN_SECONDS
	ui.oxygenFill.Size = UDim2.fromScale(fraction, 1)
	ui.oxygenFill.BackgroundColor3 = if fraction <= LOW_OXYGEN_FRACTION then LOW_OXYGEN_COLOR else OXYGEN_COLOR
	ui.oxygenLabel.Text = `O2  {math.ceil(state.oxygenLeft)}`
	ui.shellLabel.Text = `🐚 {state.carried}`
	ui.fullIcon.Visible = state.carried + state.bagCount >= Economy.SHELL_BAG_MAX
end

-- Depth is drawn from the local character every frame so the number moves smoothly.
local function updateDepth(ui: Ui, state: Types.DiveState, zone: Types.Zone): boolean
	local root = Gui.localRoot()
	if not root then
		return false
	end
	local y = root.Position.Y
	ui.depthLabel.Text = `⬇ {math.floor(Formulas.depthAt(zone, state.surfaceY - y))} m`
	if y >= state.floorY then
		return false
	end
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, Economy.DEPTH_PUSH_SPEED), velocity.Z)
	return true
end

function DiveController.init()
	local ui = findUi()
	local surfaceEvent = Remotes.getEvent("RequestSurface")
	local latest: Types.DiveState? = nil
	local zone: Types.Zone? = nil
	local hidePressureAt = 0

	Remotes.getEvent("DiveUpdate").OnClientEvent:Connect(function(state: Types.DiveState)
		latest = state
		zone = if state.zoneId then Formulas.findZone(state.zoneId) else nil
		render(ui, state)
	end)

	RunService.Heartbeat:Connect(function()
		local state, currentZone = latest, zone
		if not state or not state.diving or not currentZone then
			return
		end
		local now = os.clock()
		if updateDepth(ui, state, currentZone) then
			hidePressureAt = now + PRESSURE_MESSAGE_SECONDS
		end
		ui.pressureLabel.Visible = now < hidePressureAt
	end)

	ui.upButton.Activated:Connect(function()
		surfaceEvent:FireServer()
	end)
end

return DiveController
