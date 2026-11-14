--!strict
-- Every balancing formula. No Roblox APIs, so Lune can test it. Roll functions take uniform
-- numbers u in [0, 1) from the caller's seeded Random, which keeps RNG on the server.
local Economy = require("./Config/Economy")
local Pearls = require("./Config/Pearls")
local Pets = require("./Config/Pets")
local Shells = require("./Config/Shells")
local Types = require("./Types")

type PearlRarityId = Types.PearlRarityId
type PetRarityId = Types.PetRarityId
type ShellTierId = Types.ShellTierId
type PityState = Types.PityState
type WeightedEntry<T> = Types.WeightedEntry<T>

local pearlById: { [PearlRarityId]: Types.PearlRarity } = {}
for _, row in Pearls do
	pearlById[row.id] = row
end

local petRarityById: { [PetRarityId]: Types.PetRarity } = {}
local petRarityRank: { [string]: number } = {}
for rank, row in Pets.Rarities do
	petRarityById[row.id] = row
	petRarityRank[row.id] = rank
end

local speciesById: { [string]: Types.PetSpecies } = {}
for _, row in Pets.Species do
	speciesById[row.id] = row
end

local EPIC_RANK = petRarityRank.Epic
local LEGENDARY_RANK = petRarityRank.Legendary
local AQUARIUM_MAX_UPGRADES = (Economy.AQUARIUM_MAX_SLOTS - Economy.AQUARIUM_START_SLOTS)
	// Economy.AQUARIUM_SLOTS_PER_UPGRADE

local Formulas = {}

local function checkUnit(u: number, label: string)
	assert(u >= 0 and u < 1, `Formulas: {label} must be in [0, 1), got {u}`)
end

local function pearlRow(rarity: PearlRarityId): Types.PearlRarity
	local row = pearlById[rarity]
	assert(row, `Formulas: unknown pearl rarity "{rarity}"`)
	return row
end

local function petRarityRow(rarity: PetRarityId): Types.PetRarity
	local row = petRarityById[rarity]
	assert(row, `Formulas: unknown pet rarity "{rarity}"`)
	return row
end

function Formulas.pressureRate(level: number, totalBonus: number, afkSeconds: number): number
	local rate = Economy.PRESSURE_BASE_RATE * Economy.PRESSURE_RATE_GROWTH ^ (level - 1) * (1 + totalBonus)
	if afkSeconds >= Economy.PRESSURE_AFK_FATIGUE_SECONDS then
		rate *= Economy.PRESSURE_AFK_FATIGUE_RATE
	end
	return rate
end

-- Cost to go from `level` to `level + 1`, in whole Coins.
function Formulas.pressureUpgradeCost(level: number): number
	return math.floor(Economy.PRESSURE_UPGRADE_BASE_COST * Economy.PRESSURE_UPGRADE_COST_GROWTH ^ (level - 1))
end

function Formulas.pearlCoinsPerSecond(rarity: PearlRarityId, zoneIndex: number): number
	return pearlRow(rarity).coinsPerSecond * Economy.PEARL_ZONE_VALUE_GROWTH ^ zoneIndex
end

function Formulas.pearlSellPrice(rarity: PearlRarityId, zoneIndex: number): number
	return Formulas.pearlCoinsPerSecond(rarity, zoneIndex) * Economy.PEARL_SELL_SECONDS
end

function Formulas.cappedSum(values: { number }, cap: number): number
	local sum = 0
	for _, value in values do
		sum += value
	end
	return math.min(sum, cap)
end

function Formulas.petBonus(rarity: PetRarityId, stars: number): number
	assert(stars >= 1 and stars <= Economy.PET_MAX_STARS, `Formulas: pet stars out of range, got {stars}`)
	return petRarityRow(rarity).bonus * Economy.PET_STAR_BONUS_GROWTH ^ (stars - 1)
end

function Formulas.petSlots(upgrades: number, hasGamePass: boolean): number
	local coinSlots = math.min(Economy.PET_SLOTS_START + upgrades, Economy.PET_SLOTS_COIN_MAX)
	return coinSlots + if hasGamePass then Economy.PET_SLOTS_GAME_PASS_BONUS else 0
end

-- Bonuses add (never multiply); each source is capped separately before adding.
function Formulas.pressureBonus(pearlBonuses: { number }, petBonuses: { number }): number
	return Formulas.cappedSum(pearlBonuses, Economy.PEARL_BONUS_CAP)
		+ Formulas.cappedSum(petBonuses, Economy.PET_BONUS_CAP)
end

function Formulas.aquariumSlots(upgrades: number): number
	return math.min(
		Economy.AQUARIUM_START_SLOTS + Economy.AQUARIUM_SLOTS_PER_UPGRADE * upgrades,
		Economy.AQUARIUM_MAX_SLOTS
	)
