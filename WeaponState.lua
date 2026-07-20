-- WeaponState.lua
-- Ablageort: ReplicatedStorage/Modules/WeaponState
--
-- Client-seitiger gemeinsamer Zustand: welche Waffe ist gerade gewählt.
-- WeaponSelector schreibt, die Waffen-Clients (ProjectileWeapon, Chaingun)
-- lesen/abonnieren. Gleiches Muster wie PlayerHudState - zwei LocalScripts
-- können sich sonst nicht direkt sehen.

local WeaponState = {}

export type Weapon = "Spinfusor" | "Chaingun"

local changed = Instance.new("BindableEvent")
WeaponState.Changed = changed.Event

local selected: Weapon = "Spinfusor"

function WeaponState.Set(weapon: Weapon)
	if weapon ~= "Spinfusor" and weapon ~= "Chaingun" then
		return
	end
	if weapon == selected then
		return
	end
	selected = weapon
	changed:Fire(selected)
end

function WeaponState.Get(): Weapon
	return selected
end

return WeaponState
