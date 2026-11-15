--!strict
-- Aquarium rules on saved data: placing shells from the bag, opening ripe shells into pearls and
-- the four things a player can do with a pearl. No Roblox APIs, so Lune can test it. Only
-- AquariumService calls these, after it has validated the request. Times are unix seconds.
local Economy = require("./Config/Economy")
local Onboarding = require("./Config/Onboarding")
local Formulas = require("./Formulas")
local Pearls = require("./Config/Pearls")
local PlayerData = require("./PlayerData")
local Types = require("./Types")

type PlayerData = Types.PlayerData
type Failure = Types.AquariumFailure

local Aquarium = {}

local KNOWN_RARITIES: { [string]: boolean } = {}
for _, row in Pearls do
	KNOWN_RARITIES[row.id] = true
end

-- Ripening shells and displayed pearls share the same slots.
function Aquarium.freeSlots(data: PlayerData): number
	return Formulas.aquariumSlots(data.aquarium.upgrades) - #data.aquarium.shells - #data.aquarium.displayedPearls
end

-- Moves shells from the bag into free slots, oldest first. A new player's first shells ripen at once.
function Aquarium.placeFromBag(data: PlayerData, now: number): number
	local placed = 0
	while #data.shellBag > 0 and Aquarium.freeSlots(data) > 0 do
		local shell = table.remove(data.shellBag, 1) :: Types.BagShell
		local instant = data.onboarding.instantShellsLeft > 0
		if instant then
			data.onboarding.instantShellsLeft -= 1
		end
		local readyAt = if instant then now else now + Formulas.shellRipenSeconds(shell.tier)
		table.insert(data.aquarium.shells, { tier = shell.tier, zoneId = shell.zoneId, readyAt = readyAt })
		placed += 1
	end
	return placed
end

local function countKeys(map: { [string]: any }): number
	local count = 0
	for _ in map do
		count += 1
	end
	return count
end

-- u is a uniform number in [0, 1) from the server's Random. Returns the new pearl's id.
function Aquarium.openShell(data: PlayerData, index: number, now: number, u: number): (string?, Failure?)
	local shell = data.aquarium.shells[index]
	if not shell then
		return nil, "Missing"
	end
	if shell.readyAt > now then
		return nil, "NotRipe"
	end
	if countKeys(data.pearls) >= Economy.PEARL_INVENTORY_MAX then
		return nil, "PearlsFull"
	end
	-- nextItemId 1 means nothing was ever created, so this is the player's first opening.
	local rarity: Types.PearlRarityId = if data.nextItemId == 1
		then Onboarding.firstPearlRarity
		else Formulas.rollPearl(Formulas.shellPearlLuck(shell.tier), u)
	table.remove(data.aquarium.shells, index)
	local id = PlayerData.newItemId(data)
	data.pearls[id] = { rarity = rarity, zoneId = shell.zoneId }
	return id, nil
end

function Aquarium.pearlPlace(data: PlayerData, id: string): Types.PearlPlace
	if table.find(data.equippedPearls, id) then
		return "Equipped"
	end
	if table.find(data.aquarium.displayedPearls, id) then
		return "Displayed"
	end
	return "Stored"
end

local function unplace(data: PlayerData, id: string)
	local equipped = table.find(data.equippedPearls, id)
	if equipped then
		table.remove(data.equippedPearls, equipped)
	end
	local displayed = table.find(data.aquarium.displayedPearls, id)
	if displayed then
		table.remove(data.aquarium.displayedPearls, displayed)
	end
end

-- Equipping into a full slot sends the oldest equipped pearl back to storage.
local function equip(data: PlayerData, id: string)
	unplace(data, id)
	if #data.equippedPearls >= Economy.PEARL_EQUIP_SLOTS_START then
		table.remove(data.equippedPearls, 1)
	end
	table.insert(data.equippedPearls, id)
end

-- Returns a failure, or nil and the Coins the action earned.
function Aquarium.usePearl(data: PlayerData, id: string, use: Types.PearlUse): (Failure?, number)
	local pearl = data.pearls[id]
	if not pearl then
		return "Missing", 0
	end
	local place = Aquarium.pearlPlace(data, id)
	if use == "Equip" then
		equip(data, id)
	elseif use == "Display" then
		if place ~= "Displayed" then
			if Aquarium.freeSlots(data) <= 0 then
				return "NoRoom", 0
			end
			unplace(data, id)
			table.insert(data.aquarium.displayedPearls, id)
		end
	elseif use == "Store" then
		unplace(data, id)
	else
		unplace(data, id)
		data.pearls[id] = nil
		local price = Formulas.pearlSellPrice(pearl.rarity, Formulas.zoneIndex(pearl.zoneId))
		data.coins += price
		return nil, price
	end
	return nil, 0
end

function Aquarium.pearlView(data: PlayerData, id: string): Types.PearlView
	local pearl = data.pearls[id]
	local zoneIndex = Formulas.zoneIndex(pearl.zoneId)
	return {
		id = id,
		rarity = pearl.rarity,
		zoneId = pearl.zoneId,
		place = Aquarium.pearlPlace(data, id),
		coinsPerSecond = Formulas.pearlCoinsPerSecond(pearl.rarity, zoneIndex),
		sellPrice = Formulas.pearlSellPrice(pearl.rarity, zoneIndex),
		bonus = Formulas.pearlEquipBonus(pearl.rarity),
	}
end

function Aquarium.state(data: PlayerData, now: number, hasPlot: boolean): Types.AquariumState
	local shells = {}
	for _, shell in data.aquarium.shells do
		table.insert(shells, { tier = shell.tier, readyIn = math.max(shell.readyAt - now, 0) })
	end
	local pearls = {}
	for id, pearl in data.pearls do
		-- Pearls whose content left Config are skipped; DataService warned about them on load.
		if KNOWN_RARITIES[pearl.rarity] and Formulas.findZone(pearl.zoneId) then
			table.insert(pearls, Aquarium.pearlView(data, id))
		end
	end
	return {
		hasPlot = hasPlot,
		slots = Formulas.aquariumSlots(data.aquarium.upgrades),
		shells = shells,
		pearls = pearls,
		bagCount = #data.shellBag,
		coinsPerSecond = Formulas.aquariumCoinsPerSecond(data),
		equipSlots = Economy.PEARL_EQUIP_SLOTS_START,
	}
end

return Aquarium