end

-- nil once the aquarium is at max slots.
function Formulas.aquariumUpgradeCost(upgrades: number): number?
	if upgrades >= AQUARIUM_MAX_UPGRADES then
		return nil
	end
	return Economy.AQUARIUM_UPGRADE_BASE_COST * Economy.AQUARIUM_UPGRADE_COST_GROWTH ^ upgrades
end

function Formulas.aquariumOfflineCoins(coinsPerSecond: number, offlineSeconds: number): number
	return coinsPerSecond
		* math.min(offlineSeconds, Economy.AQUARIUM_OFFLINE_MAX_SECONDS)
		* Economy.AQUARIUM_OFFLINE_RATE
end

-- Luck sources add like multipliers: x1.5 and x2 combine to x2.5, then the cap applies.
function Formulas.combineLuck(sources: { number }): number
	local luck = 1
	for _, source in sources do
		luck += source - 1
	end
	return math.min(luck, Economy.LUCK_CAP)
end

-- Luck scales every rarity except the most common, then weights are renormalized,
-- so no rarity can exceed LUCK_CAP times its base chance.
local function pearlWeights(luck: number): { WeightedEntry<PearlRarityId> }
	local cappedLuck = math.clamp(luck, 1, Economy.LUCK_CAP)
	local entries: { WeightedEntry<PearlRarityId> } = {}
	for index, row in Pearls do
		local weight = if index == 1 then row.chance else row.chance * cappedLuck
		table.insert(entries, { value = row.id, weight = weight })
	end
	return entries
end

function Formulas.pearlOdds(luck: number): { [PearlRarityId]: number }
	local entries = pearlWeights(luck)
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	local odds: { [PearlRarityId]: number } = {}
	for _, entry in entries do
		odds[entry.value] = entry.weight / total
	end
	return odds
end

-- The type solver widens singleton ids (e.g. "Gold") to string through this generic, so callers
-- cast the result back to their id union; the entries they pass only ever hold valid ids.
function Formulas.rollWeighted<T>(entries: { WeightedEntry<T> }, u: number): T
	checkUnit(u, "u")
	assert(#entries > 0, "Formulas: rollWeighted needs at least one entry")
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	local remaining = u * total
	for _, entry in entries do
		remaining -= entry.weight
		if remaining < 0 then
			return entry.value
		end
	end
	-- Float rounding can leave `remaining` at exactly 0 when u is just below 1.
	return entries[#entries].value
end

function Formulas.rollShellTier(u: number): ShellTierId
	local entries: { WeightedEntry<ShellTierId> } = {}
	for _, row in Shells do
		table.insert(entries, { value = row.id, weight = row.chance })
	end
	return Formulas.rollWeighted(entries, u) :: ShellTierId
end

function Formulas.rollPearl(luck: number, u: number): PearlRarityId
	return Formulas.rollWeighted(pearlWeights(luck), u) :: PearlRarityId
end

local function minPityRank(pity: PityState): number
	if pity.sinceLegendary + 1 >= Economy.PITY_LEGENDARY_HATCHES then
		return LEGENDARY_RANK
	elseif pity.sinceEpic + 1 >= Economy.PITY_EPIC_HATCHES then
		return EPIC_RANK
	end
	return 1
end

local function poolSpeciesOfRarity(egg: Types.Egg, rarity: PetRarityId): { string }
	local matches = {}
	for _, speciesId in egg.pool do
		local species = speciesById[speciesId]
		if species and species.rarity == rarity then
			table.insert(matches, speciesId)
		end
	end
	assert(#matches > 0, `Formulas: egg "{egg.id}" has no {rarity} species`)
	return matches
end

-- Returns the hatched species and a new pity state; the input state is not modified.
function Formulas.rollPet(egg: Types.Egg, pity: PityState, uRarity: number, uSpecies: number): (string, PityState)
	checkUnit(uSpecies, "uSpecies")
	local minRank = minPityRank(pity)
	local entries: { WeightedEntry<PetRarityId> } = {}
	for rank, row in Pets.Rarities do
		if rank >= minRank then
			table.insert(entries, { value = row.id, weight = row.chance })
		end
	end
	local rarity: PetRarityId = Formulas.rollWeighted(entries, uRarity) :: PetRarityId
	local matches = poolSpeciesOfRarity(egg, rarity)
	local speciesId = matches[math.floor(uSpecies * #matches) + 1]

	local rank = petRarityRank[rarity]
	return speciesId,
		{
			sinceEpic = if rank >= EPIC_RANK then 0 else pity.sinceEpic + 1,
			sinceLegendary = if rank >= LEGENDARY_RANK then 0 else pity.sinceLegendary + 1,
		}
end

return Formulas
