--!strict
-- How each pearl rarity looks, shared by the tank display (server) and the aquarium screens (client)
-- so a rarity has one color everywhere (GDD "Visual dan UX"). Presentation only, not balancing.
local Types = require("./Types")

export type Look = {
	color: Color3,
	glow: Color3,
	rainbow: boolean,
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 70)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 230, 100)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 200, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(150, 110, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 110, 220)),
})

local WHITE: Look = { color = Color3.fromRGB(248, 246, 238), glow = Color3.fromRGB(255, 255, 255), rainbow = false }

local LOOKS: { [Types.PearlRarityId]: Look } = {
	White = WHITE,
	Pink = { color = Color3.fromRGB(255, 165, 200), glow = Color3.fromRGB(255, 140, 190), rainbow = false },
	Blue = { color = Color3.fromRGB(95, 175, 255), glow = Color3.fromRGB(90, 170, 255), rainbow = false },
	Gold = { color = Color3.fromRGB(255, 205, 60), glow = Color3.fromRGB(255, 200, 60), rainbow = false },
	Black = { color = Color3.fromRGB(50, 45, 70), glow = Color3.fromRGB(160, 110, 255), rainbow = false },
	Rainbow = { color = Color3.fromRGB(255, 255, 255), glow = Color3.fromRGB(255, 220, 255), rainbow = true },
}

local PearlLooks = {}

PearlLooks.RAINBOW = RAINBOW

function PearlLooks.of(rarity: Types.PearlRarityId): Look
	return LOOKS[rarity] or WHITE
end

return PearlLooks
