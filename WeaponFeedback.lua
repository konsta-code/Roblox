-- WeaponFeedback.lua
-- Rein lokales Signal für First-Person-Rückstoß und Mündungsblitz.

local WeaponFeedback = {}

export type Weapon = "Spinfusor" | "Chaingun" | "Grenade" | "Melee"

local fired = Instance.new("BindableEvent")
WeaponFeedback.Fired = fired.Event

type Cooldown = {
	startedAt: number,
	duration: number,
}

local cooldownStarted = Instance.new("BindableEvent")
WeaponFeedback.CooldownStarted = cooldownStarted.Event
local cooldowns: { [string]: Cooldown } = {}

function WeaponFeedback.Fire(weapon: Weapon)
	fired:Fire(weapon)
end

function WeaponFeedback.StartCooldown(weapon: Weapon, duration: number)
	local cooldown = {
		startedAt = os.clock(),
		duration = math.max(0.01, duration),
	}
	cooldowns[weapon] = cooldown
	cooldownStarted:Fire(weapon, cooldown.startedAt, cooldown.duration)
end

function WeaponFeedback.GetCooldown(weapon: Weapon): (number, number)
	local cooldown = cooldowns[weapon]
	if not cooldown then
		return 0, 0
	end
	return cooldown.startedAt, cooldown.duration
end

return WeaponFeedback
