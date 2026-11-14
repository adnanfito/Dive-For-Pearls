--!strict
-- Owns diving: the Bubble Lift, the oxygen timer, the Depth Limit inside a zone and surfacing.
-- The server alone checks zone unlocks, moves characters and measures depth from their position.
-- World layout (built in Studio): Workspace.Dock.{Lift, Arrival} and, per released zone,
-- Workspace.DiveZones.<zoneId>.{Surface, Start, ShellSpots}.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Characters = require(ServerScriptService.Server.Characters)
local DataService = require(ServerScriptService.Server.Services.DataService)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShellService = require(ServerScriptService.Server.Services.ShellService)
local Types = require(ReplicatedStorage.Shared.Types)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

type PlayerData = Types.PlayerData
type LiftResult = Types.LiftResult

type ZoneWorld = {
	start: CFrame,
	surfaceY: number,
	spots: { Vector3 },
}

type Session = {
	zone: Types.Zone,
	world: ZoneWorld,
	character: Model,
	startedAt: number,
	-- Depth Limit only rises inside the chamber, so it is fixed for the whole dive.
	floorY: number,
}

local DOCK_NAME = "Dock"
local LIFT_NAME = "Lift"
local ARRIVAL_NAME = "Arrival"
local ZONES_FOLDER_NAME = "DiveZones"
local SURFACE_NAME = "Surface"
local START_NAME = "Start"
local SPOTS_NAME = "ShellSpots"
local STAND_OFFSET = Vector3.new(0, 3, 0) -- place the character above a marker part, not inside it

local sessions: { [Player]: Session } = {}
local lastLiftAt: { [Player]: number } = {}
local lastSurfaceAt: { [Player]: number } = {}
local updateEvent: RemoteEvent
local liftPart: BasePart? = nil
local arrivalPart: BasePart? = nil
local zoneWorlds: { [string]: ZoneWorld } = {}

local DiveService = {}

local function sendState(player: Player, data: PlayerData, session: Session?, now: number)
	local state: Types.DiveState = {
		diving = session ~= nil,
		zoneId = if session then session.zone.id else nil,
		surfaceY = if session then session.world.surfaceY else 0,
		floorY = if session then session.floorY else 0,
		oxygenLeft = if session
			then math.max(Economy.DIVE_OXYGEN_SECONDS - (now - session.startedAt), 0)
			else Economy.DIVE_OXYGEN_SECONDS,
		carried = ShellService.carriedCount(player),
		bagCount = #data.shellBag,
	}
	updateEvent:FireClient(player, state)
end

local function passCooldown(times: { [Player]: number }, player: Player): boolean
	local now = os.clock()
	if now - (times[player] or -math.huge) < Economy.DIVE_REQUEST_COOLDOWN_SECONDS then
		return false
	end
	times[player] = now
	return true
end

-- With streaming on, the client may not have the destination loaded yet; stream it in first so the
-- diver does not fall through unloaded water or floor. stillValid drops a move that a later
-- request (such as tapping Up right away) has replaced.
local function teleport(player: Player, character: Model, target: CFrame, stillValid: () -> boolean)
	task.spawn(function()
		local ok, err = pcall(player.RequestStreamAroundAsync, player, target.Position)
		if not ok then
			warn(`DiveService: streaming around {target.Position} for {player.Name} ({player.UserId}) failed: {err}`)
		end
		if stillValid() and player.Character == character and Characters.aliveRoot(player) then
			character:PivotTo(target)
		end
	end)
end

local function startDive(player: Player, data: PlayerData, zone: Types.Zone, world: ZoneWorld, character: Model)
	local limitStuds = Formulas.limitStuds(zone, data.depthLimit)
	local now = os.clock()
	local session: Session = {
		zone = zone,
		world = world,
		character = character,
		startedAt = now,
		floorY = world.surfaceY - limitStuds,
	}
	sessions[player] = session
	ShellService.startDive(player, zone, world.spots, world.surfaceY, limitStuds)
	teleport(player, character, world.start, function()
		return sessions[player] == session
	end)
	sendState(player, data, session, now)
end

-- data is nil when the save already closed (player leaving).
local function endDive(player: Player, data: PlayerData?, moveToDock: boolean)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	ShellService.finishDive(player, data)
	local arrival = arrivalPart
	if moveToDock and arrival then
		teleport(player, session.character, arrival.CFrame + STAND_OFFSET, function()
			return sessions[player] == nil
		end)
	end
	if data and player.Parent == Players then
		sendState(player, data, nil, os.clock())
	end
end

