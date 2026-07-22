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

local primaryChanged = Instance.new("BindableEvent")
WeaponState.PrimaryChanged = primaryChanged.Event

local selected: Weapon = "Spinfusor"
local primaryDown = false

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

function WeaponState.SetPrimaryDown(down: boolean)
	if primaryDown == down then
		return
	end
	primaryDown = down
	primaryChanged:Fire(down)
end

function WeaponState.IsPrimaryDown(): boolean
	return primaryDown
end

return WeaponState
