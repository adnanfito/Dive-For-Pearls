--!strict
-- Values at Shallow Beach. Ordered most common first: luck boosts every row except the first.
-- Sell price is derived in Formulas (coinsPerSecond * PEARL_SELL_SECONDS), so it is not stored here.
local Types = require("../Types")

local Pearls: { Types.PearlRarity } = {
	{ id = "White", displayName = "White", chance = 60, coinsPerSecond = 1, equipBonus = 0.05 },
	{ id = "Pink", displayName = "Pink", chance = 25, coinsPerSecond = 3, equipBonus = 0.10 },
	{ id = "Blue", displayName = "Blue", chance = 10, coinsPerSecond = 10, equipBonus = 0.20 },
	{ id = "Gold", displayName = "Gold", chance = 4, coinsPerSecond = 40, equipBonus = 0.40 },
	{ id = "Black", displayName = "Black", chance = 0.9, coinsPerSecond = 200, equipBonus = 0.80 },
	{ id = "Rainbow", displayName = "Rainbow", chance = 0.1, coinsPerSecond = 1_500, equipBonus = 1.50 },
}

return Pearls
