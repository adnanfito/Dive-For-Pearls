--!strict
-- Spawns each diver's own shells, validates every pickup and moves carried shells into the saved
-- shellBag when the dive ends. Tiers are rolled here; clients only draw the shells they are sent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Characters = require(ServerScriptService.Server.Characters)
local DataService = require(ServerScriptService.Server.Services.DataService)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerData = Types.PlayerData
type DiveShell = Types.DiveShell
type CollectResult = Types.CollectResult

-- Session-only until the dive ends; carried shells are not saved before that.
type Dive = {
	zoneId: string,
	shells: { [number]: DiveShell },
	carried: { Types.BagShell },
	lastCollectAt: number,
}

local rng = Random.new()
local dives: { [Player]: Dive } = {}
local shellsEvent: RemoteEvent

local ShellService = {}

-- Only spots the diver's Depth Limit can reach, in random order.
local function pickSpots(spots: { Vector3 }, surfaceY: number, limitStuds: number): { Vector3 }
	local reachable = {}
	for _, spot in spots do
		if surfaceY - spot.Y <= limitStuds then
			table.insert(reachable, spot)
		end
	end
	for i = #reachable, 2, -1 do
		local j = rng:NextInteger(1, i)
		reachable[i], reachable[j] = reachable[j], reachable[i]
	end
	return table.move(reachable, 1, math.min(#reachable, Economy.SHELLS_PER_DIVE), 1, {})
end

function ShellService.startDive(
	player: Player,
	zone: Types.Zone,
	spots: { Vector3 },
	surfaceY: number,
	limitStuds: number
)
	local dive: Dive = { zoneId = zone.id, shells = {}, carried = {}, lastCollectAt = -math.huge }
	local sent: { DiveShell } = {}
	for id, position in pickSpots(spots, surfaceY, limitStuds) do
		local fraction = Formulas.zoneDepthFraction(surfaceY - position.Y)
		local shell: DiveShell =
			{ id = id, tier = Formulas.rollShellTier(fraction, rng:NextNumber()), position = position }
		dive.shells[id] = shell
		table.insert(sent, shell)
	end
	dives[player] = dive
	shellsEvent:FireClient(player, sent)
end

-- keep is false when the diver fainted: carried shells are only safe once the diver reaches land.
-- Returns how many carried shells were saved or lost.
function ShellService.finishDive(player: Player, data: PlayerData?, keep: boolean): number
	local dive = dives[player]
	if not dive then
		return 0
	end
	dives[player] = nil
	if player.Parent == Players then
		shellsEvent:FireClient(player, {})
	end
	if not keep then
		return #dive.carried
	end
	if not data then
		if #dive.carried > 0 then
			warn(`ShellService: {player.Name} ({player.UserId}) lost {#dive.carried} carried shells; save closed`)
		end
		return #dive.carried
	end
	for _, shell in dive.carried do
		-- collect() keeps bag + carried within the max, so this only trips if that check breaks.
		if #data.shellBag >= Economy.SHELL_BAG_MAX then
			warn(`ShellService: {player.Name} ({player.UserId}) shellBag full while surfacing; shells dropped`)
			break
		end
		table.insert(data.shellBag, shell)
	end
	return #dive.carried
end

function ShellService.carriedCount(player: Player): number
	local dive = dives[player]
	return if dive then #dive.carried else 0
end

local function isWholeId(value: unknown): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= 1
end

local function collect(player: Player, shellId: unknown): CollectResult
	if not isWholeId(shellId) then
		warn(`ShellService: {player.Name} ({player.UserId}) sent bad shell id {shellId}`)
		return { ok = false, reason = "BadRequest" }
	end
	local dive = dives[player]
	local data = DataService.get(player)
	if not dive or not data then
		return { ok = false, reason = "NotDiving" }
	end
	local now = os.clock()
	if now - dive.lastCollectAt < Economy.SHELL_COLLECT_COOLDOWN_SECONDS then
		return { ok = false, reason = "TooFast" }
	end
	dive.lastCollectAt = now
	local id = shellId :: number
	local shell = dive.shells[id]
	if not shell then
		return { ok = false, reason = "Gone" }
	end
	local root = Characters.aliveRoot(player)
	if not root or (root.Position - shell.position).Magnitude > Economy.SHELL_COLLECT_RADIUS_STUDS then
		return { ok = false, reason = "TooFar" }
	end
	if #data.shellBag + #dive.carried >= Economy.SHELL_BAG_MAX then
		return { ok = false, reason = "BagFull" }
	end
	dive.shells[id] = nil
	table.insert(dive.carried, { tier = shell.tier, zoneId = dive.zoneId })
	return { ok = true }
end

function ShellService.init()
	shellsEvent = Remotes.getEvent("DiveShells")
	Remotes.getFunction("CollectShell").OnServerInvoke = collect
end

return ShellService
