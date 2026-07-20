-- LoadoutConstants.lua
-- Neun Klassen aus dem klassischen Light-/Medium-/Heavy-Raster.

local Constants = {}

export type LoadoutId = "Pathfinder"
	| "Sentinel"
	| "Infiltrator"
	| "Soldier"
	| "Technician"
	| "Raider"
	| "Juggernaut"
	| "Brute"
	| "Doombringer"
export type LoadoutDefinition = {
	displayName: string,
	armor: string,
	maxHealth: number,
	maxEnergy: number,
	maxGrenades: number,
	walkSpeedScale: number,
	jetThrustScale: number,
	airControlScale: number,
	skiControlScale: number,
	impulseScale: number,
	description: string,
}

Constants.DEFAULT_LOADOUT = "Pathfinder" :: LoadoutId
Constants.ORDER = {
	"Pathfinder",
	"Sentinel",
	"Infiltrator",
	"Soldier",
	"Technician",
	"Raider",
	"Juggernaut",
	"Brute",
	"Doombringer",
}
Constants.CHANGE_COOLDOWN = 3

Constants.LOADOUTS = {
	Pathfinder = {
		displayName = "PATHFINDER",
		armor = "LIGHT",
		maxHealth = 100,
		maxEnergy = 100,
		maxGrenades = 2,
		walkSpeedScale = 1,
		jetThrustScale = 1,
		airControlScale = 1,
		skiControlScale = 1,
		impulseScale = 1,
		description = "Schneller Flaggenträger mit maximaler Jetpack-Energie.",
	},
	Sentinel = {
		displayName = "SENTINEL",
		armor = "LIGHT",
		maxHealth = 100,
		maxEnergy = 95,
		maxGrenades = 2,
		walkSpeedScale = 0.98,
		jetThrustScale = 0.98,
		airControlScale = 0.96,
		skiControlScale = 0.98,
		impulseScale = 0.96,
		description = "Leichter Distanzkämpfer und Scharfschütze.",
	},
	Infiltrator = {
		displayName = "INFILTRATOR",
		armor = "LIGHT",
		maxHealth = 105,
		maxEnergy = 90,
		maxGrenades = 2,
		walkSpeedScale = 0.99,
		jetThrustScale = 0.96,
		airControlScale = 1,
		skiControlScale = 1,
		impulseScale = 0.94,
		description = "Mobiler Angreifer mit Stealth-Waffen und Haftgranate.",
	},
	Soldier = {
		displayName = "SOLDIER",
		armor = "MEDIUM",
		maxHealth = 130,
		maxEnergy = 90,
		maxGrenades = 2,
		walkSpeedScale = 0.93,
		jetThrustScale = 0.94,
		airControlScale = 0.9,
		skiControlScale = 0.92,
		impulseScale = 0.82,
		description = "Ausgewogener Frontkämpfer mit mehr Panzerung.",
	},
	Technician = {
		displayName = "TECHNICIAN",
		armor = "MEDIUM",
		maxHealth = 125,
		maxEnergy = 100,
		maxGrenades = 2,
		walkSpeedScale = 0.92,
		jetThrustScale = 0.96,
		airControlScale = 0.91,
		skiControlScale = 0.92,
		impulseScale = 0.8,
		description = "Defensive Support-Klasse für Generator und Basis.",
	},
	Raider = {
		displayName = "RAIDER",
		armor = "MEDIUM",
		maxHealth = 135,
		maxEnergy = 88,
		maxGrenades = 2,
		walkSpeedScale = 0.94,
		jetThrustScale = 0.92,
		airControlScale = 0.92,
		skiControlScale = 0.94,
		impulseScale = 0.8,
		description = "Aggressiver Basenstürmer mit Explosiv- und EMP-Waffen.",
	},
	Juggernaut = {
		displayName = "JUGGERNAUT",
		armor = "HEAVY",
		maxHealth = 170,
		maxEnergy = 80,
		maxGrenades = 3,
		walkSpeedScale = 0.84,
		jetThrustScale = 0.86,
		airControlScale = 0.74,
		skiControlScale = 0.8,
		impulseScale = 0.62,
		description = "Schwere Angriffsrolle mit maximaler Gesundheit.",
	},
	Brute = {
		displayName = "BRUTE",
		armor = "HEAVY",
		maxHealth = 165,
		maxEnergy = 85,
		maxGrenades = 3,
		walkSpeedScale = 0.86,
		jetThrustScale = 0.88,
		airControlScale = 0.76,
		skiControlScale = 0.82,
		impulseScale = 0.64,
		description = "Schwerer Nahbereichs-Brecher mit hoher Explosivkraft.",
	},
	Doombringer = {
		displayName = "DOOMBRINGER",
		armor = "HEAVY",
		maxHealth = 180,
		maxEnergy = 75,
		maxGrenades = 3,
		walkSpeedScale = 0.82,
		jetThrustScale = 0.83,
		airControlScale = 0.7,
		skiControlScale = 0.77,
		impulseScale = 0.58,
		description = "Schwerster Verteidiger gegen Fahrzeuge und Flag-Routen.",
	},
} :: { [LoadoutId]: LoadoutDefinition }

return Constants
