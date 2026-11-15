--!strict
-- Owns diving. A dive starts when a character goes under a zone's water and ends when the diver
-- climbs back onto land (shells safe), takes the bottom portal to the next zone (shells safe), or
-- runs out of air or dies (fainted: carried shells are lost). The server alone measures positions,
-- checks unlocks and moves characters.
-- World layout (built in Studio): Workspace.Dock.{Lift, Arrival} and, per released zone,
-- Workspace.DiveZones.<zoneId>.{Surface, ShellSpots} plus, where they exist, Start (cave ledge
-- the lift and portal arrive on), Portal (gate at the bottom) and ReturnLift (cave lift back to
-- the dock, with a ProximityPrompt).
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
	zone: Types.Zone,
	surface: BasePart, -- its footprint is the zone's water area; its height is the water line
	start: CFrame?,
	portal: Vector3?,
	spots: { Vector3 },
}

type Session = {
	world: ZoneWorld,
	character: Model,
	startedAt: number,
	-- Depth Limit only rises inside the chamber, so it is fixed for the whole dive.
	floorY: number,
	portalNoticeAt: number,
}

local DOCK_NAME = "Dock"
local LIFT_NAME = "Lift"
local ARRIVAL_NAME = "Arrival"
local ZONES_FOLDER_NAME = "DiveZones"
local SURFACE_NAME = "Surface"
local START_NAME = "Start"
local PORTAL_NAME = "Portal"
local RETURN_LIFT_NAME = "ReturnLift"
local SPOTS_NAME = "ShellSpots"
local STAND_OFFSET = Vector3.new(0, 3, 0) -- place the character above a marker part, not inside it

local sessions: { [Player]: Session } = {}
local lastLiftAt: { [Player]: number } = {}
local updateEvent: RemoteEvent
local noticeEvent: RemoteEvent
local liftPart: BasePart? = nil
local arrivalPart: BasePart? = nil
local zoneWorlds: { ZoneWorld } = {}

local DiveService = {}

local function sendState(player: Player, data: PlayerData, session: Session?, now: number)
	local state: Types.DiveState = {
		diving = session ~= nil,
		zoneId = if session then session.world.zone.id else nil,
		surfaceY = if session then session.world.surface.Position.Y else 0,
		floorY = if session then session.floorY else 0,
		oxygenLeft = if session
			then math.max(Economy.DIVE_OXYGEN_SECONDS - (now - session.startedAt), 0)
			else Economy.DIVE_OXYGEN_SECONDS,
		carried = ShellService.carriedCount(player),
		bagCount = #data.shellBag,
	}
	updateEvent:FireClient(player, state)
end

local function sendNotice(player: Player, kind: Types.DiveNoticeKind, shells: number, need: number)
	if player.Parent == Players then
		local notice: Types.DiveNotice = { kind = kind, shells = shells, needDepth = need }
		noticeEvent:FireClient(player, notice)
	end
end

-- With streaming on, the client may not have the destination loaded yet; stream it in first so the
-- character does not fall through unloaded floor. stillValid drops a move a later event replaced.
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

local function moveToDock(player: Player, character: Model)
	local arrival = arrivalPart
	if arrival then
		teleport(player, character, arrival.CFrame + STAND_OFFSET, function()
			return sessions[player] == nil
		end)
	end
end

local function startDive(player: Player, data: PlayerData, world: ZoneWorld, character: Model, now: number)
	local surfaceY = world.surface.Position.Y
	local limitStuds = Formulas.limitStuds(world.zone, data.depthLimit)
	local session: Session = {
		world = world,
		character = character,
		startedAt = now,
		floorY = surfaceY - limitStuds,
		portalNoticeAt = -math.huge,
	}
	sessions[player] = session
	ShellService.startDive(player, world.zone, world.spots, surfaceY, limitStuds)
	sendState(player, data, session, now)
end

