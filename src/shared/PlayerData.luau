--!strict
-- Saved player data: defaults, migrations, shape check, repair and validation.
-- No Roblox APIs, so Lune can test it. Only DataService loads and saves this data.
local Economy = require("./Config/Economy")
local Formulas = require("./Formulas")
local Pearls = require("./Config/Pearls")
local Pets = require("./Config/Pets")
local Shells = require("./Config/Shells")
local Types = require("./Types")
local Zones = require("./Config/Zones")

type PlayerData = Types.PlayerData
type RawData = { [string]: any }

export type Migration = (data: RawData) -> RawData
export type LoadFailure = { ok: false, reason: "Newer" | "Unreadable", detail: string }
export type LoadResult = {
	ok: true,
	data: PlayerData,
	isNew: boolean,
	fixes: { string }, -- what repair changed
	warnings: { string }, -- problems left in place because fixing them could lose items
} | LoadFailure

local CURRENT_VERSION = 1

-- MIGRATIONS[n] turns version n data into version n + 1. Never edit a shipped step; add a new one.
local MIGRATIONS: { Migration } = {}

local function idSet(rows: { any }): { [string]: boolean }
	local set = {}
	for _, row in rows do
		set[row.id] = true
	end
	return set
end

local PEARL_IDS = idSet(Pearls)
local SHELL_IDS = idSet(Shells)
local SPECIES_IDS = idSet(Pets.Species)
local ZONE_IDS = idSet(Zones)

local TOP_FIELDS = {
	version = "number",
	depthLimit = "number",
	coins = "number",
	eggTickets = "number",
	pressureLevel = "number",
	aquarium = "table",
	shellBag = "table",
	pearls = "table",
	equippedPearls = "table",
	pets = "table",
	equippedPets = "table",
	petSlotUpgrades = "number",
	pity = "table",
	nextItemId = "number",
	lastOnlineAt = "number",
	onboarding = "table",
	playtimeRewards = "table",
	groupRewardClaimed = "boolean",
	redeemedCodes = "table",
	purchaseIds = "table",
}
local AQUARIUM_FIELDS = { upgrades = "number", shells = "table", displayedPearls = "table" }
local AQUARIUM_SHELL_FIELDS = { tier = "string", zoneId = "string", readyAt = "number" }
local BAG_SHELL_FIELDS = { tier = "string", zoneId = "string" }
local PEARL_FIELDS = { rarity = "string", zoneId = "string" }
local PET_FIELDS = { species = "string", stars = "number" }
local PITY_FIELDS = { sinceEpic = "number", sinceLegendary = "number" }
local ONBOARDING_FIELDS = { instantShellsLeft = "number", freeEggClaimed = "boolean" }
local PLAYTIME_FIELDS = { day = "number", seconds = "number", claimed = "table" }

local PlayerData = {}

PlayerData.CURRENT_VERSION = CURRENT_VERSION

function PlayerData.default(now: number): PlayerData
	return {
		version = CURRENT_VERSION,
		depthLimit = 0,
		coins = 0,
		eggTickets = 0,
		pressureLevel = 1,
		aquarium = { upgrades = 0, shells = {}, displayedPearls = {} },
		shellBag = {},
		pearls = {},
		equippedPearls = {},
		pets = {},
		equippedPets = {},
		petSlotUpgrades = 0,
		pity = { sinceEpic = 0, sinceLegendary = 0 },
		nextItemId = 1,
		lastOnlineAt = now,
		onboarding = { instantShellsLeft = Economy.ONBOARDING_INSTANT_SHELLS, freeEggClaimed = false },
		playtimeRewards = { day = 0, seconds = 0, claimed = {} },
		groupRewardClaimed = false,
		redeemedCodes = {},
		purchaseIds = {},
	}
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[key] = deepCopy(item)
	end
	return copy
end

local function fail(reason: "Newer" | "Unreadable", detail: string): LoadFailure
	return { ok = false, reason = reason, detail = detail }
end

-- Exposed with an injectable migration list so tests can run fake steps.
function PlayerData.runMigrations(raw: RawData, migrations: { Migration }, target: number): (RawData?, LoadFailure?)
	local version = raw.version
	if type(version) ~= "number" or version < 1 or version % 1 ~= 0 then
		return nil, fail("Unreadable", `bad version {version}`)
	end
	if version > target then
		return nil, fail("Newer", `version {version} is newer than {target}`)
	end
	local data = raw
	for step = version, target - 1 do
		local migrate = migrations[step]
		if not migrate then
			return nil, fail("Unreadable", `no migration from version {step}`)
		end
		data = migrate(data)
		data.version = step + 1
	end
	return data, nil
end

local function checkFields(value: any, fields: { [string]: string }, path: string): string?
	if type(value) ~= "table" then
		return `{path} should be table, got {type(value)}`
	end
	for key, expected in fields do
		if type(value[key]) ~= expected then
			return `{path}.{key} should be {expected}, got {type(value[key])}`
		end
	end
	return nil
end

