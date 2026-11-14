--!strict
-- The Bubble Lift menu (StarterGui.LiftGui, built in Studio). It opens from the lift's prompt and
-- lists released zones; the server decides the unlock and does the teleport.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gui = require("../Gui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared:WaitForChild("Formulas"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local Zones = require(Shared:WaitForChild("Config"):WaitForChild("Zones"))

local PROMPT_NAME = "LiftPrompt"
local LEADERSTATS_NAME = "leaderstats"
local DEPTH_STAT_NAME = "Depth" -- PressureService mirrors depthLimit here
local OPEN_COLOR = Color3.fromRGB(60, 200, 90)
local LOCKED_COLOR = Color3.fromRGB(140, 140, 140)

type Ui = {
	gui: ScreenGui,
	list: GuiObject,
	template: GuiButton,
	closeButton: GuiButton,
}

local LiftController = {}

local function findUi(): Ui
	local gui = Gui.screen("LiftGui")
	local panel = Gui.waitFor(gui, "Panel")
	local list = Gui.waitFor(panel, "List") :: GuiObject
	return {
		gui = gui,
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
	row.BackgroundColor3 = if open then OPEN_COLOR else LOCKED_COLOR
	row.Visible = true
	local info = Gui.waitFor(row, "InfoLabel") :: TextLabel
	local name = Gui.waitFor(row, "NameLabel") :: TextLabel
	name.Text = zone.displayName
	info.Text = if open then "▶" else `🔒 Need {zone.startDepth} m (you {depthLimit} m)`
	if open then
		row.Activated:Connect(function()
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
	ui.closeButton.Activated:Connect(function()
		ui.gui.Enabled = false
	end)
end

return LiftController
