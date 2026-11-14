--!strict
-- 100,000 seeded rolls per table; each observed frequency must sit within 4 standard deviations
-- of its expected probability, which a correct roller fails less than once in ~15,000 checks.
local Assert = require("./Assert")
local Economy = require("../src/shared/Config/Economy")
local Eggs = require("../src/shared/Config/Eggs")
local Formulas = require("../src/shared/Formulas")
local Pets = require("../src/shared/Config/Pets")
local Shells = require("../src/shared/Config/Shells")

local ROLLS = 100_000
local SIGMA_LIMIT = 4
local SEED = 20261114

local rarityOfSpecies: { [string]: string } = {}
local rarityRank: { [string]: number } = {}
for _, species in Pets.Species do
	rarityOfSpecies[species.id] = species.rarity
end
for rank, row in Pets.Rarities do
	rarityRank[row.id] = rank
end

local function checkDistribution(counts: { [string]: number }, expected: { [string]: number }, label: string)
	for id, probability in expected do
		local observed = (counts[id] or 0) / ROLLS
		local tolerance = SIGMA_LIMIT * math.sqrt(probability * (1 - probability) / ROLLS)
		Assert.near(observed, probability, tolerance, `{label} {id}`)
	end
end

local function countPearls(luck: number): { [string]: number }
	math.randomseed(SEED)
	local counts = {}
	for _ = 1, ROLLS do
		local rarity = Formulas.rollPearl(luck, math.random())
		counts[rarity] = (counts[rarity] or 0) + 1
	end
	return counts
end

return {
	{
		name = "pearls at x1 luck match base odds",
		run = function()
			checkDistribution(countPearls(1), Formulas.pearlOdds(1), "pearl x1")
		end,
	},
	{
		name = "pearls at x3 luck match renormalized odds",
		run = function()
			checkDistribution(countPearls(Economy.LUCK_CAP), Formulas.pearlOdds(Economy.LUCK_CAP), "pearl x3")
		end,
	},
	{
		name = "shell tiers match config odds",
		run = function()
			math.randomseed(SEED)
			local counts = {}
			for _ = 1, ROLLS do
				local tier = Formulas.rollShellTier(0, math.random())
				counts[tier] = (counts[tier] or 0) + 1
			end
			local expected = {}
			for _, row in Shells do
				expected[row.id] = row.chance / 100
			end
			checkDistribution(counts, expected, "shell")
		end,
	},
	{
		name = "shell tiers at a zone's bottom scale non-Common odds by 1 + DEEP_SHELL_BONUS",
		run = function()
			math.randomseed(SEED)
			local counts = {}
			for _ = 1, ROLLS do
				local tier = Formulas.rollShellTier(1, math.random())
				counts[tier] = (counts[tier] or 0) + 1
			end
			local scale = 1 + Economy.DEEP_SHELL_BONUS
			local total = 0
			for index, row in Shells do
				total += if index == 1 then row.chance else row.chance * scale
			end
			local expected = {}
			for index, row in Shells do
				expected[row.id] = (if index == 1 then row.chance else row.chance * scale) / total
			end
			checkDistribution(counts, expected, "deep shell")
		end,
	},
	{
		name = "pets without pity match config odds",
		run = function()
			math.randomseed(SEED)
			local freshPity = { sinceEpic = 0, sinceLegendary = 0 }
			local counts = {}
			for _ = 1, ROLLS do
				local species = Formulas.rollPet(Eggs[1], freshPity, math.random(), math.random())
				local rarity = rarityOfSpecies[species]
				counts[rarity] = (counts[rarity] or 0) + 1
			end
			local expected = {}
			for _, row in Pets.Rarities do
				expected[row.id] = row.chance / 100
			end
			checkDistribution(counts, expected, "pet")
		end,
	},
	{
		name = "pets with pity never exceed the pity streak limits",
		run = function()
			math.randomseed(SEED)
			local pity = { sinceEpic = 0, sinceLegendary = 0 }
			local runWithoutEpic, runWithoutLegendary = 0, 0
			local longestWithoutEpic, longestWithoutLegendary = 0, 0
			for _ = 1, ROLLS do
				local species
				species, pity = Formulas.rollPet(Eggs[1], pity, math.random(), math.random())
				local rank = rarityRank[rarityOfSpecies[species]]
				runWithoutEpic = if rank >= rarityRank.Epic then 0 else runWithoutEpic + 1
				runWithoutLegendary = if rank >= rarityRank.Legendary then 0 else runWithoutLegendary + 1
				longestWithoutEpic = math.max(longestWithoutEpic, runWithoutEpic)
				longestWithoutLegendary = math.max(longestWithoutLegendary, runWithoutLegendary)
			end
			Assert.isTrue(longestWithoutEpic <= Economy.PITY_EPIC_HATCHES - 1, `Epic streak {longestWithoutEpic}`)
			Assert.isTrue(
				longestWithoutLegendary <= Economy.PITY_LEGENDARY_HATCHES - 1,
				`Legendary streak {longestWithoutLegendary}`
			)
		end,
	},
}
