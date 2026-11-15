--!strict
-- Renders the Pressure Chamber state the server sends and asks the server to buy upgrades.
-- It never computes depth or Coins itself. The layout lives in StarterGui.PressureGui (built in Studio).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AudioController = require("./AudioController")
local Gui = require("../Gui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared:WaitForChild("Formulas"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local BAR_TWEEN_INFO = TweenInfo.new(0.3)
local FLASH_SECONDS = 0.4
local SMALL_GAIN = 10 -- below this, show one decimal so slow levels still show "+0.5 m"
local CAN_BUY_COLOR = Color3.fromRGB(70, 200, 90)
local CANNOT_BUY_COLOR = Color3.fromRGB(140, 150, 160)
local FLASH_COLOR = Color3.fromRGB(235, 70, 70)

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

local function findUi(): Ui
	local gui = Gui.screen("PressureGui")
	local top = Gui.waitFor(gui, "Top") :: GuiObject
	local bar = Gui.waitFor(top, "ZoneBar")
	local upgradePanel = Gui.waitFor(gui, "UpgradePanel")
	return {
		gui = gui,
		top = top,
		depthLabel = Gui.waitFor(top, "DepthLabel") :: TextLabel,
		gainTemplate = Gui.waitFor(top, "GainLabel") :: TextLabel,
		barFill = Gui.waitFor(bar, "Fill") :: GuiObject,
		zoneLabel = Gui.waitFor(bar, "ZoneLabel") :: TextLabel,
		coinsLabel = Gui.waitFor(upgradePanel, "CoinsLabel") :: TextLabel,
		upgradeButton = Gui.waitFor(upgradePanel, "UpgradeButton") :: TextButton,
	}
end

local function floatGain(ui: Ui, gained: number)
	Gui.floatText(
		ui.gainTemplate,
		if gained < SMALL_GAIN then string.format("+%.1f m", gained) else `+{Gui.withCommas(gained)} m`
	)
end

local function renderZone(ui: Ui, depth: number)
	local progress = Formulas.zoneProgress(depth)
	local nextZone = progress.nextZone
	ui.zoneLabel.Text = if nextZone
		then `{nextZone.displayName}: {Gui.withCommas(depth)} / {Gui.withCommas(nextZone.startDepth)} m`
		else progress.current.displayName
	TweenService:Create(ui.barFill, BAR_TWEEN_INFO, { Size = UDim2.fromScale(progress.fraction, 1) }):Play()
end

local function render(ui: Ui, state: Types.PressureState)
	ui.gui.Enabled = state.inside
	if not state.inside then
		return
	end
	ui.depthLabel.Text = `Depth Limit: {Gui.withCommas(state.depthLimit)} m`
	if state.gained > 0 then
		floatGain(ui, state.gained)
	end
	renderZone(ui, state.depthLimit)
	-- 💰 rather than the coin emoji, which Roblox does not render.
	ui.coinsLabel.Text = `💰 {Gui.withCommas(state.coins)}`
	ui.upgradeButton.Text = `⬆️ 💰 {Gui.withCommas(state.upgradeCost)}`
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

	Gui.bindPress(ui.upgradeButton)
	ui.upgradeButton.Activated:Connect(function()
		AudioController.play("Click")
		local state = latest
		if pending or not state then
			return
		end
		pending = true
		local result: Types.PressureUpgradeResult = buyUpgrade:InvokeServer(state.level)
		pending = false
		if result.ok then
			AudioController.play("CollectRare")
		elseif result.reason == "NotEnoughCoins" then
			flashNotEnough(ui)
		end
	end)
end

return PressureController