local function checkEach(collection: any, keyType: string, path: string, checkItem: (any, string) -> string?): string?
	if type(collection) ~= "table" then
		return `{path} should be table, got {type(collection)}`
	end
	for key, item in collection do
		if type(key) ~= keyType then
			return `{path} has a {type(key)} key, expected {keyType}`
		end
		local problem = checkItem(item, `{path}[{key}]`)
		if problem then
			return problem
		end
	end
	return nil
end

local function record(fields: { [string]: string }): (any, string) -> string?
	return function(item, path)
		return checkFields(item, fields, path)
	end
end

local function primitive(expected: string): (any, string) -> string?
	return function(item, path)
		return if type(item) == expected then nil else `{path} should be {expected}, got {type(item)}`
	end
end

-- Returns the first type problem, or nil when every field has the right type.
function PlayerData.checkShape(data: any): string?
	return checkFields(data, TOP_FIELDS, "data")
		or checkFields(data.aquarium, AQUARIUM_FIELDS, "aquarium")
		or checkFields(data.pity, PITY_FIELDS, "pity")
		or checkFields(data.onboarding, ONBOARDING_FIELDS, "onboarding")
		or checkFields(data.playtimeRewards, PLAYTIME_FIELDS, "playtimeRewards")
		or checkEach(data.aquarium.shells, "number", "aquarium.shells", record(AQUARIUM_SHELL_FIELDS))
		or checkEach(data.aquarium.displayedPearls, "number", "aquarium.displayedPearls", primitive("string"))
		or checkEach(data.shellBag, "number", "shellBag", record(BAG_SHELL_FIELDS))
		or checkEach(data.pearls, "string", "pearls", record(PEARL_FIELDS))
		or checkEach(data.equippedPearls, "number", "equippedPearls", primitive("string"))
		or checkEach(data.pets, "string", "pets", record(PET_FIELDS))
		or checkEach(data.equippedPets, "number", "equippedPets", primitive("string"))
		or checkEach(data.playtimeRewards.claimed, "number", "playtimeRewards.claimed", primitive("number"))
		or checkEach(data.redeemedCodes, "string", "redeemedCodes", primitive("boolean"))
		or checkEach(data.purchaseIds, "number", "purchaseIds", primitive("string"))
end

-- NaN and infinity cannot be saved as JSON, so they fall back to the minimum.
local function fixNumber(
	fixes: { string },
	path: string,
	value: number,
	min: number,
	max: number,
	whole: boolean
): number
	local fixed
	if value ~= value or value == math.huge or value == -math.huge then
		fixed = min
	else
		fixed = math.clamp(value, min, max)
		fixed = if whole then math.floor(fixed) else fixed
	end
	if fixed ~= value then
		table.insert(fixes, `{path}: {value} -> {fixed}`)
	end
	return fixed
end

local function repairCounters(data: PlayerData, fixes: { string })
	local INF = math.huge
	data.depthLimit = fixNumber(fixes, "depthLimit", data.depthLimit, 0, INF, false)
	data.coins = fixNumber(fixes, "coins", data.coins, 0, INF, false)
	data.eggTickets = fixNumber(fixes, "eggTickets", data.eggTickets, 0, INF, true)
	data.pressureLevel = fixNumber(fixes, "pressureLevel", data.pressureLevel, 1, INF, true)
	data.aquarium.upgrades = fixNumber(fixes, "aquarium.upgrades", data.aquarium.upgrades, 0, INF, true)
	data.petSlotUpgrades = fixNumber(fixes, "petSlotUpgrades", data.petSlotUpgrades, 0, INF, true)
	data.pity.sinceEpic = fixNumber(fixes, "pity.sinceEpic", data.pity.sinceEpic, 0, INF, true)
	data.pity.sinceLegendary = fixNumber(fixes, "pity.sinceLegendary", data.pity.sinceLegendary, 0, INF, true)
	data.nextItemId = fixNumber(fixes, "nextItemId", data.nextItemId, 1, INF, true)
	data.lastOnlineAt = fixNumber(fixes, "lastOnlineAt", data.lastOnlineAt, 0, INF, false)
	local onboarding = data.onboarding
	onboarding.instantShellsLeft =
		fixNumber(fixes, "onboarding.instantShellsLeft", onboarding.instantShellsLeft, 0, INF, true)
	local playtime = data.playtimeRewards
	playtime.day = fixNumber(fixes, "playtimeRewards.day", playtime.day, 0, INF, true)
	playtime.seconds = fixNumber(fixes, "playtimeRewards.seconds", playtime.seconds, 0, INF, false)
end

local function repairItems(data: PlayerData, fixes: { string })
	for index, shell in data.aquarium.shells do
		shell.readyAt = fixNumber(fixes, `aquarium.shells[{index}].readyAt`, shell.readyAt, 0, math.huge, false)
	end
	for id, pet in data.pets do
		pet.stars = fixNumber(fixes, `pets[{id}].stars`, pet.stars, 1, Economy.PET_MAX_STARS, true)
	end
end