-- data is nil when the save already closed (player leaving).
local function endDive(player: Player, data: PlayerData?, safe: boolean)
	if not sessions[player] then
		return
	end
	sessions[player] = nil
	local shells = ShellService.finishDive(player, data, safe)
	sendNotice(player, if safe then "Safe" else "Fainted", shells, 0)
	if data and player.Parent == Players then
		sendState(player, data, nil, os.clock())
	end
end

local function findWorld(zone: Types.Zone): ZoneWorld?
	for _, world in zoneWorlds do
		if world.zone == zone then
			return world
		end
	end
	return nil
end

-- The released zone whose water the position is in, if any.
local function waterAt(position: Vector3): ZoneWorld?
	for _, world in zoneWorlds do
		local offset = world.surface.CFrame:PointToObjectSpace(position)
		local half = world.surface.Size / 2
		if
			math.abs(offset.X) <= half.X
			and math.abs(offset.Z) <= half.Z
			and offset.Y < -Economy.DIVE_START_DEPTH_STUDS
		then
			return world
		end
	end
	return nil
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
	local now = os.clock()
	if now - (lastLiftAt[player] or -math.huge) < Economy.DIVE_REQUEST_COOLDOWN_SECONDS then
		return { ok = false, reason = "TooFast" }
	end
	lastLiftAt[player] = now
	if sessions[player] then
		return { ok = false, reason = "AlreadyDiving" }
	end
	local zone = Formulas.findZone(zoneId)
	if not zone or not Formulas.hasLiftStop(zone) then
		warn(`DiveService: {player.Name} ({player.UserId}) asked the lift for zone "{zoneId}"`)
		return { ok = false, reason = "BadRequest" }
	end
	if not Formulas.canEnterZone(zone, data.depthLimit) then
		return { ok = false, reason = "Locked" }
	end
	local world = findWorld(zone)
	local lift = liftPart
	local start = if world then world.start else nil
	if not start or not lift then
		return { ok = false, reason = "NoWorld" }
	end
	local root = Characters.aliveRoot(player)
	local character = player.Character
	if not root or not character or (root.Position - lift.Position).Magnitude > Economy.LIFT_RADIUS_STUDS then
		return { ok = false, reason = "TooFar" }
	end
	teleport(player, character, start, function()
		return sessions[player] == nil
	end)
	return { ok = true }
end

-- The portal ends the dive with the shells safe, because the diver arrives on the next cave's ledge.
local function tryPortal(player: Player, data: PlayerData, session: Session, root: BasePart, now: number)
	local portal = session.world.portal
	local nextZone = Formulas.nextZone(session.world.zone)
	if not portal or not nextZone or (root.Position - portal).Magnitude > Economy.PORTAL_RADIUS_STUDS then
		return
	end
	local nextWorld = findWorld(nextZone)
	local start = if nextWorld then nextWorld.start else nil
	if not start or not Formulas.canEnterZone(nextZone, data.depthLimit) then
		if now - session.portalNoticeAt >= Economy.PORTAL_NOTICE_COOLDOWN_SECONDS then
			session.portalNoticeAt = now
			sendNotice(player, if nextZone.released then "PortalLocked" else "PortalSoon", 0, nextZone.startDepth)
		end
		return
	end
	local character = session.character
	endDive(player, data, true)
	teleport(player, character, start, function()
		return sessions[player] == nil
	end)
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

local function tickDiver(player: Player, data: PlayerData, session: Session, now: number)
	local root = Characters.aliveRoot(player)
	if not root or player.Character ~= session.character then
		-- Died or reset under water: that counts as fainting, and the respawn is already at spawn.
		endDive(player, data, false)
		return
	end
	if now - session.startedAt >= Economy.DIVE_OXYGEN_SECONDS then
		local character = session.character
		endDive(player, data, false)
		moveToDock(player, character)
		return
	end
	if root.Position.Y >= session.world.surface.Position.Y + Economy.SURFACE_CLEARANCE_STUDS then
		endDive(player, data, true)
		return
	end
	tryPortal(player, data, session, root, now)
	if sessions[player] == session then
		enforceLimit(root, session)
		sendState(player, data, session, now)
	end
end

