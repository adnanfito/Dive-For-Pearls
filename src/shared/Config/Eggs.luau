--!strict
-- One egg per released zone; ticket cost = zone index + 1. Both MVP eggs share one pool until
-- zone-specific species are designed. Every pool must cover every pet rarity.
local Types = require("../Types")

local STARTER_POOL = {
	"Clownfish",
	"Crab",
	"Dolphin",
	"Seal",
	"Turtle",
	"Otter",
	"HumpbackWhale",
	"MantaRay",
	"SeaDragon",
	"LittleKraken",
}

local Eggs: { Types.Egg } = {
	{ id = "BeachEgg", displayName = "Beach Egg", zoneId = "ShallowBeach", ticketCost = 1, pool = STARTER_POOL },
	{ id = "ReefEgg", displayName = "Reef Egg", zoneId = "CoralReef", ticketCost = 2, pool = STARTER_POOL },
}

return Eggs
