--!strict
-- Renders the Pressure Chamber state the server sends and asks the server to buy upgrades.
-- It never computes depth or Coins itself. The layout lives in StarterGui.PressureGui (built in Studio).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared:WaitForChild("Formulas"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local GUI_WAIT_SECONDS = 10
local GAIN_FLOAT_INFO = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GAIN_FLOAT_RISE = UDim2.fromOffset(0, -40)
local BAR_TWEEN_INFO = TweenInfo.new(0.3)
local FLASH_SECONDS = 0.4
local SMALL_GAIN = 10 -- below this, show one decimal so slow levels still show "+0.5 m"
local CAN_BUY_COLOR = Color3.fromRGB(60, 200, 90)
local CANNOT_BUY_COLOR = Color3.fromRGB(140, 140, 140)
local FLASH_COLOR = Color3.fromRGB(230, 70, 70)

type Ui = {
	gui: ScreenGui,
	top: GuiObject,
	depthLabel: TextLabel,
	gainTemplate: TextLabel,
	barFill: GuiObject,
	zoneLabel: TextLabel,
	coinsLabel: TextLabel,
	upgradeButton: TextButton,
}

local PressureController = {}

local function waitFor(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, GUI_WAIT_SECONDS)
	assert(child, `PressureController: {parent:GetFullName()}.{name} is missing`)
	return child
end

local function findUi(): Ui
	local playerGui = waitFor(Players.LocalPlayer, "PlayerGui")
	local gui = waitFor(playerGui, "PressureGui") :: ScreenGui
	local top = waitFor(gui, "Top") :: GuiObject
	local bar = waitFor(top, "ZoneBar")
	local upgradePanel = waitFor(gui, "UpgradePanel")
	return {
		gui = gui,
		top = top,
		depthLabel = waitFor(top, "DepthLabel") :: TextLabel,
		gainTemplate = waitFor(top, "GainLabel") :: TextLabel,
		barFill = waitFor(bar, "Fill") :: GuiObject,
		zoneLabel = waitFor(bar, "ZoneLabel") :: TextLabel,
		coinsLabel = waitFor(upgradePanel, "CoinsLabel") :: TextLabel,
		upgradeButton = waitFor(upgradePanel, "UpgradeButton") :: TextButton,
	}
end

local function withCommas(value: number): string
	local digits = string.format("%d", math.floor(value))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (grouped:gsub("^,", ""))
end

local function floatGain(ui: Ui, gained: number)
	local label = ui.gainTemplate:Clone()
	label.Text = if gained < SMALL_GAIN then string.format("+%.1f m", gained) else `+{withCommas(gained)} m`
	label.Visible = true
	label.Parent = ui.top
	local tween = TweenService:Create(label, GAIN_FLOAT_INFO, {
		Position = label.Position + GAIN_FLOAT_RISE,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Once(function()
		label:Destroy()
	end)
	tween:Play()
end

local function renderZone(ui: Ui, depth: number)
	local progress = Formulas.zoneProgress(depth)
	local nextZone = progress.nextZone
	ui.zoneLabel.Text = if nextZone
		then `{nextZone.displayName}: {withCommas(depth)} / {withCommas(nextZone.startDepth)} m`
		else progress.current.displayName
	TweenService:Create(ui.barFill, BAR_TWEEN_INFO, { Size = UDim2.fromScale(progress.fraction, 1) }):Play()
end

local function render(ui: Ui, state: Types.PressureState)
	ui.gui.Enabled = state.inside
	if not state.inside then
		return
	end
	ui.depthLabel.Text = `Depth Limit: {withCommas(state.depthLimit)} m`
	if state.gained > 0 then
		floatGain(ui, state.gained)
	end
	renderZone(ui, state.depthLimit)
	-- 💰 rather than the coin emoji, which Roblox does not render.
	ui.coinsLabel.Text = `💰 {withCommas(state.coins)}`
	ui.upgradeButton.Text = `⬆️ 💰 {withCommas(state.upgradeCost)}`
	ui.upgradeButton.BackgroundColor3 = if state.coins >= state.upgradeCost then CAN_BUY_COLOR else CANNOT_BUY_COLOR
end

local function flashNotEnough(ui: Ui)
	local button = ui.upgradeButton
	local before = button.BackgroundColor3
	button.BackgroundColor3 = FLASH_COLOR
	task.delay(FLASH_SECONDS, function()
		if button.BackgroundColor3 == FLASH_COLOR then
			button.BackgroundColor3 = before
		end
	end)
end

function PressureController.init()
	local ui = findUi()
	local buyUpgrade = Remotes.getFunction("BuyPressureUpgrade")
	local latest: Types.PressureState? = nil
	local pending = false

	Remotes.getEvent("PressureUpdate").OnClientEvent:Connect(function(state: Types.PressureState)
		latest = state
		render(ui, state)
	end)

	ui.upgradeButton.Activated:Connect(function()
		local state = latest
		if pending or not state then
			return
		end
		pending = true
		local result: Types.PressureUpgradeResult = buyUpgrade:InvokeServer(state.level)
		pending = false
		if result.reason == "NotEnoughCoins" then
			flashNotEnough(ui)
		end
	end)
end

return PressureController
