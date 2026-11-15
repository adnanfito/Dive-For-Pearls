--!strict
-- New-player guarantees from GDD "5 menit pertama". Numeric onboarding values live in Economy.
local Types = require("../Types")

type Onboarding = {
	firstPearlRarity: Types.PearlRarityId, -- the first shell a player opens is always this rarity
}

local Onboarding: Onboarding = {
	firstPearlRarity = "Pink",
}

return Onboarding
