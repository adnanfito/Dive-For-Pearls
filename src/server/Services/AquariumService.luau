--!strict
-- Owns the aquariums. Each player gets one of the tanks on the island (Workspace.Aquariums.<Plot>,
-- built in Studio) and uses it standing near its Pad: placing shells from the bag, opening ripe
-- shells into pearls (rolled here, never on the client) and choosing what each pearl does. Displayed
-- pearls pay Coins every second while the player is in the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Aquarium = require(ReplicatedStorage.Shared.Aquarium)
local AquariumDisplay = require(ServerScriptService.Server.AquariumDisplay)
local Characters = require(ServerScriptService.Server.Characters)
local DataService = require(ServerScriptService.Server.Services.DataService)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerData = Types.PlayerData
type Result = Types.AquariumResult
type Failure = Types.AquariumFailure

type Plot = { model: Model, pad: BasePart, owner: Player? }

local FOLDER_NAME = "Aquariums"
local PAD_NAME = "Pad"
local OWNER_ATTRIBUTE = "OwnerUserId" -- the client reads it to find its own tank
local PEARL_USES: { [string]: boolean } = { Equip = true, Display = true, Sell = true, Store = true }

local rng = Random.new()
local plots: { Plot } = {}
local plotOf: { [Player]: Plot } = {}
local lastActionAt: { [Player]: number } = {}
local ripeCounts: { [Player]: number } = {}
local updateEvent: RemoteEvent
local coinsEvent: RemoteEvent

local AquariumService = {}

local function fail(reason: Failure?): Result
	return { ok = false, reason = reason }
end

local function countRipe(data: PlayerData, now: number): number
	local ripe = 0
	for _, shell in data.aquarium.shells do
		if shell.readyAt <= now then
			ripe += 1
		end
	end
	return ripe
end

local function refresh(player: Player, data: PlayerData)
	local now = os.time()
	local plot = plotOf[player]
	ripeCounts[player] = countRipe(data, now)
	updateEvent:FireClient(player, Aquarium.state(data, now, plot ~= nil))
	if plot then
		AquariumDisplay.render(plot.model, data, now)
	end
end

local function sendCoins(player: Player, data: PlayerData)
	coinsEvent:FireClient(player, data.coins)
end

local function assignPlot(player: Player, data: PlayerData)
	if player.Parent ~= Players then
		return
	end
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plotOf[player] = plot
			plot.model:SetAttribute(OWNER_ATTRIBUTE, player.UserId)
			AquariumDisplay.setOwner(plot.model, player.DisplayName)
			break
		end
	end
	if not plotOf[player] then
		warn(`AquariumService: no free tank for {player.Name} ({player.UserId}); is MaxPlayers above {#plots}?`)
	end
	refresh(player, data)
	sendCoins(player, data)
end

local function freePlot(player: Player)
	local plot = plotOf[player]
	plotOf[player] = nil
	lastActionAt[player] = nil
	ripeCounts[player] = nil
	if plot then
		plot.owner = nil
		plot.model:SetAttribute(OWNER_ATTRIBUTE, nil)
		AquariumDisplay.setOwner(plot.model, nil)
		AquariumDisplay.clear(plot.model)
	end
end

-- Every request: loaded data, a short cooldown, and the player standing at their own tank.
local function checkRequest(player: Player): (PlayerData?, Failure?)
	local data = DataService.get(player)
	if not data then
		return nil, "NotReady"
	end
	local now = os.clock()
	if now - (lastActionAt[player] or -math.huge) < Economy.AQUARIUM_ACTION_COOLDOWN_SECONDS then
		return nil, "TooFast"
	end
	lastActionAt[player] = now
	local plot = plotOf[player]
	local root = Characters.aliveRoot(player)
	if not plot or not root or (root.Position - plot.pad.Position).Magnitude > Economy.AQUARIUM_RADIUS_STUDS then
		return nil, "TooFar"
	end
	return data, nil
end

local function placeShells(player: Player): Result
	local data: PlayerData?, failure: Failure? = checkRequest(player)
	if not data then
		return fail(failure)
	end
	if #data.shellBag == 0 or Aquarium.freeSlots(data) <= 0 then
		return fail("NoRoom")
	end
	Aquarium.placeFromBag(data, os.time())
	refresh(player, data)
	return { ok = true }
end

local function isWholeIndex(value: unknown): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= 1
end

local function openShell(player: Player, index: unknown): Result
	if not isWholeIndex(index) then
		warn(`AquariumService: {player.Name} ({player.UserId}) sent bad shell index {index}`)
		return fail("BadRequest")
	end
	local data: PlayerData?, failure: Failure? = checkRequest(player)
	if not data then
		return fail(failure)
	end
	local id: string?, openFailure: Failure? = Aquarium.openShell(data, index :: number, os.time(), rng:NextNumber())
	if not id then
		return fail(openFailure)
	end
	refresh(player, data)
	return { ok = true, pearl = Aquarium.pearlView(data, id) }
end

local function usePearl(player: Player, pearlId: unknown, use: unknown): Result
	if typeof(pearlId) ~= "string" or typeof(use) ~= "string" or not PEARL_USES[use] then
		warn(`AquariumService: {player.Name} ({player.UserId}) sent bad pearl use {pearlId} {use}`)
		return fail("BadRequest")
	end
	local data: PlayerData?, failure: Failure? = checkRequest(player)
	if not data then
		return fail(failure)
	end
	local useFailure: Failure?, coins: number = Aquarium.usePearl(data, pearlId, use :: Types.PearlUse)
	if useFailure then
		return fail(useFailure)
	end
	refresh(player, data)
	if coins > 0 then
		sendCoins(player, data)
	end
	return { ok = true }
end

-- Pays display income and redraws a tank when one of its shells has just ripened.
local function tick(elapsed: number)
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			local coinsPerSecond = Formulas.aquariumCoinsPerSecond(data)
			if coinsPerSecond > 0 then
				data.coins += coinsPerSecond * elapsed
				sendCoins(player, data)
			end
			if ripeCounts[player] and countRipe(data, now) ~= ripeCounts[player] then
				refresh(player, data)
			end
		end
	end
end

local function findPlots()
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if not folder then
		warn(`AquariumService: Workspace.{FOLDER_NAME} is missing; nobody gets a tank`)
		return
	end
	for _, model in folder:GetChildren() do
		local pad = model:FindFirstChild(PAD_NAME)
		if model:IsA("Model") and pad and pad:IsA("BasePart") then
			table.insert(plots, { model = model, pad = pad, owner = nil })
		else
			warn(`AquariumService: {model:GetFullName()} needs to be a Model with a {PAD_NAME} part`)
		end
	end
	table.sort(plots, function(a, b)
		return a.model.Name < b.model.Name
	end)
end

-- Call before DataService.init so the loaded callback sees every player.
function AquariumService.init()
	updateEvent = Remotes.getEvent("AquariumUpdate")
	coinsEvent = Remotes.getEvent("CoinsUpdate")
	Remotes.getFunction("PlaceShells").OnServerInvoke = placeShells
	Remotes.getFunction("OpenShell").OnServerInvoke = openShell
	Remotes.getFunction("UsePearl").OnServerInvoke = usePearl
	findPlots()

	DataService.onLoaded(assignPlot)
	Players.PlayerRemoving:Connect(freePlot)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed >= Economy.AQUARIUM_TICK_SECONDS then
			tick(elapsed)
			elapsed = 0
		end
	end)
end

return AquariumService
