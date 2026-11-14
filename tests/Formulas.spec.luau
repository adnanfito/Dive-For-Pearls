--!strict
local Assert = require("./Assert")
local Economy = require("../src/shared/Config/Economy")
local Eggs = require("../src/shared/Config/Eggs")
local Formulas = require("../src/shared/Formulas")
local Pearls = require("../src/shared/Config/Pearls")
local Pets = require("../src/shared/Config/Pets")
local PlayerData = require("../src/shared/PlayerData")

local EPSILON = 1e-9
local CORAL_REEF_INDEX = 1

-- Sell prices exactly as listed in GDD "Balancing awal" (Shallow Beach).
local GDD_SELL_PRICES = { White = 30, Pink = 90, Blue = 300, Gold = 1_200, Black = 6_000, Rainbow = 45_000 }

local function speciesRarity(speciesId: string): string
	for _, species in Pets.Species do
		if species.id == speciesId then
			return species.rarity
		end
	end
	error(`unknown species {speciesId}`)
end

return {
	{
		name = "pressure rate: base, growth, bonus, AFK fatigue",
		run = function()
			Assert.near(Formulas.pressureRate(1, 0, 0), 0.5, EPSILON, "level 1")
			Assert.near(Formulas.pressureRate(2, 0, 0), 0.575, EPSILON, "level 2")
			Assert.near(Formulas.pressureRate(1, 0.5, 0), 0.75, EPSILON, "level 1 +50%")
			Assert.near(Formulas.pressureRate(1, 0, 7_199), 0.5, EPSILON, "just before fatigue")
			Assert.near(Formulas.pressureRate(1, 0, 7_200), 0.375, EPSILON, "fatigue at 2h")
		end,
	},
	{
		name = "pressure upgrade cost: 20 * 1.25^(level-1), whole coins",
		run = function()
			Assert.equal(Formulas.pressureUpgradeCost(1), 20, "level 1")
			Assert.equal(Formulas.pressureUpgradeCost(2), 25, "level 2")
			Assert.equal(Formulas.pressureUpgradeCost(3), 31, "level 3 floors 31.25")
		end,
	},
	{
		name = "pearl value scales 4^zone and sell price matches GDD table",
		run = function()
			Assert.equal(Formulas.pearlCoinsPerSecond("White", 0), 1, "White at Shallow Beach")
			Assert.equal(Formulas.pearlCoinsPerSecond("White", CORAL_REEF_INDEX), 4, "White at Coral Reef")
			Assert.equal(Formulas.pearlSellPrice("Rainbow", CORAL_REEF_INDEX), 180_000, "Rainbow sell at Coral Reef")
			for _, row in Pearls do
				Assert.equal(Formulas.pearlSellPrice(row.id, 0), GDD_SELL_PRICES[row.id], `{row.id} sell price`)
			end
		end,
	},
	{
		name = "bonuses add and each source is capped",
		run = function()
			Assert.near(Formulas.cappedSum({ 0.1, 0.2 }, 1), 0.3, EPSILON, "under cap")
			Assert.near(Formulas.pressureBonus({ 1.5, 1.5, 1.5 }, {}), Economy.PEARL_BONUS_CAP, EPSILON, "pearl cap")
			Assert.near(Formulas.pressureBonus({}, { 0.5, 0.5, 0.5 }), Economy.PET_BONUS_CAP, EPSILON, "pet cap")
			Assert.near(Formulas.pressureBonus({ 0.05 }, { 0.02 }), 0.07, EPSILON, "pearl + pet add")
		end,
	},
	{
		name = "equipped pressure bonus: pearls + pets, capped, unknown ids skipped",
		run = function()
			local data = PlayerData.default(0)
			Assert.equal(Formulas.equippedPressureBonus(data), 0, "nothing equipped")

			local commonSpecies = Pets.Species[1].id
			assert(speciesRarity(commonSpecies) == "Common", "first species should be Common")
			data.pearls["1"] = { rarity = "Gold", zoneId = "ShallowBeach" }
			data.pets["2"] = { species = commonSpecies, stars = 1 }
			data.equippedPearls = { "1", "99" }
			data.equippedPets = { "2" }
			Assert.near(Formulas.equippedPressureBonus(data), 0.42, EPSILON, "Gold pearl + 1-star Common pet")

			for id = 3, 5 do
				data.pearls[tostring(id)] = { rarity = "Rainbow", zoneId = "ShallowBeach" }
			end
			data.equippedPearls = { "3", "4", "5" }
			data.equippedPets = {}
			Assert.near(Formulas.equippedPressureBonus(data), Economy.PEARL_BONUS_CAP, EPSILON, "pearl cap")
		end,
	},
	{
		name = "zone progress: current zone, next zone, fraction",
		run = function()
			local start = Formulas.zoneProgress(0)
			Assert.equal(start.current.id, "ShallowBeach", "at 0 m")
			Assert.equal((start.nextZone :: any).id, "CoralReef", "next after beach")
			Assert.near(start.fraction, 0, EPSILON, "empty bar at 0 m")
			Assert.near(Formulas.zoneProgress(25).fraction, 0.5, EPSILON, "half way to Coral Reef")

			local reef = Formulas.zoneProgress(125)
			Assert.equal(reef.current.id, "CoralReef", "at 125 m")
			Assert.near(reef.fraction, 0.5, EPSILON, "half way from 50 to 200")
			Assert.equal(Formulas.zoneProgress(50).current.id, "CoralReef", "threshold belongs to the new zone")

			local last = Formulas.zoneProgress(1e12)
			Assert.equal(last.nextZone, nil, "no zone after the last")
			Assert.equal(last.fraction, 1, "full bar past the last zone")
		end,
	},
	{
		name = "zone entry: released, has a map, depth limit reaches its start",
		run = function()
			local beach = Formulas.findZone("ShallowBeach") :: any
			local reef = Formulas.findZone("CoralReef") :: any
			local twilight = Formulas.findZone("TwilightZone") :: any
			Assert.equal(Formulas.findZone("Nowhere"), nil, "unknown zone")
			Assert.isTrue(Formulas.canEnterZone(beach, 0), "beach at 0 m")
			Assert.isTrue(not Formulas.canEnterZone(reef, 49.9), "reef just below 50 m")
			Assert.isTrue(Formulas.canEnterZone(reef, 50), "reef at 50 m")
			Assert.isTrue(not Formulas.canEnterZone(twilight, 1e9), "unreleased zone stays locked")
		end,
	},
	{
		name = "zone depth: studs to meters, limit in studs, depth fraction",
		run = function()
			local beach = Formulas.findZone("ShallowBeach") :: any
			local reef = Formulas.findZone("CoralReef") :: any
			Assert.near(Formulas.depthAt(beach, 20), 10, EPSILON, "20 studs at 0.5 m/stud")
			Assert.near(Formulas.depthAt(reef, 100), 200, EPSILON, "reef bottom is 200 m")
			Assert.near(Formulas.depthAt(reef, -5), 50, EPSILON, "above the surface counts as the start")
			Assert.near(Formulas.limitStuds(beach, Economy.START_DEPTH_LIMIT), 20, EPSILON, "new player at beach")
			Assert.near(Formulas.limitStuds(reef, 124), 74 / 1.5, EPSILON, "124 m in the reef")
			Assert.near(Formulas.limitStuds(reef, 1e6), Economy.ZONE_HEIGHT_STUDS, EPSILON, "capped at the map")
			Assert.near(Formulas.zoneDepthFraction(50), 0.5, EPSILON, "half way down")
			Assert.near(Formulas.zoneDepthFraction(500), 1, EPSILON, "clamped at the bottom")
		end,
	},
	{
		name = "pet bonus grows x1.5 per star, stars limited to 1..3",
		run = function()
			Assert.near(Formulas.petBonus("Common", 1), 0.02, EPSILON, "1 star")
			Assert.near(Formulas.petBonus("Common", 3), 0.045, EPSILON, "3 stars")
			Assert.throws(function()
				Formulas.petBonus("Common", 4)
			end, "4 stars")
		end,
	},
	{
		name = "pet slots: 1 to start, Coins up to 3",
		run = function()
			Assert.equal(Formulas.petSlots(0), 1, "start")
			Assert.equal(Formulas.petSlots(2), 3, "max")
			Assert.equal(Formulas.petSlots(5), 3, "upgrades past max add nothing")
		end,
	},
	{
		name = "aquarium: slots, cost, cap at 40, offline income",
		run = function()
			Assert.equal(Formulas.aquariumSlots(0), 8, "start slots")
			Assert.equal(Formulas.aquariumSlots(16), 40, "max slots")
			Assert.equal(Formulas.aquariumSlots(20), 40, "slots never exceed max")
			Assert.equal(Formulas.aquariumUpgradeCost(0), 100, "first upgrade")
			Assert.equal(Formulas.aquariumUpgradeCost(15), 3_276_800, "last upgrade")
			Assert.equal(Formulas.aquariumUpgradeCost(16), nil, "no upgrade past max")
			Assert.equal(Formulas.aquariumOfflineCoins(10, 60), 300, "half rate offline")
			Assert.equal(Formulas.aquariumOfflineCoins(1, 24 * 60 * 60), 4 * 60 * 60, "capped at 8h")
		end,
	},
	{
		name = "luck adds and caps at x3",
		run = function()
			Assert.near(Formulas.combineLuck({}), 1, EPSILON, "no sources")
			Assert.near(Formulas.combineLuck({ 1.5, 2 }), 2.5, EPSILON, "1.5 + 2")
			Assert.near(Formulas.combineLuck({ 3, 2 }), Economy.LUCK_CAP, EPSILON, "capped")
		end,
	},
	{
		name = "pearl odds: base at x1, renormalized and within 3x base at cap",
		run = function()
			local base = Formulas.pearlOdds(1)
			for _, row in Pearls do
				Assert.near(base[row.id], row.chance / 100, EPSILON, `{row.id} base odds`)
			end
			local lucky = Formulas.pearlOdds(10)
			local total = 0
			for _, row in Pearls do
				total += lucky[row.id]
				Assert.isTrue(lucky[row.id] <= Economy.LUCK_CAP * row.chance / 100 + EPSILON, `{row.id} within 3x`)
			end
			Assert.near(total, 1, EPSILON, "odds sum to 1")
			Assert.near(lucky.Pink, 75 / 180, EPSILON, "Pink at x3")
		end,
	},
	{
		name = "rollWeighted: boundaries and input checks",
		run = function()
			local entries = { { value = "a", weight = 1 }, { value = "b", weight = 3 } }
			Assert.equal(Formulas.rollWeighted(entries, 0), "a", "u = 0")
			Assert.equal(Formulas.rollWeighted(entries, 0.2499), "a", "just below split")
			Assert.equal(Formulas.rollWeighted(entries, 0.25), "b", "at split")
			Assert.equal(Formulas.rollWeighted(entries, 0.9999999), "b", "u near 1")
			Assert.throws(function()
				Formulas.rollWeighted(entries, 1)
			end, "u = 1 rejected")
		end,
	},
	{
		name = "pet pity: 20th hatch forced Epic+, 120th forced Legendary+, counters reset",
		run = function()
			local egg = Eggs[1]
			local commonRoll = 0

			local species, pity = Formulas.rollPet(egg, { sinceEpic = 0, sinceLegendary = 0 }, commonRoll, 0)
			Assert.equal(speciesRarity(species), "Common", "no pity at start")
			Assert.equal(pity.sinceEpic, 1, "epic counter grows")

			local epicSpecies, afterEpic = Formulas.rollPet(egg, { sinceEpic = 19, sinceLegendary = 19 }, commonRoll, 0)
			Assert.equal(speciesRarity(epicSpecies), "Epic", "20th hatch forced to Epic+")
			Assert.equal(afterEpic.sinceEpic, 0, "epic counter reset")
			Assert.equal(afterEpic.sinceLegendary, 20, "legendary counter keeps growing")

			local legendarySpecies, afterLegendary =
				Formulas.rollPet(egg, { sinceEpic = 5, sinceLegendary = 119 }, commonRoll, 0)
			Assert.equal(speciesRarity(legendarySpecies), "Legendary", "120th hatch forced to Legendary+")
			Assert.equal(afterLegendary.sinceEpic, 0, "legendary also resets epic counter")
			Assert.equal(afterLegendary.sinceLegendary, 0, "legendary counter reset")
		end,
	},
	{
		name = "rollPet does not modify the input pity state",
		run = function()
			local pity = { sinceEpic = 3, sinceLegendary = 3 }
			Formulas.rollPet(Eggs[1], pity, 0, 0)
			Assert.equal(pity.sinceEpic, 3, "sinceEpic unchanged")
			Assert.equal(pity.sinceLegendary, 3, "sinceLegendary unchanged")
		end,
	},
}
