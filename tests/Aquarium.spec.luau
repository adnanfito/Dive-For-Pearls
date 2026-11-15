--!strict
local Aquarium = require("../src/shared/Aquarium")
local Assert = require("./Assert")
local Economy = require("../src/shared/Config/Economy")
local Formulas = require("../src/shared/Formulas")
local Onboarding = require("../src/shared/Config/Onboarding")
local PlayerData = require("../src/shared/PlayerData")

local NOW = 1_000_000

local function freshData(): any
	return PlayerData.default(NOW)
end

local function fillBag(data: any, count: number, tier: string)
	for _ = 1, count do
		table.insert(data.shellBag, { tier = tier, zoneId = "ShallowBeach" })
	end
end

-- A pearl owned by data, created the same way opening a shell does.
local function givePearl(data: any, rarity: string, zoneId: string?): string
	local id = PlayerData.newItemId(data)
	data.pearls[id] = { rarity = rarity, zoneId = zoneId or "ShallowBeach" }
	return id
end

return {
	{
		name = "aquarium: placing fills free slots, first shells ripen at once, the rest stay in the bag",
		run = function()
			local data = freshData()
			local slots = Formulas.aquariumSlots(0)
			fillBag(data, slots + 3, "Glowing")
			Assert.equal(Aquarium.placeFromBag(data, NOW), slots, "fills every slot")
			Assert.equal(#data.shellBag, 3, "the rest waits in the bag")
			Assert.equal(Aquarium.freeSlots(data), 0, "no slot left")
			for index, shell in data.aquarium.shells do
				local instant = index <= Economy.ONBOARDING_INSTANT_SHELLS
				local expected = if instant then NOW else NOW + Formulas.shellRipenSeconds("Glowing")
				Assert.equal(shell.readyAt, expected, `shell {index} ready time`)
			end
			Assert.equal(data.onboarding.instantShellsLeft, 0, "onboarding shells used up")
		end,
	},
	{
		name = "aquarium: opening needs a ripe shell, the first pearl is Pink, later ones are rolled",
		run = function()
			local data = freshData()
			data.onboarding.instantShellsLeft = 0
			fillBag(data, 2, "Common")
			Aquarium.placeFromBag(data, NOW)
			local id, failure = Aquarium.openShell(data, 1, NOW, 0.5)
			Assert.equal(id, nil, "unripe shell stays closed")
			Assert.equal(failure, "NotRipe", "unripe reason")
			local later = NOW + Formulas.shellRipenSeconds("Common")
			local first = Aquarium.openShell(data, 1, later, 0.99) :: string
			Assert.equal(data.pearls[first].rarity, Onboarding.firstPearlRarity, "first pearl is the onboarding pick")
			local second = Aquarium.openShell(data, 1, later, 0) :: string
			Assert.equal(data.pearls[second].rarity, "White", "u = 0 rolls the most common rarity")
			Assert.equal(#data.aquarium.shells, 0, "opened shells leave their slots")
			local _, missing = Aquarium.openShell(data, 1, later, 0)
			Assert.equal(missing, "Missing", "no shell at that slot")
		end,
	},
	{
		name = "aquarium: equip replaces the oldest, display needs a free slot, sell pays and removes",
		run = function()
			local data = freshData()
			local a = givePearl(data, "White")
			local b = givePearl(data, "Gold")
			Aquarium.usePearl(data, a, "Equip")
			Aquarium.usePearl(data, b, "Equip")
			Assert.equal(Aquarium.pearlPlace(data, a), "Stored", "full equip slot sends the old pearl back")
			Assert.equal(Aquarium.pearlPlace(data, b), "Equipped", "new pearl equipped")
			Assert.equal(Aquarium.usePearl(data, a, "Display"), nil, "display with room")
			Assert.near(Formulas.aquariumCoinsPerSecond(data), 1, 1e-9, "White pearl earns 1 per second")
			data.aquarium.upgrades = 0
			fillBag(data, Formulas.aquariumSlots(0), "Common")
			Aquarium.placeFromBag(data, NOW)
			Assert.equal(Aquarium.usePearl(data, b, "Display"), "NoRoom", "no slot for a second pearl")
			Assert.equal(Aquarium.pearlPlace(data, b), "Equipped", "failed display leaves it equipped")
			local failure, coins = Aquarium.usePearl(data, a, "Sell")
			Assert.equal(failure, nil, "sell works")
			Assert.equal(coins, Formulas.pearlSellPrice("White", 0), "sell price paid")
			Assert.equal(data.coins, coins, "Coins added")
			Assert.equal(data.pearls[a], nil, "sold pearl is gone")
			Assert.equal(#data.aquarium.displayedPearls, 0, "sold pearl left the display")
		end,
	},
	{
		name = "aquarium: reef pearls are worth more, state lists every pearl",
		run = function()
			local data = freshData()
			givePearl(data, "Blue", "CoralReef")
			local state = Aquarium.state(data, NOW, true)
			Assert.equal(#state.pearls, 1, "one pearl listed")
			Assert.equal(state.pearls[1].coinsPerSecond, 10 * Economy.PEARL_ZONE_VALUE_GROWTH, "reef scales by 4")
			Assert.equal(state.pearls[1].place, "Stored", "new pearl starts stored")
		end,
	},
}