local function tickPlayer(player: Player, now: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	local session = sessions[player]
	if session then
		tickDiver(player, data, session, now)
		return
	end
	local root = Characters.aliveRoot(player)
	local character = player.Character
	local world = if root then waterAt(root.Position) else nil
	if not world or not character then
		return
	end
	if Formulas.canEnterZone(world.zone, data.depthLimit) then
		startDive(player, data, world, character, now)
	else
		-- Locked zones are only reachable through checked lifts and portals, so this is a bug or a cheat.
		warn(`DiveService: {player.Name} ({player.UserId}) was in locked zone {world.zone.id}; sent to the dock`)
		moveToDock(player, character)
	end
end

local function useReturnLift(player: Player, liftPosition: Vector3)
	local root = Characters.aliveRoot(player)
	local character = player.Character
	if sessions[player] or not root or not character then
		return
	end
	if (root.Position - liftPosition).Magnitude > Economy.LIFT_RADIUS_STUDS then
		return
	end
	moveToDock(player, character)
end

local function partIn(parent: Instance, name: string): BasePart?
	local part = parent:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

local function readZoneWorld(zone: Types.Zone, model: Instance): ZoneWorld?
	local surface = partIn(model, SURFACE_NAME)
	local spotsFolder = model:FindFirstChild(SPOTS_NAME)
	if not surface or not spotsFolder then
		warn(`DiveService: {model:GetFullName()} needs a BasePart {SURFACE_NAME} and a {SPOTS_NAME} folder`)
		return nil
	end
	local spots = {}
	for _, spot in spotsFolder:GetChildren() do
		if spot:IsA("BasePart") then
			table.insert(spots, spot.Position)
		end
	end
	local start = partIn(model, START_NAME)
	local portal = partIn(model, PORTAL_NAME)
	local returnLift = partIn(model, RETURN_LIFT_NAME)
	local prompt = if returnLift then returnLift:FindFirstChildOfClass("ProximityPrompt") else nil
	if prompt and returnLift then
		local liftPosition = returnLift.Position
		prompt.Triggered:Connect(function(player)
			useReturnLift(player, liftPosition)
		end)
	end
	return {
		zone = zone,
		surface = surface,
		start = if start then start.CFrame + STAND_OFFSET else nil,
		portal = if portal then portal.Position else nil,
		spots = spots,
	}
end

local function findDockPart(name: string): BasePart?
	local dock = Workspace:FindFirstChild(DOCK_NAME)
	local part = if dock then partIn(dock, name) else nil
	if not part then
		warn(`DiveService: Workspace.{DOCK_NAME}.{name} (a BasePart) is missing; the Bubble Lift will not work`)
	end
	return part
end

local function readWorld()
	liftPart = findDockPart(LIFT_NAME)
	arrivalPart = findDockPart(ARRIVAL_NAME)
	local folder = Workspace:FindFirstChild(ZONES_FOLDER_NAME)
	for _, zone in Zones do
		local model = if folder then folder:FindFirstChild(zone.id) else nil
		local world = if model and zone.released then readZoneWorld(zone, model) else nil
		if world then
			table.insert(zoneWorlds, world)
		elseif zone.released then
			warn(`DiveService: released zone {zone.id} has no usable Workspace.{ZONES_FOLDER_NAME}.{zone.id}`)
		end
	end
end

function DiveService.init()
	updateEvent = Remotes.getEvent("DiveUpdate")
	noticeEvent = Remotes.getEvent("DiveNotice")
	Remotes.getFunction("UseLift").OnServerInvoke = useLift
	readWorld()

	-- Leaving mid-dive keeps the carried shells: they are written before the save closes.
	DataService.onReleasing(function(player, data)
		endDive(player, data, true)
	end)
	Players.PlayerRemoving:Connect(function(player)
		endDive(player, DataService.get(player), true)
		lastLiftAt[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < Economy.DIVE_TICK_SECONDS then
			return
		end
		elapsed = 0
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			tickPlayer(player, now)
		end
	end)
end

return DiveService
