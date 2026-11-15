--!strict
-- Renders the dive HUD (StarterGui.DiveGui and DiveFxGui, built in Studio) from the state the
-- server sends, and sends the Up request. At the Depth Limit it floats the diver back up so the
-- limit feels smooth; the server enforces the same limit on its own.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AudioController = require("./AudioController")
local Gui = require("../Gui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local LOW_OXYGEN_FRACTION = 0.2 -- GDD: the oxygen warning starts at 20%
local PRESSURE_MESSAGE_SECONDS = 1.5
local BANNER_SECONDS = 2.5
local BAR_INFO = TweenInfo.new(0.25)
local PULSE_SPEED = 7
local WOBBLE_SPEED = 18
local WOBBLE_DEGREES = 3
local UP_STROKE = 4
local UP_STROKE_PULSE = 4
local VIGNETTE_MIN = 0.25
local PRESSURE_VIGNETTE = 0.45
local ARROW_REST = UDim2.fromScale(0.15, 0.1)
local ARROW_HOP = 0.07 -- share of the button height the arrow hops while oxygen is low
local VIGNETTE_RANGE = 0.5
local PRESSURE_GLOW = Color3.fromRGB(255, 60, 60)
-- GDD "Batas tekanan": the screen edges darken over the last 10% before the limit.
local NEAR_LIMIT_FRACTION = 0.9
local NEAR_LIMIT_GLOW = Color3.fromRGB(5, 15, 40)
local NEAR_LIMIT_DARKEST = 0.3
-- Stops pulling down just above the limit so the push-up there does not fight the button.
local DIVE_DOWN_MARGIN_STUDS = 1
local DIVE_DOWN_ACTION = "DiveDown"
local DIVE_DOWN_KEY = Enum.KeyCode.C
local LOW_OXYGEN_GLOW = Color3.fromRGB(60, 150, 255)
local OXYGEN_COLORS = ColorSequence.new(Color3.fromRGB(110, 235, 255), Color3.fromRGB(30, 150, 255))
local LOW_OXYGEN_COLORS = ColorSequence.new(Color3.fromRGB(255, 150, 130), Color3.fromRGB(230, 50, 50))

type Ui = {
	gui: ScreenGui,
	oxygenFill: GuiObject,
	oxygenColors: UIGradient,
	oxygenLabel: TextLabel,
	depthLabel: TextLabel,
	shellPanel: GuiObject,
	shellLabel: TextLabel,
	bagLabel: TextLabel,
	fullIcon: GuiObject,
	plusTemplate: TextLabel,
	marker: GuiObject,
	limitLine: GuiObject,
	topLabel: TextLabel,
	bottomLabel: TextLabel,
	pressureLabel: GuiObject,
	upButton: GuiButton,
	upStroke: UIStroke,
	upArrow: GuiObject,
	downButton: GuiButton,
	banner: TextLabel,
	vignette: GuiObject,
}

type View = {
	state: Types.DiveState?,
	zone: Types.Zone?,
	carried: number,
	lowOxygen: boolean,
	pressureUntil: number,
	holdingDown: boolean,
	limitFraction: number, -- how far down toward the Depth Limit, 0 at the surface
}

local DiveController = {}

local function findUi(): Ui
	local gui = Gui.screen("DiveGui")
	local top = Gui.waitFor(gui, "Top")
	local track = Gui.waitFor(Gui.waitFor(top, "OxygenBar"), "Track")
	local fill = Gui.waitFor(track, "Fill") :: GuiObject
	local shellPanel = Gui.waitFor(gui, "ShellPanel") :: GuiObject
	local gauge = Gui.waitFor(gui, "DepthGauge")
	local upButton = Gui.waitFor(gui, "UpButton") :: GuiButton
	return {
		gui = gui,
		oxygenFill = fill,
		oxygenColors = Gui.waitFor(fill, "UIGradient") :: UIGradient,
		oxygenLabel = Gui.waitFor(track, "Label") :: TextLabel,
		depthLabel = Gui.waitFor(top, "DepthLabel") :: TextLabel,
		shellPanel = shellPanel,
		shellLabel = Gui.waitFor(shellPanel, "ShellLabel") :: TextLabel,
		bagLabel = Gui.waitFor(shellPanel, "BagLabel") :: TextLabel,
		fullIcon = Gui.waitFor(shellPanel, "FullIcon") :: GuiObject,
		plusTemplate = Gui.waitFor(shellPanel, "PlusTemplate") :: TextLabel,
		marker = Gui.waitFor(gauge, "Marker") :: GuiObject,
		limitLine = Gui.waitFor(gauge, "LimitLine") :: GuiObject,
		topLabel = Gui.waitFor(gauge, "TopLabel") :: TextLabel,
		bottomLabel = Gui.waitFor(gauge, "BottomLabel") :: TextLabel,
		pressureLabel = Gui.waitFor(gui, "PressureLabel") :: GuiObject,
		upButton = upButton,
		upStroke = Gui.waitFor(upButton, "UIStroke") :: UIStroke,
		upArrow = Gui.waitFor(upButton, "Arrow") :: GuiObject,
		downButton = Gui.waitFor(gui, "DownButton") :: GuiButton,
		banner = Gui.waitFor(gui, "ZoneBanner") :: TextLabel,
		vignette = Gui.waitFor(Gui.screen("DiveFxGui"), "Vignette") :: GuiObject,
	}
end

local function renderOxygen(ui: Ui, view: View, state: Types.DiveState)
	local fraction = state.oxygenLeft / Economy.DIVE_OXYGEN_SECONDS
	local low = fraction <= LOW_OXYGEN_FRACTION
	TweenService:Create(ui.oxygenFill, BAR_INFO, { Size = UDim2.fromScale(math.max(fraction, 0), 1) }):Play()
	ui.oxygenColors.Color = if low then LOW_OXYGEN_COLORS else OXYGEN_COLORS
	ui.oxygenLabel.Text = tostring(math.ceil(state.oxygenLeft))
	if low and not view.lowOxygen then
		AudioController.play("Warning")
	end
	view.lowOxygen = low
end

local function renderShells(ui: Ui, view: View, state: Types.DiveState)
	ui.shellLabel.Text = tostring(state.carried)
	ui.bagLabel.Text = `🎒 {state.bagCount + state.carried}/{Economy.SHELL_BAG_MAX}`
	ui.fullIcon.Visible = state.carried + state.bagCount >= Economy.SHELL_BAG_MAX
	if state.carried > view.carried then
		Gui.bounce(ui.shellPanel)
		Gui.floatText(ui.plusTemplate, `+{state.carried - view.carried}`)
	end
	view.carried = state.carried
end

local function renderGauge(ui: Ui, zone: Types.Zone, state: Types.DiveState)
	local limitStuds = state.surfaceY - state.floorY
	ui.topLabel.Text = `{zone.startDepth} m`
	ui.bottomLabel.Text = `{math.floor(Formulas.depthAt(zone, Economy.ZONE_HEIGHT_STUDS))} m`
	ui.limitLine.Position = UDim2.new(0, -5, Formulas.zoneDepthFraction(limitStuds), 0)
end

local function showBanner(ui: Ui, zone: Types.Zone)
	ui.banner.Text = zone.displayName
	ui.banner.Visible = true
	Gui.popIn(ui.banner)
	task.delay(BANNER_SECONDS, function()
		if ui.banner.Text == zone.displayName then
			ui.banner.Visible = false
		end
	end)
end

local function render(ui: Ui, view: View, state: Types.DiveState)
	local wasDiving = view.state ~= nil and (view.state :: Types.DiveState).diving
	local zone = if state.zoneId then Formulas.findZone(state.zoneId) else nil
	view.state, view.zone = state, zone
	ui.gui.Enabled = state.diving
	if not state.diving or not zone then
		view.carried, view.lowOxygen = 0, false
		return
	end
	if not wasDiving then
		view.carried = state.carried
		showBanner(ui, zone)
		AudioController.play("Splash")
	end
	renderOxygen(ui, view, state)
	renderShells(ui, view, state)
	renderGauge(ui, zone, state)
end

-- Depth is drawn from the local character every frame so the number and marker move smoothly.
-- Returns true while the diver is below the limit and being floated back up.
local function updateDepth(ui: Ui, view: View, state: Types.DiveState, zone: Types.Zone): boolean
	local root = Gui.localRoot()
	if not root then
		return false
	end
	local y = root.Position.Y
	local studs = state.surfaceY - y
	ui.depthLabel.Text = `⬇ {math.floor(Formulas.depthAt(zone, studs))} m`
	ui.marker.Position = UDim2.fromScale(0.5, Formulas.zoneDepthFraction(studs))
	view.limitFraction = studs / math.max(state.surfaceY - state.floorY, 1)
	local velocity = root.AssemblyLinearVelocity
	if y < state.floorY then
		root.AssemblyLinearVelocity =
			Vector3.new(velocity.X, math.max(velocity.Y, Economy.DEPTH_PUSH_SPEED), velocity.Z)
		return true
	end
	if view.holdingDown and y > state.floorY + DIVE_DOWN_MARGIN_STUDS then
		root.AssemblyLinearVelocity =
			Vector3.new(velocity.X, math.min(velocity.Y, -Economy.DIVE_DOWN_SPEED), velocity.Z)
	end
	return false
end

local function setVignette(ui: Ui, color: Color3?, transparency: number)
	ui.vignette.Visible = color ~= nil
	if not color then
		return
	end
	for _, edge in ui.vignette:GetChildren() do
		if edge:IsA("Frame") then
			edge.BackgroundColor3 = color
			edge.BackgroundTransparency = transparency
		end
	end
end

local function updateEffects(ui: Ui, view: View, now: number)
	local pressure = now < view.pressureUntil
	local pulse = 0.5 + 0.5 * math.sin(now * PULSE_SPEED)
	ui.pressureLabel.Visible = pressure
	ui.pressureLabel.Rotation = if pressure then math.sin(now * WOBBLE_SPEED) * WOBBLE_DEGREES else 0
	ui.upStroke.Thickness = if view.lowOxygen then UP_STROKE + UP_STROKE_PULSE * pulse else UP_STROKE
	ui.upArrow.Position = if view.lowOxygen then ARROW_REST - UDim2.fromScale(0, ARROW_HOP * pulse) else ARROW_REST
	if pressure then
		setVignette(ui, PRESSURE_GLOW, PRESSURE_VIGNETTE)
	elseif view.lowOxygen then
		setVignette(ui, LOW_OXYGEN_GLOW, VIGNETTE_MIN + VIGNETTE_RANGE * pulse)
	elseif view.limitFraction >= NEAR_LIMIT_FRACTION then
		local closeness = math.clamp((view.limitFraction - NEAR_LIMIT_FRACTION) / (1 - NEAR_LIMIT_FRACTION), 0, 1)
		setVignette(ui, NEAR_LIMIT_GLOW, 1 - (1 - NEAR_LIMIT_DARKEST) * closeness)
	else
		setVignette(ui, nil, 1)
	end
end

-- Held, not tapped: the diver sinks while a finger (or the C key) stays down. The touch is
-- followed until it lifts, because the finger can slide off the button first.
local function bindDiveDown(ui: Ui, view: View)
	Gui.bindPress(ui.downButton)
	ui.downButton.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
			return
		end
		view.holdingDown = true
		local watch: RBXScriptConnection
		watch = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			if
				input.UserInputState == Enum.UserInputState.End
				or input.UserInputState == Enum.UserInputState.Cancel
			then
				view.holdingDown = false
				watch:Disconnect()
			end
		end)
	end)
	ContextActionService:BindAction(DIVE_DOWN_ACTION, function(_, inputState)
		view.holdingDown = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, false, DIVE_DOWN_KEY)
end

function DiveController.init()
	local ui = findUi()
	local surfaceEvent = Remotes.getEvent("RequestSurface")
	local view: View = {
		state = nil,
		zone = nil,
		carried = 0,
		lowOxygen = false,
		pressureUntil = 0,
		holdingDown = false,
		limitFraction = 0,
	}

	Remotes.getEvent("DiveUpdate").OnClientEvent:Connect(function(state: Types.DiveState)
		render(ui, view, state)
	end)

	RunService.Heartbeat:Connect(function()
		local state, zone = view.state, view.zone
		local now = os.clock()
		if not state or not state.diving or not zone then
			setVignette(ui, nil, 1)
			return
		end
		if updateDepth(ui, view, state, zone) then
			view.pressureUntil = now + PRESSURE_MESSAGE_SECONDS
		end
		updateEffects(ui, view, now)
	end)

	Gui.bindPress(ui.upButton)
	ui.upButton.Activated:Connect(function()
		AudioController.play("Click")
		surfaceEvent:FireServer()
	end)
	bindDiveDown(ui, view)
end

return DiveController
