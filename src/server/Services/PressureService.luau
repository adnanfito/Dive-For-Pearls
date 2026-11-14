--!strict
-- Owns the Pressure Chamber. The server alone decides who stands inside (from the character's
-- position), raises depthLimit, mirrors it to leaderstats, and sells chamber levels for Coins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DataService = require(ServerScriptService.Server.Services.DataService)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerData = Types.PlayerData
type UpgradeResult = Types.PressureUpgradeResult

-- Session-only: the 2-hour slowdown restarts when the player steps out or leaves the game.
type Session = {
	inside: boolean,
	afkSeconds: number,
	lastUpgradeAt: number,
	depthStat: IntValue,
}

local CHAMBER_NAME = "PressureChamber"
local ZONE_NAME = "Zone"
local LEADERSTATS_NAME = "leaderstats" -- the name Roblox's player list looks for
local DEPTH_STAT_NAME = "Depth"

local sessions: { [Player]: Session } = {}
local updateEvent: RemoteEvent
local zonePart: BasePart? = nil

local PressureService = {}

local function isInside(player: Player, zone: BasePart): boolean
	local character = player.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false
	end
	local offset = zone.CFrame:PointToObjectSpace((root :: BasePart).Position)
	local half = zone.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

local function sendState(player: Player, data: PlayerData, session: Session, gained: number)
	local state: Types.PressureState = {
		inside = session.inside,
		depthLimit = data.depthLimit,
		gained = gained,
		level = data.pressureLevel,
		upgradeCost = Formulas.pressureUpgradeCost(data.pressureLevel),
		coins = data.coins,
	}
	updateEvent:FireClient(player, state)
end

local function tickPlayer(player: Player, session: Session, zone: BasePart, elapsed: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	local wasInside = session.inside
	session.inside = isInside(player, zone)
	if not session.inside then
		session.afkSeconds = 0
		if wasInside then
			sendState(player, data, session, 0)
		end
		return
	end
	local bonus = Formulas.equippedPressureBonus(data)
	local gained = Formulas.pressureRate(data.pressureLevel, bonus, session.afkSeconds) * elapsed
	session.afkSeconds += elapsed
	data.depthLimit += gained
	session.depthStat.Value = math.floor(data.depthLimit)
	sendState(player, data, session, gained)
end

local function startSession(player: Player, data: PlayerData)
	if player.Parent ~= Players then
		return
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = LEADERSTATS_NAME
	local depthStat = Instance.new("IntValue")
	depthStat.Name = DEPTH_STAT_NAME
	depthStat.Value = math.floor(data.depthLimit)
	depthStat.Parent = leaderstats
	leaderstats.Parent = player

	local session: Session = { inside = false, afkSeconds = 0, lastUpgradeAt = -math.huge, depthStat = depthStat }
	sessions[player] = session
	sendState(player, data, session, 0)
end

local function isWholeLevel(value: unknown): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= 1
end

local function buyUpgrade(player: Player, expectedLevel: unknown): UpgradeResult
	if not isWholeLevel(expectedLevel) then
		warn(`PressureService: {player.Name} ({player.UserId}) sent bad upgrade level {expectedLevel}`)
		return { ok = false, reason = "BadRequest" }
	end
	local session = sessions[player]
	local data = DataService.get(player)
	if not session or not data then
		return { ok = false, reason = "NotReady" }
	end
	local now = os.clock()
	if now - session.lastUpgradeAt < Economy.PRESSURE_UPGRADE_COOLDOWN_SECONDS then
		return { ok = false, reason = "TooFast" }
	end
	session.lastUpgradeAt = now
	-- A double tap sends the same level twice; only the first one buys.
	if expectedLevel ~= data.pressureLevel then
		return { ok = false, reason = "Stale" }
	end
	local cost = Formulas.pressureUpgradeCost(data.pressureLevel)
	if data.coins < cost then
		return { ok = false, reason = "NotEnoughCoins" }
	end
	data.coins -= cost
	data.pressureLevel += 1
	sendState(player, data, session, 0)
	return { ok = true }
end

local function findZone(): BasePart?
	local chamber = Workspace:FindFirstChild(CHAMBER_NAME)
	local zone = if chamber then chamber:FindFirstChild(ZONE_NAME) else nil
	if zone and zone:IsA("BasePart") then
		return zone
	end
	warn(`PressureService: Workspace.{CHAMBER_NAME}.{ZONE_NAME} (a BasePart) is missing; depth will not rise`)
	return nil
end

-- Call before DataService.init so the loaded callback sees every player.
function PressureService.init()
	updateEvent = Remotes.getEvent("PressureUpdate")
	Remotes.getFunction("BuyPressureUpgrade").OnServerInvoke = buyUpgrade
	zonePart = findZone()

	DataService.onLoaded(startSession)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		local zone = zonePart
		if elapsed < Economy.PRESSURE_TICK_SECONDS or not zone then
			return
		end
		for player, session in sessions do
			tickPlayer(player, session, zone, elapsed)
		end
		elapsed = 0
	end)
end

return PressureService
