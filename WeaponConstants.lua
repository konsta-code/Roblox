-- WeaponConstants.lua
-- Ablageort: ReplicatedStorage/Modules/WeaponConstants
-- Tuning für die Skillshot-Splash-Waffe (intern "Spinfusor-Prinzip" als
-- Referenz - eigenes Branding/Name kommt on top, das hier ist reine Mechanik).

local Constants = {}

Constants.PROJECTILE_SPEED = 180       -- studs/s, Geschossgeschwindigkeit
Constants.PROJECTILE_LIFETIME = 3      -- Sekunden bis Selbstzerstörung ohne Treffer
Constants.PROJECTILE_RADIUS = 0.8      -- Kollisionsradius des Geschosses selbst

Constants.SPLASH_RADIUS = 12           -- Studs, Wirkungsradius der Explosion
Constants.DIRECT_HIT_DAMAGE = 75       -- Schaden bei direktem Treffer
Constants.SPLASH_MAX_DAMAGE = 60       -- Schaden im Epizentrum der Explosion
Constants.SPLASH_MIN_DAMAGE = 5        -- Schaden am Rand des Splash-Radius

Constants.FIRE_COOLDOWN = 0.85         -- Sekunden zwischen Schüssen

Constants.SELF_KNOCKBACK_ENABLED = true
Constants.SELF_KNOCKBACK_FORCE = 55        -- "Disc-Jump"-Skilltech
Constants.SELF_KNOCKBACK_MAX_DISTANCE = 15

return Constants
