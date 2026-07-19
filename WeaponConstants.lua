-- WeaponConstants.lua
-- Ablageort: ReplicatedStorage/Modules/WeaponConstants
-- Optimiert für stärkeres Disc-Jump Feeling (Tribes Ascend Style)

local Constants = {}

Constants.PROJECTILE_SPEED = 195       -- studs/s
Constants.PROJECTILE_LIFETIME = 3
Constants.PROJECTILE_RADIUS = 0.8

Constants.SPLASH_RADIUS = 13
Constants.DIRECT_HIT_DAMAGE = 85
Constants.SPLASH_MAX_DAMAGE = 70
Constants.SPLASH_MIN_DAMAGE = 8

Constants.FIRE_COOLDOWN = 0.78

Constants.SELF_KNOCKBACK_ENABLED = true
Constants.SELF_KNOCKBACK_FORCE = 85        -- stärkerer Disc-Jump
Constants.SELF_KNOCKBACK_MAX_DISTANCE = 18

return Constants
