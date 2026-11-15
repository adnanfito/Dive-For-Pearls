--!strict

export type Zone = {
	id: string,
	displayName: string,
	startDepth: number,
	released: boolean,
	metersPerStud: number?,
}

export type ZoneProgress = {
	current: Zone,
	nextZone: Zone?, -- nil past the last zone
	fraction: number, -- 0..1 from current.startDepth to nextZone.startDepth
}

export type PearlRarityId = "White" | "Pink" | "Blue" | "Gold" | "Black" | "Rainbow"

export type PearlRarity = {
	id: PearlRarityId,
	displayName: string,
	chance: number,
	coinsPerSecond: number,
	equipBonus: number,
}

export type ShellTierId = "Common" | "Glowing" | "Rare" | "Giant"

export type ShellTier = {
	id: ShellTierId,
	displayName: string,
	chance: number,
	ripenSeconds: number,
	pearlLuck: number,
}

export type PetRarityId = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type PetRarity = {
	id: PetRarityId,
	displayName: string,
	chance: number,
	bonus: number,
}

export type PetSpecies = {
	id: string,
	displayName: string,
	rarity: PetRarityId,
}

export type Egg = {
	id: string,
	displayName: string,
	zoneId: string,
	ticketCost: number,
	pool: { string },
}

-- Hatches since the last result at or above each pity rarity.
export type PityState = {
	sinceEpic: number,
	sinceLegendary: number,
}

-- Saved player data. Times are unix seconds (os.time) so ripening continues while offline.
-- Item maps are keyed by string ids from PlayerData.newItemId; lists hold those ids.
export type AquariumShell = {
	tier: ShellTierId,
	zoneId: string, -- pearl value scales by the zone the shell came from
	readyAt: number,
}

export type BagShell = {
	tier: ShellTierId,
	zoneId: string,
}

export type OwnedPearl = {
	rarity: PearlRarityId,
	zoneId: string,
}

export type OwnedPet = {
	species: string,
	stars: number,
}

export type PlayerData = {
	version: number,
	depthLimit: number,
	coins: number,
	eggTickets: number,
	pressureLevel: number,
	aquarium: {
		upgrades: number,
		shells: { AquariumShell },
		displayedPearls: { string },
	},
	shellBag: { BagShell },
	pearls: { [string]: OwnedPearl },
	equippedPearls: { string },
	pets: { [string]: OwnedPet },
	equippedPets: { string },
	petSlotUpgrades: number,
	pity: PityState,
	nextItemId: number,
	lastOnlineAt: number,
	onboarding: {
		instantShellsLeft: number,
		freeEggClaimed: boolean,
	},
	playtimeRewards: {
		day: number, -- the reward service resets this block when the day changes
		seconds: number,
		claimed: { number }, -- minute marks already claimed today
	},
	groupRewardClaimed: boolean,
	redeemedCodes: { [string]: boolean },
	purchaseIds: { string }, -- recent developer product receipts, so none is granted twice
}

-- Sent by the server to one player through PressureUpdate; the client only renders it.
export type PressureState = {
	inside: boolean,
	depthLimit: number,
	gained: number, -- meters added by the last tick
	level: number,
	upgradeCost: number,
	coins: number,
}

export type PressureUpgradeFailure = "BadRequest" | "NotReady" | "TooFast" | "Stale" | "NotEnoughCoins"

export type PressureUpgradeResult = {
	ok: boolean,
	reason: PressureUpgradeFailure?,
}

-- Sent by the server through DiveUpdate. surfaceY and floorY are world heights: the zone's
-- water surface and the deepest point the diver's Depth Limit allows.
export type DiveState = {
	diving: boolean,
	zoneId: string?,
	surfaceY: number,
	floorY: number,
	oxygenLeft: number,
	carried: number,
	bagCount: number,
}

-- One shell the server spawned for one diver; only that diver sees and collects it.
export type DiveShell = {
	id: number,
	tier: ShellTierId,
	position: Vector3,
}

-- Sent by the server through DiveNotice when a dive ends or a portal turns the diver away
-- (PortalLocked: not deep enough yet; PortalSoon: the next zone is not released).
-- shells: carried shells saved (Safe) or lost (Fainted). needDepth: the next zone's start depth.
export type DiveNoticeKind = "Safe" | "Fainted" | "PortalLocked" | "PortalSoon"

export type DiveNotice = {
	kind: DiveNoticeKind,
	shells: number,
	needDepth: number,
}

export type LiftFailure = "BadRequest" | "NotReady" | "TooFast" | "Locked" | "AlreadyDiving" | "TooFar" | "NoWorld"

export type LiftResult = {
	ok: boolean,
	reason: LiftFailure?,
}

export type CollectFailure = "BadRequest" | "NotDiving" | "TooFast" | "Gone" | "TooFar" | "BagFull"

export type CollectResult = {
	ok: boolean,
	reason: CollectFailure?,
}

-- Where an owned pearl is: equipped (pressure bonus), displayed (Coins per second) or stored.
export type PearlPlace = "Equipped" | "Displayed" | "Stored"
export type PearlUse = "Equip" | "Display" | "Sell" | "Store"

export type PearlView = {
	id: string,
	rarity: PearlRarityId,
	zoneId: string,
	place: PearlPlace,
	coinsPerSecond: number,
	sellPrice: number,
	bonus: number,
}

-- readyIn: seconds left when the server sent it; 0 means ready to open.
export type AquariumShellView = {
	tier: ShellTierId,
	readyIn: number,
}

-- Sent by the server through AquariumUpdate; the client only renders it.
export type AquariumState = {
	hasPlot: boolean,
	slots: number,
	shells: { AquariumShellView },
	pearls: { PearlView },
	bagCount: number,
	coinsPerSecond: number,
	equipSlots: number,
}

export type AquariumFailure =
	"BadRequest"
	| "NotReady"
	| "TooFast"
	| "TooFar"
	| "NotRipe"
	| "NoRoom"
	| "PearlsFull"
	| "Missing"

export type AquariumResult = {
	ok: boolean,
	reason: AquariumFailure?,
	pearl: PearlView?, -- the pearl a shell opened into
}

export type WeightedEntry<T> = {
	value: T,
	weight: number,
}

return {}
