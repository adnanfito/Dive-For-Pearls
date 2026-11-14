--!strict

export type Zone = {
	id: string,
	displayName: string,
	startDepth: number,
	released: boolean,
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

export type WeightedEntry<T> = {
	value: T,
	weight: number,
}

return {}
