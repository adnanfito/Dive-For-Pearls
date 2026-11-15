--!strict
-- The aquarium screens (StarterGui.AquariumGui, built in Studio). The panel opens while the player
-- stands on the pad of their own tank. It renders the state the server sends and sends requests:
-- put shells, open a ripe shell (the server rolls the pearl) and choose what a pearl does.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioController = require("./AudioController")
local Gui = require("../Gui")
local ShellViewport = require("../ShellViewport")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PearlLooks = require(Shared:WaitForChild("PearlLooks"))
local Pearls = require(Shared:WaitForChild("Config"):WaitForChild("Pearls"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

type State = Types.AquariumState
type PearlView = Types.PearlView
type Tab = "Tank" | "Pearls"

local FOLDER_NAME = "Aquariums"
local PAD_NAME = "Pad"
local OWNER_ATTRIBUTE = "OwnerUserId"
local PAD_REACH_STUDS = 6 -- horizontal distance from the pad centre that counts as standing on it
local PAD_HEIGHT_STUDS = 8
local TIMER_STEP_SECONDS = 0.25
local TAB_ON = Color3.fromRGB(255, 190, 60)
local TAB_OFF = Color3.fromRGB(70, 140, 200)
local CAN_COLOR = Color3.fromRGB(70, 200, 90)
local CANNOT_COLOR = Color3.fromRGB(140, 150, 160)
local SHOUT_COLOR = Color3.fromRGB(255, 120, 110)
local SHELL_CARD_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(255, 240, 220),
	Glowing = Color3.fromRGB(205, 245, 255),
	Rare = Color3.fromRGB(232, 212, 255),
	Giant = Color3.fromRGB(255, 236, 170),
}
local BADGES: { [string]: string } = { Equipped = "⭐", Displayed = "🐠", Stored = "" }
local PLACE_ORDER: { [string]: number } = { Equipped = 1, Displayed = 2, Stored = 3 }
local SPECIAL_PEARLS: { [string]: boolean } = { Gold = true, Black = true, Rainbow = true }
local MESSAGES: { [string]: string } = {
	NoRoom = "Tank is full!",
	PearlsFull = "Too many pearls! Sell some.",
	NotRipe = "Not ready yet!",
	TooFar = "Stand on your pad!",
}

local rarityRank: { [string]: number } = {}
for index, row in Pearls do
	rarityRank[row.id] = index
end

type Ui = {
	gui: ScreenGui,
	panel: GuiObject,
	slotsLabel: TextLabel,
	incomeLabel: TextLabel,
	tankTab: GuiButton,
	pearlsTab: GuiButton,
	putButton: GuiButton,
	putLabel: TextLabel,
	grid: ScrollingFrame,
	shellTemplate: GuiButton,
	pearlTemplate: GuiButton,
	emptyTemplate: GuiObject,
	closeButton: GuiButton,
	reveal: GuiObject,
	viewport: ViewportFrame,
	glow: GuiObject,
	rarityLabel: TextLabel,
	equipButton: GuiButton,
	displayButton: GuiButton,
	sellButton: GuiButton,
	keepButton: GuiButton,
}

type View = {
	state: State?,
	receivedAt: number,
	bagCount: number,
	tab: Tab,
	open: boolean,
	dismissed: boolean, -- closed with X; reopens after stepping off the pad
	busy: boolean,
	pearl: PearlView?, -- the pearl the choice card is showing
	timers: { [TextLabel]: { readyAt: number, ready: TextLabel } },
}

local AquariumController = {}

local function findUi(): Ui
	local gui = Gui.screen("AquariumGui")
	local panel = Gui.waitFor(gui, "Panel") :: GuiObject
	local templates = Gui.waitFor(panel, "Templates")
	local putButton = Gui.waitFor(panel, "PutButton") :: GuiButton
	local reveal = Gui.waitFor(gui, "Reveal") :: GuiObject
	local card = Gui.waitFor(reveal, "Card")
	return {
		gui = gui,
		panel = panel,
		slotsLabel = Gui.waitFor(panel, "SlotsLabel") :: TextLabel,
		incomeLabel = Gui.waitFor(panel, "IncomeLabel") :: TextLabel,
		tankTab = Gui.waitFor(panel, "TankTab") :: GuiButton,
		pearlsTab = Gui.waitFor(panel, "PearlsTab") :: GuiButton,
		putButton = putButton,
		putLabel = Gui.waitFor(putButton, "Label") :: TextLabel,
		grid = Gui.waitFor(panel, "Grid") :: ScrollingFrame,
		shellTemplate = Gui.waitFor(templates, "ShellCard") :: GuiButton,
		pearlTemplate = Gui.waitFor(templates, "PearlCard") :: GuiButton,
		emptyTemplate = Gui.waitFor(templates, "EmptyCard") :: GuiObject,
		closeButton = Gui.waitFor(panel, "CloseButton") :: GuiButton,
		reveal = reveal,
		viewport = Gui.waitFor(card, "Viewport") :: ViewportFrame,
		glow = Gui.waitFor(card, "Glow") :: GuiObject,
		rarityLabel = Gui.waitFor(card, "RarityLabel") :: TextLabel,
		equipButton = Gui.waitFor(card, "EquipButton") :: GuiButton,
		displayButton = Gui.waitFor(card, "DisplayButton") :: GuiButton,
		sellButton = Gui.waitFor(card, "SellButton") :: GuiButton,
		keepButton = Gui.waitFor(card, "KeepButton") :: GuiButton,
	}
end

local function myPad(): BasePart?
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if not folder then
		return nil
	end
	for _, plot in folder:GetChildren() do
		if plot:GetAttribute(OWNER_ATTRIBUTE) == Players.LocalPlayer.UserId then
			local pad = plot:FindFirstChild(PAD_NAME)
			return if pad and pad:IsA("BasePart") then pad else nil
		end
	end
	return nil
end

local function onPad(): boolean
	local root = Gui.localRoot()
	local pad = myPad()
	if not root or not pad then
		return false
	end
	local offset = root.Position - pad.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= PAD_REACH_STUDS and math.abs(offset.Y) <= PAD_HEIGHT_STUDS
end

local function formatTime(seconds: number): string
	local whole = math.ceil(seconds)
	if whole >= 3600 then
		return `{whole // 3600}h {(whole % 3600) // 60}m`
	end
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function shout(ui: Ui, reason: string?)
	AudioController.play("Warning")
	Gui.floatText(ui.slotsLabel, MESSAGES[reason or ""] or "Try again!", SHOUT_COLOR)
end

local function paintPearl(ball: GuiObject, rarity: Types.PearlRarityId)
	local look = PearlLooks.of(rarity)
	ball.BackgroundColor3 = look.color
	local sheen = ball:FindFirstChild("Sheen")
	if sheen and sheen:IsA("UIGradient") then
		sheen.Color = if look.rainbow then PearlLooks.RAINBOW else ColorSequence.new(Color3.new(1, 1, 1), look.color)
	end
end

local function clearGrid(ui: Ui, view: View)
	table.clear(view.timers)
	for _, child in ui.grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function freeSlots(state: State): number
	local displayed = 0
	for _, pearl in state.pearls do
		if pearl.place == "Displayed" then
			displayed += 1
		end
	end
	return state.slots - #state.shells - displayed
end

local function setValue(button: GuiButton, text: string)
	local value = button:FindFirstChild("Value")
	if value and value:IsA("TextLabel") then
		value.Text = text
	end
end

-- The choice card: what the pearl gives in each of the three places, with the current one ticked.
local function showChoices(ui: Ui, view: View, pearl: PearlView)
	view.pearl = pearl
	local look = PearlLooks.of(pearl.rarity)
	ui.glow.BackgroundColor3 = look.glow
	ui.rarityLabel.Text = `{string.upper(pearl.rarity)} PEARL!`
	ui.rarityLabel.TextColor3 = if look.rainbow then Color3.new(1, 1, 1) else look.glow:Lerp(Color3.new(1, 1, 1), 0.4)
	setValue(ui.equipButton, if pearl.place == "Equipped" then "✓" else `+{math.floor(pearl.bonus * 100)}%`)
	setValue(
		ui.displayButton,
		if pearl.place == "Displayed" then "✓" else `+{Gui.withCommas(pearl.coinsPerSecond)}/s`
	)
	setValue(ui.sellButton, Gui.withCommas(pearl.sellPrice))
	local state = view.state
	local roomToShow = pearl.place == "Displayed" or (state ~= nil and freeSlots(state) > 0)
	ui.displayButton.BackgroundColor3 = if roomToShow then Color3.fromRGB(60, 200, 210) else CANNOT_COLOR
	ui.reveal.Visible = true
	Gui.popIn(ui.reveal:FindFirstChild("Card") :: GuiObject)
end

local function openShell(ui: Ui, view: View, index: number, tier: Types.ShellTierId)
	if view.busy then
		return
	end
	view.busy = true
	local result: Types.AquariumResult = Remotes.getFunction("OpenShell"):InvokeServer(index)
	view.busy = false
	local pearl = result.pearl
	if not result.ok or not pearl then
		shout(ui, result.reason)
		return
	end
	showChoices(ui, view, pearl)
	ShellViewport.openWithPearl(ui.viewport, tier, pearl.rarity)
	AudioController.play(if SPECIAL_PEARLS[pearl.rarity] then "CollectRare" else "Collect")
end

local function choose(ui: Ui, view: View, use: Types.PearlUse)
	local pearl = view.pearl
	if not pearl or view.busy then
		return
	end
	view.busy = true
	local result: Types.AquariumResult = Remotes.getFunction("UsePearl"):InvokeServer(pearl.id, use)
	view.busy = false
	if not result.ok then
		shout(ui, result.reason)
		return
	end
	AudioController.play(if use == "Sell" then "CollectRare" else "Click")
	ui.reveal.Visible = false
	view.pearl = nil
end

local function addShellCard(ui: Ui, view: View, index: number, shell: Types.AquariumShellView)
	local card = ui.shellTemplate:Clone()
	card.LayoutOrder = index
	card.BackgroundColor3 = SHELL_CARD_COLORS[shell.tier] or SHELL_CARD_COLORS.Common
	card.Visible = true
	card.Parent = ui.grid
	ShellViewport.showShell(card:FindFirstChild("Viewport") :: ViewportFrame, shell.tier)
	local timeLabel = card:FindFirstChild("TimeLabel") :: TextLabel
	view.timers[timeLabel] = {
		readyAt = view.receivedAt + shell.readyIn,
		ready = card:FindFirstChild("ReadyLabel") :: TextLabel,
	}
	Gui.bindPress(card)
	card.Activated:Connect(function()
		AudioController.play("Click")
		task.spawn(openShell, ui, view, index, shell.tier)
	end)
end

local function addPearlCard(ui: Ui, view: View, order: number, pearl: PearlView)
	local card = ui.pearlTemplate:Clone()
	card.LayoutOrder = order
	card.Visible = true
	paintPearl(card:FindFirstChild("Pearl") :: GuiObject, pearl.rarity)
	local info = card:FindFirstChild("InfoLabel") :: TextLabel
	info.Text = if pearl.place == "Equipped"
		then `+{math.floor(pearl.bonus * 100)}%`
		else `+{Gui.withCommas(pearl.coinsPerSecond)}/s`
	local badge = card:FindFirstChild("Badge") :: TextLabel
	badge.Text = BADGES[pearl.place]
	card.Parent = ui.grid
	Gui.bindPress(card)
	card.Activated:Connect(function()
		AudioController.play("Click")
		showChoices(ui, view, pearl)
		ShellViewport.showPearl(ui.viewport, pearl.rarity)
	end)
end

local function addEmptyCard(ui: Ui, order: number)
	local card = ui.emptyTemplate:Clone()
	card.LayoutOrder = order
	card.Visible = true
	card.Parent = ui.grid
end

-- Tank tab: ripening shells, then displayed pearls, then empty slots, like the tank itself.
local function renderTank(ui: Ui, view: View, state: State)
	for index, shell in state.shells do
		addShellCard(ui, view, index, shell)
	end
	local order = #state.shells
	for _, pearl in state.pearls do
		if pearl.place == "Displayed" then
			order += 1
			addPearlCard(ui, view, order, pearl)
		end
	end
	for _ = 1, freeSlots(state) do
		order += 1
		addEmptyCard(ui, order)
	end
end

-- Pearls tab: every owned pearl, equipped first, then displayed, then stored; best rarity first.
local function renderPearls(ui: Ui, view: View, state: State)
	local pearls = table.clone(state.pearls)
	table.sort(pearls, function(a, b)
		if a.place ~= b.place then
			return PLACE_ORDER[a.place] < PLACE_ORDER[b.place]
		end
		return (rarityRank[a.rarity] or 0) > (rarityRank[b.rarity] or 0)
	end)
	for order, pearl in pearls do
		addPearlCard(ui, view, order, pearl)
	end
end

local function render(ui: Ui, view: View)
	local state = view.state
	if not state then
		return
	end
	local used = state.slots - freeSlots(state)
	ui.slotsLabel.Text = `Slots {used}/{state.slots}`
	ui.incomeLabel.Text = `💰 +{Gui.withCommas(state.coinsPerSecond)}/s`
	ui.putLabel.Text = `🎒 Put shells ({view.bagCount})`
	ui.putButton.BackgroundColor3 = if view.bagCount > 0 and freeSlots(state) > 0 then CAN_COLOR else CANNOT_COLOR
	ui.tankTab.BackgroundColor3 = if view.tab == "Tank" then TAB_ON else TAB_OFF
	ui.pearlsTab.BackgroundColor3 = if view.tab == "Pearls" then TAB_ON else TAB_OFF
	clearGrid(ui, view)
	if view.tab == "Tank" then
		renderTank(ui, view, state)
	else
		renderPearls(ui, view, state)
	end
end

local function updateTimers(view: View, now: number)
	for label, timer in view.timers do
		local left = timer.readyAt - now
		label.Visible = left > 0
		timer.ready.Visible = left <= 0
		if left > 0 then
			label.Text = formatTime(left)
		end
	end
end

local function setOpen(ui: Ui, view: View, open: boolean)
	view.open = open
	ui.gui.Enabled = open
	if open then
		render(ui, view)
		Gui.popIn(ui.panel)
	else
		ui.reveal.Visible = false
		view.pearl = nil
	end
end

local function putShells(ui: Ui, view: View)
	if view.busy then
		return
	end
	view.busy = true
	local result: Types.AquariumResult = Remotes.getFunction("PlaceShells"):InvokeServer()
	view.busy = false
	if result.ok then
		AudioController.play("Splash")
	else
		shout(ui, result.reason)
	end
end

local function bindButtons(ui: Ui, view: View)
	local function button(object: GuiButton, action: () -> ())
		Gui.bindPress(object)
		object.Activated:Connect(function()
			AudioController.play("Click")
			action()
		end)
	end
	local function tab(name: Tab)
		view.tab = name
		render(ui, view)
	end
	button(ui.tankTab, function()
		tab("Tank")
	end)
	button(ui.pearlsTab, function()
		tab("Pearls")
	end)
	button(ui.closeButton, function()
		view.dismissed = true
		setOpen(ui, view, false)
	end)
	button(ui.putButton, function()
		task.spawn(putShells, ui, view)
	end)
	button(ui.keepButton, function()
		ui.reveal.Visible = false
		view.pearl = nil
	end)
	local function choice(object: GuiButton, use: Types.PearlUse)
		Gui.bindPress(object)
		object.Activated:Connect(function()
			task.spawn(choose, ui, view, use)
		end)
	end
	choice(ui.equipButton, "Equip")
	choice(ui.displayButton, "Display")
	choice(ui.sellButton, "Sell")
end

function AquariumController.init()
	local ui = findUi()
	local view: View = {
		state = nil,
		receivedAt = 0,
		bagCount = 0,
		tab = "Tank",
		open = false,
		dismissed = false,
		busy = false,
		pearl = nil,
		timers = {},
	}
	bindButtons(ui, view)

	Remotes.getEvent("AquariumUpdate").OnClientEvent:Connect(function(state: State)
		view.state, view.receivedAt, view.bagCount = state, os.clock(), state.bagCount
		if view.open then
			render(ui, view)
		end
	end)
	-- Shells reach the bag when a dive ends, before the next aquarium update.
	Remotes.getEvent("DiveUpdate").OnClientEvent:Connect(function(state: Types.DiveState)
		if view.bagCount ~= state.bagCount then
			view.bagCount = state.bagCount
			if view.open then
				render(ui, view)
			end
		end
	end)

	local sinceTimers = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		local standing = onPad()
		if standing and not view.open and not view.dismissed then
			setOpen(ui, view, true)
		elseif not standing then
			view.dismissed = false
			if view.open then
				setOpen(ui, view, false)
			end
		end
		sinceTimers += deltaTime
		if view.open and sinceTimers >= TIMER_STEP_SECONDS then
			sinceTimers = 0
			updateTimers(view, os.clock())
		end
	end)
end

return AquariumController
