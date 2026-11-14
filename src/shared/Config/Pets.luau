--!strict
-- Rarities are ordered lowest to highest; pity compares ranks by this order.
-- Every pet bonus feeds the Pressure Chamber multiplier.
local Types = require("../Types")

local Rarities: { Types.PetRarity } = {
	{ id = "Common", displayName = "Common", chance = 55, bonus = 0.02 },
	{ id = "Rare", displayName = "Rare", chance = 30, bonus = 0.04 },
	{ id = "Epic", displayName = "Epic", chance = 12, bonus = 0.08 },
	{ id = "Legendary", displayName = "Legendary", chance = 2.7, bonus = 0.15 },
	{ id = "Mythic", displayName = "Mythic", chance = 0.3, bonus = 0.25 },
}

local Species: { Types.PetSpecies } = {
	{ id = "Clownfish", displayName = "Clownfish", rarity = "Common" },
	{ id = "Crab", displayName = "Crab", rarity = "Common" },
	{ id = "Dolphin", displayName = "Dolphin", rarity = "Rare" },
	{ id = "Seal", displayName = "Seal", rarity = "Rare" },
	{ id = "Turtle", displayName = "Turtle", rarity = "Epic" },
	{ id = "Otter", displayName = "Otter", rarity = "Epic" },
	{ id = "HumpbackWhale", displayName = "Humpback Whale", rarity = "Legendary" },
	{ id = "MantaRay", displayName = "Manta Ray", rarity = "Legendary" },
	{ id = "SeaDragon", displayName = "Sea Dragon", rarity = "Mythic" },
	{ id = "LittleKraken", displayName = "Little Kraken", rarity = "Mythic" },
}

return {
	Rarities = Rarities,
	Species = Species,
}
