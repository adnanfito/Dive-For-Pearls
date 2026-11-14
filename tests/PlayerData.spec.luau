--!strict
local serde = require("@lune/serde")

local Assert = require("./Assert")
local Economy = require("../src/shared/Config/Economy")
local PlayerData = require("../src/shared/PlayerData")
local Types = require("../src/shared/Types")

local NOW = 1_700_000_000

local function withItems(): Types.PlayerData
	local data = PlayerData.default(NOW)
	local pearlId = PlayerData.newItemId(data)
	data.pearls[pearlId] = { rarity = "Gold", zoneId = "CoralReef" }
	data.equippedPearls = { pearlId }
	local displayedId = PlayerData.newItemId(data)
	data.pearls[displayedId] = { rarity = "White", zoneId = "ShallowBeach" }
	data.aquarium.displayedPearls = { displayedId }
	data.aquarium.shells = { { tier = "Rare", zoneId = "ShallowBeach", readyAt = NOW + 3_600 } }
	data.shellBag = { { tier = "Common", zoneId = "CoralReef" } }
	local petId = PlayerData.newItemId(data)
	data.pets[petId] = { species = "Dolphin", stars = 2 }
	data.equippedPets = { petId }
	data.redeemedCodes = { WELCOME = true }
	data.purchaseIds = { "receipt-1" }
	data.playtimeRewards.claimed = { 5, 15 }
	return data
end

local function loadOk(raw: any): Types.PlayerData
	local result = PlayerData.load(raw, NOW)
	assert(result.ok, "expected load to succeed")
	return result.data
end

local function loadFailure(raw: any): PlayerData.LoadFailure
	local result = PlayerData.load(raw, NOW)
	assert(not result.ok, "expected load to fail")
	return result
end

return {
	{
		name = "player data: empty profile becomes default data",
		run = function()
			local result = PlayerData.load({}, NOW)
			assert(result.ok, "load ok")
			Assert.isTrue(result.isNew, "isNew")
			Assert.equal(result.data.version, PlayerData.CURRENT_VERSION, "version")
			Assert.equal(result.data.lastOnlineAt, NOW, "lastOnlineAt")
			Assert.equal(result.data.onboarding.instantShellsLeft, Economy.ONBOARDING_INSTANT_SHELLS, "instant shells")
		end,
	},
	{
		name = "player data: default and filled data pass every check",
		run = function()
			for label, data in { default = PlayerData.default(NOW), filled = withItems() } do
				Assert.equal(PlayerData.checkShape(data), nil, `{label} shape`)
				Assert.equal(#PlayerData.repair(data), 0, `{label} repair fixes`)
				Assert.equal(#PlayerData.validate(data), 0, `{label} validate problems`)
			end
		end,
	},
	{
		name = "player data: survives a JSON round trip like a DataStore save",
		run = function()
			local original = withItems()
			local data = loadOk(serde.decode("json", serde.encode("json", original)))
			Assert.equal(data.pearls[original.equippedPearls[1]].rarity, "Gold", "equipped pearl")
			Assert.equal(data.aquarium.shells[1].readyAt, NOW + 3_600, "shell readyAt")
			Assert.equal(data.pets[data.equippedPets[1]].stars, 2, "pet stars")
			Assert.equal(data.redeemedCodes.WELCOME, true, "redeemed code")
			Assert.equal(data.nextItemId, original.nextItemId, "nextItemId")
		end,
	},
	{
		name = "player data: load rejects unreadable and newer saves without touching them",
		run = function()
			Assert.equal(loadFailure("oops").reason, "Unreadable", "not a table")
			Assert.equal(loadFailure({ coins = 5 }).reason, "Unreadable", "missing version")

			local newer = withItems() :: any
			newer.version = PlayerData.CURRENT_VERSION + 1
			Assert.equal(loadFailure(newer).reason, "Newer", "newer version")

			local broken = withItems() :: any
			broken.pets["3"].stars = "two"
			local failure = loadFailure(broken)
			Assert.equal(failure.reason, "Unreadable", "wrong field type")
			Assert.isTrue(string.find(failure.detail, "pets[3].stars", 1, true) ~= nil, "detail names the field")
			Assert.equal(broken.pets["3"].stars, "two", "raw data unchanged")
		end,
	},
	{
		name = "player data: migrations run in order and stop at a missing step",
		run = function()
			local migrations: { PlayerData.Migration } = {
				function(data)
					data.trail = "a"
					return data
				end,
				function(data)
					data.trail ..= "b"
					return data
				end,
			}
			local migrated = PlayerData.runMigrations({ version = 1 }, migrations, 3)
			assert(migrated, "migrated")
			Assert.equal(migrated.trail, "ab", "steps in order")
			Assert.equal(migrated.version, 3, "version bumped")

			local missing, failure = PlayerData.runMigrations({ version = 1 }, migrations, 4)
			Assert.equal(missing, nil, "no data when a step is missing")
			assert(failure, "failure")
			Assert.equal(failure.reason, "Unreadable", "missing step reason")
		end,
	},
	{
		name = "player data: repair fixes bad numbers",
		run = function()
			local data = withItems()
			data.coins = 0 / 0
			data.depthLimit = math.huge
			data.eggTickets = -3
			data.pressureLevel = 2.7
			data.pets["3"].stars = Economy.PET_MAX_STARS + 5
			local fixes = PlayerData.repair(data)
			Assert.equal(data.coins, 0, "NaN coins")
			Assert.equal(data.depthLimit, 0, "infinite depth")
			Assert.equal(data.eggTickets, 0, "negative tickets")
			Assert.equal(data.pressureLevel, 2, "fractional level")
			Assert.equal(data.pets["3"].stars, Economy.PET_MAX_STARS, "stars clamped")
			Assert.equal(#fixes, 5, "one fix per bad number")
		end,
	},
	{
		name = "player data: repair drops broken references and keeps ids unique",
		run = function()
			local data = withItems()
			local equipped = data.equippedPearls[1]
			data.aquarium.displayedPearls = { equipped, "999", data.aquarium.displayedPearls[1] }
			data.equippedPets = { "3", "3", "404" }
			data.nextItemId = 2
			PlayerData.repair(data)
			Assert.equal(#data.aquarium.displayedPearls, 1, "equipped and missing pearls undisplayed")
			Assert.isTrue(data.aquarium.displayedPearls[1] ~= equipped, "equipped pearl stays equipped")
			Assert.equal(#data.equippedPets, 1, "duplicate and missing pets dropped")
			Assert.equal(data.nextItemId, 4, "next id above owned ids")
			Assert.equal(PlayerData.newItemId(data), "4", "new id")
			Assert.equal(PlayerData.newItemId(data), "5", "ids increase")
		end,
	},
	{
		name = "player data: validate reports unknown content and limits without removing items",
		run = function()
			local data = withItems()
			data.pearls["1"].rarity = "Purple" :: any
			for _ = 1, Economy.SHELL_BAG_MAX do
				table.insert(data.shellBag, { tier = "Common", zoneId = "ShallowBeach" })
			end
			for _ = 1, 8 do
				table.insert(data.aquarium.shells, { tier = "Common", zoneId = "ShallowBeach", readyAt = NOW })
			end
			data.equippedPets = { "3", "3", "3", "3", "3", "3" }
			local problems = PlayerData.validate(data)
			Assert.equal(#problems, 4, `problems: {table.concat(problems, "; ")}`)
			Assert.equal(data.pearls["1"].rarity, "Purple", "unknown pearl kept")
			Assert.equal(#data.shellBag, Economy.SHELL_BAG_MAX + 1, "bag not trimmed")
		end,
	},
}
