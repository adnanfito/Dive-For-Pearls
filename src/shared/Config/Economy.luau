--!strict
-- Scalar balancing constants from GDD "Balancing awal". Per-row content lives in the sibling Config modules.

local HOUR = 60 * 60

return {
	PRESSURE_BASE_RATE = 0.5, -- meters per second at level 1
	PRESSURE_RATE_GROWTH = 1.15,
	PRESSURE_UPGRADE_BASE_COST = 20,
	PRESSURE_UPGRADE_COST_GROWTH = 1.25,
	PRESSURE_AFK_FATIGUE_SECONDS = 2 * HOUR,
	PRESSURE_AFK_FATIGUE_RATE = 0.75,
	-- Timings, not balancing: depth gain is rate * elapsed time, so the tick length does not change it.
	PRESSURE_TICK_SECONDS = 1,
	PRESSURE_UPGRADE_COOLDOWN_SECONDS = 0.25,
	DEV_TEST_COINS = 1_000, -- Studio-only test grant, see DevService
	DEV_TEST_DEPTH = 50, -- Studio-only test grant in meters, see DevService
	START_DEPTH_LIMIT = 10, -- lets a new player dive at Shallow Beach before the chamber

	DIVE_OXYGEN_SECONDS = 90,
	SHELLS_PER_DIVE = 12,
	DEEP_SHELL_BONUS = 1.0, -- non-Common shell odds reach 1 + this at the bottom of a zone
	ZONE_HEIGHT_STUDS = 100, -- every zone map is this tall; Zones.metersPerStud sets its meters
	-- Timings and tolerances, not balancing.
	DIVE_TICK_SECONDS = 0.25,
	DIVE_REQUEST_COOLDOWN_SECONDS = 1,
	LIFT_RADIUS_STUDS = 15,
	-- Generous because the server sees the character slightly behind where the client drew it.
	SHELL_COLLECT_RADIUS_STUDS = 10,
	SHELL_TOUCH_RADIUS_STUDS = 5, -- how close the client gets before it asks to collect
	SHELL_COLLECT_COOLDOWN_SECONDS = 0.1,
	DEPTH_LIMIT_TOLERANCE_STUDS = 4, -- the server snaps a diver back only past this
	DEPTH_PUSH_SPEED = 12, -- studs per second the client floats a diver up from the limit
	DIVE_DOWN_SPEED = 16, -- studs per second while the dive button is held
	DIVE_START_DEPTH_STUDS = 2, -- a dive starts once the character is this far under the water
	-- A diver is back on land (and the shells are safe) once this far above the water line;
	-- a swimmer at the surface floats lower than this.
	SURFACE_CLEARANCE_STUDS = 2.5,
	PORTAL_RADIUS_STUDS = 8,
	PORTAL_NOTICE_COOLDOWN_SECONDS = 3,

	PEARL_ZONE_VALUE_GROWTH = 4,
	PEARL_SELL_SECONDS = 30, -- sell price equals this many seconds of display income
	PEARL_EQUIP_SLOTS_START = 1,
	PEARL_EQUIP_SLOTS_MAX = 3,
	PEARL_BONUS_CAP = 3.0,

	LUCK_CAP = 3,

	PET_BONUS_CAP = 1.0,
	PET_STAR_BONUS_GROWTH = 1.5,
	PET_MAX_STARS = 3,
	PITY_EPIC_HATCHES = 20,
	PITY_LEGENDARY_HATCHES = 120,
	PET_SLOTS_START = 1,
	PET_SLOTS_COIN_MAX = 3,
	PET_INVENTORY_MAX = 200,
	PEARL_INVENTORY_MAX = 300,
	SHELL_BAG_MAX = 20, -- shells wait here while the aquarium is full
	ONBOARDING_INSTANT_SHELLS = 5, -- a new player's first shells ripen at once

	AQUARIUM_START_SLOTS = 8,
	AQUARIUM_SLOTS_PER_UPGRADE = 2,
	AQUARIUM_MAX_SLOTS = 40,
	AQUARIUM_UPGRADE_BASE_COST = 100,
	AQUARIUM_UPGRADE_COST_GROWTH = 2,
	AQUARIUM_OFFLINE_RATE = 0.5,
	AQUARIUM_OFFLINE_MAX_SECONDS = 8 * HOUR,
	-- Timings and tolerances, not balancing.
	AQUARIUM_TICK_SECONDS = 1,
	AQUARIUM_ACTION_COOLDOWN_SECONDS = 0.2,
	AQUARIUM_RADIUS_STUDS = 16, -- how close to their own tank pad a player must be to use it
}
