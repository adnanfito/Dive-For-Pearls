--!strict
-- The Bubble Lift menu (StarterGui.LiftGui, built in Studio). It opens from the lift's prompt and
-- lists released zones; the server decides the unlock and does the teleport.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioController = require("./AudioController")
local Gui = require("../Gui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared:WaitForChild("Formulas"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local Zones = require(Shared:WaitForChild("Config"):WaitForChild("Zones"))

local PROMPT_NAME = "LiftPrompt"
local LEADERSTATS_NAME = "leaderstats"
local DEPTH_STAT_NAME = "Depth" -- PressureService mirrors depthLimit here
-- Card colors per zone (look only); zones without an entry use DEFAULT_COLORS.
local ZONE_COLORS: { [string]: ColorSequence } = {
	ShallowBeach = ColorSequence.new(Color3.fromRGB(255, 225, 150), Color3.fromRGB(60, 200, 210)),
	CoralReef = ColorSequence.new(Color3.fromRGB(255, 140, 180), Color3.fromRGB(150, 90, 240)),
}
local DEFAULT_COLORS = ColorSequence.new(Color3.fromRGB(120, 220, 255), Color3.fromRGB(40, 120, 230))
local LOCKED_COLORS = ColorSequence.new(Color3.fromRGB(175, 185, 200), Color3.fromRGB(110, 120, 140))

type Ui = {
	gui: ScreenGui,
	panel: GuiObject,
	list: GuiObject,
	template: GuiButton,
	closeButton: GuiButton,
}

local LiftController = {}

local function findUi(): Ui
	local gui = Gui.screen("LiftGui")
	local panel = Gui.waitFor(gui, "Panel") :: GuiObject
	local list = Gui.waitFor(panel, "List") :: GuiObject
	return {
		gui = gui,
		panel = panel,
		list = list,
		template = Gui.waitFor(list, "ZoneTemplate") :: GuiButton,
		closeButton = Gui.waitFor(panel, "CloseButton") :: GuiButton,
	}
end

-- The whole-meter value the player list shows; zone thresholds are whole meters, so it unlocks
-- the same zones as the exact value the server checks.
local function shownDepthLimit(): number
	local stats = Players.LocalPlayer:FindFirstChild(LEADERSTATS_NAME)
	local depth = if stats then stats:FindFirstChild(DEPTH_STAT_NAME) else nil
	return if depth and depth:IsA("IntValue") then depth.Value else 0
end

local function clearRows(ui: Ui)
	for _, child in ui.list:GetChildren() do
		if child:IsA("GuiButton") and child ~= ui.template then
			child:Destroy()
		end
	end
end

local function addRow(ui: Ui, zone: Types.Zone, depthLimit: number, onPick: (Types.Zone, TextLabel) -> ())
	local open = Formulas.canEnterZone(zone, depthLimit)
	local row = ui.template:Clone()
	row.Name = zone.id
	row.LayoutOrder = zone.startDepth
	row.Visible = true
	local colors = Gui.waitFor(row, "UIGradient") :: UIGradient
	colors.Color = if open then ZONE_COLORS[zone.id] or DEFAULT_COLORS else LOCKED_COLORS
	local info = Gui.waitFor(row, "InfoLabel") :: TextLabel
	local name = Gui.waitFor(row, "NameLabel") :: TextLabel
	name.Text = zone.displayName
	info.Text = if open then `⬇ {zone.startDepth} m` else `Need {zone.startDepth} m (you {depthLimit} m)`
	local goPill = Gui.waitFor(row, "GoPill") :: GuiObject
	local lockIcon = Gui.waitFor(row, "LockIcon") :: GuiObject
	goPill.Visible = open
	lockIcon.Visible = not open
	if open then
		Gui.bindPress(row)
		row.Activated:Connect(function()
			AudioController.play("Click")
			onPick(zone, info)
		end)
	end
	row.Parent = ui.list
end

function LiftController.init()
	local ui = findUi()
	local useLift = Remotes.getFunction("UseLift")
	local pending = false

	local function pick(zone: Types.Zone, info: TextLabel)
		if pending then
			return
		end
		pending = true
		local result: Types.LiftResult = useLift:InvokeServer(zone.id)
		pending = false
		if result.ok then
			ui.gui.Enabled = false
		elseif result.reason == "TooFar" then
			info.Text = "Come closer!"
		end
	end

	local function open()
		clearRows(ui)
		local depthLimit = shownDepthLimit()
		for _, zone in Zones do
			if zone.released then
				addRow(ui, zone, depthLimit, pick)
			end
		end
		ui.gui.Enabled = true
		Gui.popIn(ui.panel)
		AudioController.play("Click")
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == PROMPT_NAME then
			open()
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == PROMPT_NAME then
			ui.gui.Enabled = false
		end
	end)
	Gui.bindPress(ui.closeButton)
	ui.closeButton.Activated:Connect(function()
		AudioController.play("Click")
		ui.gui.Enabled = false
	end)
end

return LiftController
