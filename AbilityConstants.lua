-- Shared identity and timing for the nine class abilities.

local Constants = {}

export type AbilityDefinition = {
	name: string,
	description: string,
	cooldown: number,
	duration: number,
	color: Color3,
}

Constants.ABILITIES = {
	Pathfinder = {
		name = "OVERDRIVE",
		description = "Mehr Jet-, Lauf- und Luftkontrolle",
		cooldown = 16,
		duration = 5,
		color = Color3.fromRGB(80, 220, 255),
	},
	Sentinel = {
		name = "FOCUS MODE",
		description = "Erhöhter Präzisionsschaden",
		cooldown = 18,
		duration = 5,
		color = Color3.fromRGB(120, 235, 255),
	},
	Infiltrator = {
		name = "CLOAK",
		description = "Temporäre optische Tarnung",
		cooldown = 20,
		duration = 6,
		color = Color3.fromRGB(185, 105, 255),
	},
	Soldier = {
		name = "COMBAT REPAIR",
		description = "Stellt sofort Gesundheit wieder her",
		cooldown = 16,
		duration = 0,
		color = Color3.fromRGB(255, 190, 85),
	},
	Technician = {
		name = "TEAM REPAIR PULSE",
		description = "Heilt verbündete Spieler im Umkreis",
		cooldown = 18,
		duration = 0,
		color = Color3.fromRGB(95, 255, 160),
	},
	Raider = {
		name = "EMP PULSE",
		description = "Blockiert kurz gegnerische Waffen und Fähigkeiten",
		cooldown = 22,
		duration = 4,
		color = Color3.fromRGB(80, 180, 255),
	},
	Juggernaut = {
		name = "FORTIFY",
		description = "Reduziert eingehenden Schaden",
		cooldown = 22,
		duration = 6,
		color = Color3.fromRGB(255, 145, 70),
	},
	Brute = {
		name = "SHOCKWAVE",
		description = "Schaden und Rückstoß im Nahbereich",
		cooldown = 18,
		duration = 0,
		color = Color3.fromRGB(255, 90, 80),
	},
	Doombringer = {
		name = "FORCE FIELD",
		description = "Kurze vollständige Schutzbarriere",
		cooldown = 24,
		duration = 3.5,
		color = Color3.fromRGB(255, 225, 80),
	},
} :: { [string]: AbilityDefinition }

function Constants.Get(loadoutId: any): AbilityDefinition
	if typeof(loadoutId) == "string" and Constants.ABILITIES[loadoutId] then
		return Constants.ABILITIES[loadoutId]
	end
	return Constants.ABILITIES.Pathfinder
end

return Constants
