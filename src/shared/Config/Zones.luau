--!strict
-- Row order is the zone index used by pearl value scaling (Shallow Beach = 0).
-- metersPerStud: how many meters one stud of the zone map is worth. Every zone map is
-- Economy.ZONE_HEIGHT_STUDS tall, so its depth range is that height times this scale.
-- Released zones must set it (checked in Config.spec).
local Types = require("../Types")

local Zones: { Types.Zone } = {
	{ id = "ShallowBeach", displayName = "Shallow Beach", startDepth = 0, released = true, metersPerStud = 0.5 },
	{ id = "CoralReef", displayName = "Coral Reef", startDepth = 50, released = true, metersPerStud = 1.5 },
	{ id = "TwilightZone", displayName = "Twilight Zone", startDepth = 200, released = false },
	{ id = "MidnightZone", displayName = "Midnight Zone", startDepth = 1_000, released = false },
	{ id = "Abyss", displayName = "The Abyss", startDepth = 4_000, released = false },
	{ id = "MarianaTrench", displayName = "Mariana Trench", startDepth = 11_000, released = false },
	{ id = "Atlantis", displayName = "Atlantis", startDepth = 50_000, released = false },
	{ id = "CrystalSea", displayName = "Crystal Sea", startDepth = 1_000_000, released = false },
	{ id = "LavaSea", displayName = "Lava Sea", startDepth = 20_000_000, released = false },
	{ id = "StarSea", displayName = "Star Sea", startDepth = 400_000_000, released = false },
}

return Zones
