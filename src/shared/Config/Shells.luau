--!strict
local Types = require("../Types")

local MINUTE = 60
local HOUR = 60 * MINUTE

local Shells: { Types.ShellTier } = {
	{ id = "Common", displayName = "Common", chance = 70, ripenSeconds = 1 * MINUTE, pearlLuck = 1 },
	{ id = "Glowing", displayName = "Glowing", chance = 22, ripenSeconds = 10 * MINUTE, pearlLuck = 1.5 },
	{ id = "Rare", displayName = "Rare", chance = 7, ripenSeconds = 1 * HOUR, pearlLuck = 2 },
	{ id = "Giant", displayName = "Giant", chance = 1, ripenSeconds = 6 * HOUR, pearlLuck = 3 },
}

return Shells
