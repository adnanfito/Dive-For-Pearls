--!strict
-- Config validator: odds sum to 100%, rows have every field, references resolve, caps hold.
local Assert = require("./Assert")
local Economy = require("../src/shared/Config/Economy")
local Eggs = require("../src/shared/Config/Eggs")
local Pearls = require("../src/shared/Config/Pearls")
local Pets = require("../src/shared/Config/Pets")
local Shells = require("../src/shared/Config/Shells")
local Zones = require("../src/shared/Config/Zones")

local PERCENT_TOTAL = 100
local EPSILON = 1e-9

local function checkRows(rows: { any }, schema: { [string]: string }, label: string)
	Assert.isTrue(#rows > 0, `{label} is empty`)
	local seen = {}
	for index, row in rows do
		for field, fieldType in schema do
			Assert.equal(typeof(row[field]), fieldType, `{label}[{index}].{field} type`)
		end
		Assert.isTrue(not seen[row.id], `{label}: duplicate id {row.id}`)
		seen[row.id] = true
	end
end

local function checkChances(rows: { any }, label: string)
	local total = 0
	for _, row in rows do
		Assert.isTrue(row.chance > 0, `{label} {row.id} chance must be positive`)
		total += row.chance
	end
	Assert.near(total, PERCENT_TOTAL, EPSILON, `{label} chances sum`)
end

local function checkMostCommonFirst(rows: { any }, label: string)
	for index = 2, #rows do
		Assert.isTrue(rows[index].chance <= rows[index - 1].chance, `{label} must be ordered most common first`)
	end
end

local function indexById(rows: { any }): { [string]: number }
	local map = {}
	for index, row in rows do
		map[row.id] = index
	end
	return map
end

return {
	{
		name = "zones: fields, start at 0, strictly ascending",
		run = function()
			checkRows(
				Zones,
				{ id = "string", displayName = "string", startDepth = "number", released = "boolean" },
				"Zones"
			)
			Assert.equal(Zones[1].startDepth, 0, "first zone startDepth")
			for index = 2, #Zones do
				Assert.isTrue(Zones[index].startDepth > Zones[index - 1].startDepth, `Zones[{index}] ascending`)
			end
		end,
	},
	{
		name = "pearls: fields, odds sum to 100%, order, bonus within cap",
		run = function()
			checkRows(Pearls, {
				id = "string",
				displayName = "string",
				chance = "number",
				coinsPerSecond = "number",
				equipBonus = "number",
			}, "Pearls")
			checkChances(Pearls, "Pearls")
			checkMostCommonFirst(Pearls, "Pearls")
			for _, row in Pearls do
				Assert.isTrue(row.coinsPerSecond > 0, `Pearls {row.id} coinsPerSecond`)
				Assert.isTrue(row.equipBonus > 0 and row.equipBonus <= Economy.PEARL_BONUS_CAP, `Pearls {row.id} bonus`)
			end
		end,
	},
	{
		name = "shells: fields, odds sum to 100%, luck within cap",
		run = function()
			checkRows(Shells, {
				id = "string",
				displayName = "string",
				chance = "number",
				ripenSeconds = "number",
				pearlLuck = "number",
			}, "Shells")
			checkChances(Shells, "Shells")
			for _, row in Shells do
				Assert.isTrue(row.ripenSeconds > 0, `Shells {row.id} ripenSeconds`)
				Assert.isTrue(row.pearlLuck >= 1 and row.pearlLuck <= Economy.LUCK_CAP, `Shells {row.id} luck`)
			end
		end,
	},
	{
		name = "pets: fields, odds sum to 100%, species rarities exist, max-star bonus within cap",
		run = function()
			checkRows(
				Pets.Rarities,
				{ id = "string", displayName = "string", chance = "number", bonus = "number" },
				"Pet rarities"
			)
			checkRows(Pets.Species, { id = "string", displayName = "string", rarity = "string" }, "Pet species")
			checkChances(Pets.Rarities, "Pet rarities")
			checkMostCommonFirst(Pets.Rarities, "Pet rarities")
			local rarityIndex = indexById(Pets.Rarities)
			Assert.isTrue(rarityIndex.Epic ~= nil and rarityIndex.Legendary ~= nil, "pity rarities exist")
			for _, species in Pets.Species do
				Assert.isTrue(rarityIndex[species.rarity] ~= nil, `species {species.id} rarity {species.rarity}`)
			end
			for _, row in Pets.Rarities do
				local maxBonus = row.bonus * Economy.PET_STAR_BONUS_GROWTH ^ (Economy.PET_MAX_STARS - 1)
				Assert.isTrue(row.bonus > 0 and maxBonus <= Economy.PET_BONUS_CAP, `Pet rarity {row.id} bonus`)
			end
		end,
	},
	{
		name = "eggs: zone exists, cost = zone index + 1, pool valid and covers every rarity",
		run = function()
			checkRows(
				Eggs,
				{ id = "string", displayName = "string", zoneId = "string", ticketCost = "number", pool = "table" },
				"Eggs"
			)
			local zoneIndex = indexById(Zones)
			local speciesIndex = indexById(Pets.Species)
			for _, egg in Eggs do
				local zone = zoneIndex[egg.zoneId]
				Assert.isTrue(zone ~= nil, `egg {egg.id} zone {egg.zoneId}`)
				Assert.equal(egg.ticketCost, zone, `egg {egg.id} ticketCost`)

				local covered, seen = {}, {}
				for _, speciesId in egg.pool do
					Assert.isTrue(not seen[speciesId], `egg {egg.id} duplicate {speciesId}`)
					seen[speciesId] = true
					local index = speciesIndex[speciesId]
					Assert.isTrue(index ~= nil, `egg {egg.id} unknown species {speciesId}`)
					covered[Pets.Species[index].rarity] = true
				end
				for _, rarity in Pets.Rarities do
					Assert.isTrue(covered[rarity.id] == true, `egg {egg.id} has no {rarity.id} species`)
				end
			end
		end,
	},
	{
		name = "economy: constants positive and consistent",
		run = function()
			for key, value in Economy :: { [string]: number } do
				Assert.isTrue(typeof(value) == "number" and value > 0, `Economy.{key} must be a positive number`)
			end
			Assert.isTrue(Economy.PRESSURE_AFK_FATIGUE_RATE <= 1, "AFK fatigue rate <= 1")
			Assert.isTrue(Economy.AQUARIUM_OFFLINE_RATE <= 1, "offline rate <= 1")
			Assert.equal(
				(Economy.AQUARIUM_MAX_SLOTS - Economy.AQUARIUM_START_SLOTS) % Economy.AQUARIUM_SLOTS_PER_UPGRADE,
				0,
				"aquarium max slots reachable"
			)
			Assert.isTrue(Economy.PEARL_EQUIP_SLOTS_START <= Economy.PEARL_EQUIP_SLOTS_MAX, "equip slots range")
			Assert.isTrue(Economy.PITY_EPIC_HATCHES < Economy.PITY_LEGENDARY_HATCHES, "pity order")
		end,
	},
}