local function useLift(player: Player, zoneId: unknown): LiftResult
	if typeof(zoneId) ~= "string" then
		warn(`DiveService: {player.Name} ({player.UserId}) sent bad zone id {zoneId}`)
		return { ok = false, reason = "BadRequest" }
	end
	local data = DataService.get(player)
	if not data then
		return { ok = false, reason = "NotReady" }
	end
	if not passCooldown(lastLiftAt, player) then
		return { ok = false, reason = "TooFast" }
	end
	if sessions[player] then
		return { ok = false, reason = "AlreadyDiving" }
	end
	local zone = Formulas.findZone(zoneId)
	if not zone then
		warn(`DiveService: {player.Name} ({player.UserId}) asked for unknown zone "{zoneId}"`)
		return { ok = false, reason = "BadRequest" }
	end
	if not Formulas.canEnterZone(zone, data.depthLimit) then
		return { ok = false, reason = "Locked" }
	end
	local world = zoneWorlds[zone.id]
	local lift = liftPart
	if not world or not lift then
		return { ok = false, reason = "NoWorld" }
	end
	local root = Characters.aliveRoot(player)
	local character = player.Character
	if not root or not character or (root.Position - lift.Position).Magnitude > Economy.LIFT_RADIUS_STUDS then
		return { ok = false, reason = "TooFar" }
	end
	startDive(player, data, zone, world, character)
	return { ok = true }
end

local function requestSurface(player: Player)
	if not sessions[player] or not passCooldown(lastSurfaceAt, player) then
		return
	end
	endDive(player, DataService.get(player), true)
end

-- The client floats the diver up at the limit; this snaps back only clients that ignore it.
local function enforceLimit(root: BasePart, session: Session)
	local position = root.Position
	if position.Y >= session.floorY - Economy.DEPTH_LIMIT_TOLERANCE_STUDS then
		return
	end
	local target = Vector3.new(position.X, session.floorY, position.Z)
	session.character:PivotTo(CFrame.new(target) * root.CFrame.Rotation)
end

local function tickDiver(player: Player, session: Session, now: number)
	local data = DataService.get(player)
	local root = Characters.aliveRoot(player)
	if not data or not root or player.Character ~= session.character then
		-- Reset or respawned: the new character is already at spawn, and carried shells are kept.
		endDive(player, data, false)
		return
	end
	if now - session.startedAt >= Economy.DIVE_OXYGEN_SECONDS then
		endDive(player, data, true)
		return
	end
	enforceLimit(root, session)
	sendState(player, data, session, now)
end

local function readZoneWorld(model: Instance): ZoneWorld?
	local surface = model:FindFirstChild(SURFACE_NAME)
	local start = model:FindFirstChild(START_NAME)
	local spotsFolder = model:FindFirstChild(SPOTS_NAME)
	if not surface or not surface:IsA("BasePart") or not start or not start:IsA("BasePart") or not spotsFolder then
		warn(
			`DiveService: {model:GetFullName()} needs BaseParts {SURFACE_NAME}, {START_NAME} and a {SPOTS_NAME} folder`
		)
		return nil
	end
	local spots = {}
	for _, spot in spotsFolder:GetChildren() do
		if spot:IsA("BasePart") then
			table.insert(spots, spot.Position)
		end
	end
	return { start = start.CFrame + STAND_OFFSET, surfaceY = surface.Position.Y, spots = spots }
end

local function findDockPart(name: string): BasePart?
	local dock = Workspace:FindFirstChild(DOCK_NAME)
	local part = if dock then dock:FindFirstChild(name) else nil
	if part and part:IsA("BasePart") then
		return part
	end
	warn(`DiveService: Workspace.{DOCK_NAME}.{name} (a BasePart) is missing; the Bubble Lift will not work`)
	return nil
end

local function findWorld()
	liftPart = findDockPart(LIFT_NAME)
	arrivalPart = findDockPart(ARRIVAL_NAME)
	local folder = Workspace:FindFirstChild(ZONES_FOLDER_NAME)
	for _, zone in Zones do
		local model = if folder then folder:FindFirstChild(zone.id) else nil
		local world = if model then readZoneWorld(model) else nil
		if world then
			zoneWorlds[zone.id] = world
		elseif zone.released then
			warn(`DiveService: released zone {zone.id} has no Workspace.{ZONES_FOLDER_NAME}.{zone.id}`)
		end
	end
end

local function forget(player: Player)
	if sessions[player] then
		endDive(player, DataService.get(player), false)
	end
	lastLiftAt[player] = nil
	lastSurfaceAt[player] = nil
end

function DiveService.init()
	updateEvent = Remotes.getEvent("DiveUpdate")
	Remotes.getFunction("UseLift").OnServerInvoke = useLift
	Remotes.getEvent("RequestSurface").OnServerEvent:Connect(requestSurface)
	findWorld()

	-- Leaving mid-dive keeps the carried shells: they are written before the save closes.
	DataService.onReleasing(function(player, data)
		endDive(player, data, false)
	end)
	Players.PlayerRemoving:Connect(forget)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < Economy.DIVE_TICK_SECONDS then
			return
		end
		elapsed = 0
		local now = os.clock()
		for player, session in sessions do
			tickDiver(player, session, now)
		end
	end)
end

return DiveService