-- A new id must never reuse an owned one, or the new item would overwrite it.
local function repairNextItemId(data: PlayerData, fixes: { string })
	local highest = 0
	for _, items in { data.pearls :: { [string]: any }, data.pets :: { [string]: any } } do
		for id in items do
			highest = math.max(highest, tonumber(id) or 0)
		end
	end
	if data.nextItemId <= highest then
		table.insert(fixes, `nextItemId: {data.nextItemId} -> {highest + 1}`)
		data.nextItemId = highest + 1
	end
end

-- Keeps ids that point at an owned item and were not already used by an earlier list.
local function keepValidRefs(
	list: { string },
	owned: { [string]: any },
	used: { [string]: boolean },
	path: string,
	fixes: { string }
): { string }
	local kept = {}
	for _, id in list do
		if owned[id] ~= nil and not used[id] then
			used[id] = true
			table.insert(kept, id)
		else
			table.insert(fixes, `{path}: dropped reference {id}`)
		end
	end
	return kept
end

-- Fixes problems that can be fixed without removing an owned item. Returns what it changed.
function PlayerData.repair(data: PlayerData): { string }
	local fixes = {}
	repairCounters(data, fixes)
	repairItems(data, fixes)
	repairNextItemId(data, fixes)
	-- A pearl is either equipped or displayed, never both. If a save has both, the pearl stays equipped.
	local usedPearls = {}
	data.equippedPearls = keepValidRefs(data.equippedPearls, data.pearls, usedPearls, "equippedPearls", fixes)
	data.aquarium.displayedPearls =
		keepValidRefs(data.aquarium.displayedPearls, data.pearls, usedPearls, "aquarium.displayedPearls", fixes)
	data.equippedPets = keepValidRefs(data.equippedPets, data.pets, {}, "equippedPets", fixes)
	return fixes
end

local function countKeys(map: { [string]: any }): number
	local count = 0
	for _ in map do
		count += 1
	end
	return count
end

local function checkLimit(problems: { string }, label: string, count: number, limit: number)
	if count > limit then
		table.insert(problems, `{label}: {count} is over the limit of {limit}`)
	end
end

local function checkShellIds(shells: { Types.BagShell | Types.AquariumShell }, path: string, problems: { string })
	for index, shell in shells do
		if not SHELL_IDS[shell.tier] or not ZONE_IDS[shell.zoneId] then
			table.insert(problems, `{path}[{index}]: unknown tier {shell.tier} or zone {shell.zoneId}`)
		end
	end
end

local function checkContentIds(data: PlayerData, problems: { string })
	for id, pearl in data.pearls do
		if not PEARL_IDS[pearl.rarity] or not ZONE_IDS[pearl.zoneId] then
			table.insert(problems, `pearls[{id}]: unknown rarity {pearl.rarity} or zone {pearl.zoneId}`)
		end
	end
	for id, pet in data.pets do
		if not SPECIES_IDS[pet.species] then
			table.insert(problems, `pets[{id}]: unknown species {pet.species}`)
		end
	end
	checkShellIds(data.aquarium.shells, "aquarium.shells", problems)
	checkShellIds(data.shellBag, "shellBag", problems)
end

-- Problems repair leaves alone because fixing them means removing items. Callers warn; content
-- removed from Config needs a migration, not a silent delete.
function PlayerData.validate(data: PlayerData): { string }
	local problems = {}
	checkContentIds(data, problems)
	checkLimit(problems, "pearls", countKeys(data.pearls), Economy.PEARL_INVENTORY_MAX)
	checkLimit(problems, "pets", countKeys(data.pets), Economy.PET_INVENTORY_MAX)
	checkLimit(problems, "shellBag", #data.shellBag, Economy.SHELL_BAG_MAX)
	checkLimit(problems, "equippedPearls", #data.equippedPearls, Economy.PEARL_EQUIP_SLOTS_START)
	checkLimit(problems, "equippedPets", #data.equippedPets, Formulas.petSlots(data.petSlotUpgrades, true))
	checkLimit(
		problems,
		"aquarium",
		#data.aquarium.shells + #data.aquarium.displayedPearls,
		Formulas.aquariumSlots(data.aquarium.upgrades)
	)
	return problems
end

-- Works on a copy, so a rejected save stays untouched and is written back as it was.
function PlayerData.load(raw: any, now: number): LoadResult
	if type(raw) ~= "table" then
		return fail("Unreadable", `data should be table, got {type(raw)}`)
	end
	if next(raw) == nil then
		return { ok = true, data = PlayerData.default(now), isNew = true, fixes = {}, warnings = {} }
	end
	local migrated, failure = PlayerData.runMigrations(deepCopy(raw), MIGRATIONS, CURRENT_VERSION)
	if not migrated then
		return failure :: LoadFailure
	end
	local shapeProblem = PlayerData.checkShape(migrated)
	if shapeProblem then
		return fail("Unreadable", shapeProblem)
	end
	local data = (migrated :: any) :: PlayerData
	local fixes = PlayerData.repair(data)
	return { ok = true, data = data, isNew = false, fixes = fixes, warnings = PlayerData.validate(data) }
end

function PlayerData.newItemId(data: PlayerData): string
	local id = tostring(data.nextItemId)
	data.nextItemId += 1
	return id
end

return PlayerData
