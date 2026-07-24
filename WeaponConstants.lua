-- WeaponConstants.lua
-- Spinfusor defaults adapted from TrProj_Spinfusor.uc. Unreal values are
-- converted with the same 20 UU = 1 Roblox stud scale as player movement.

local Constants = {}

Constants.BUILD_ID = "tribes-core-4"
Constants.UU_PER_STUD = 20

Constants.PROJECTILE_SPEED = 3920 / Constants.UU_PER_STUD
Constants.PROJECTILE_MAX_SPEED = 8000 / Constants.UU_PER_STUD
Constants.PROJECTILE_LIFETIME = 6
Constants.PROJECTILE_RADIUS = 10 / Constants.UU_PER_STUD
Constants.PROJECTILE_INHERITANCE = 0.5

-- Original damage 650, DirectHitMultiplier 1.4. Health is scaled to the
-- Roblox default of 100 while retaining the original proportions.
Constants.SPLASH_MAX_DAMAGE = 70
Constants.SPLASH_MIN_DAMAGE = 35
Constants.SPLASH_RADIUS = 360 / Constants.UU_PER_STUD
Constants.SPLASH_FULL_DAMAGE_PCT = 0.5
Constants.SPLASH_MIN_DAMAGE_PCT = 0.9
Constants.DIRECT_HIT_DAMAGE = Constants.SPLASH_MAX_DAMAGE * 1.4

-- The T:A default reload time is 1.5 seconds.
Constants.FIRE_COOLDOWN = 1.5

-- MomentumTransfer 85000, InstigatorMultiplier 1.2, ExtraZMomentum 90000.
-- The conversion assumes a 100-unit Roblox character assembly mass.
-- SELF_KNOCKBACK_MULT: die rohen T:A-Werte fühlten sich in Roblox zu stark an
-- (Boden-Boost zu heftig) -> Disc-Jump-Stärke hier zentral herunterskalieren.
-- 1.0 = roher T:A-Wert. Höher = mehr Boost, niedriger = weniger.
Constants.SELF_KNOCKBACK_MULT = 0.3
Constants.SELF_KNOCKBACK_SPEED = (85000 * 1.2) / 100 / Constants.UU_PER_STUD * Constants.SELF_KNOCKBACK_MULT
Constants.SELF_KNOCKBACK_UP_SPEED = 90000 / 100 / Constants.UU_PER_STUD * Constants.SELF_KNOCKBACK_MULT
Constants.MAX_EXTERNAL_IMPULSE = 140

-- Gegner-Knockback -- der Tribes-Spass: Feinde wegpunten (Juggling, Luftkaempfe,
-- Leute von Basen/Klippen schiessen). Nutzt denselben rohen T:A-Momentum wie
-- self, aber eigene Multiplikatoren. Der Client skaliert eingehende Impulse
-- zusaetzlich (ImpulseScale ~0.4) und cappt auf MAX_EXTERNAL_IMPULSE. Zum
-- Justieren des Gefuehls NUR die beiden MULT-Werte drehen (hoeher = mehr Punt).
Constants.ENEMY_KNOCKBACK_MULT = 1.15 -- Splash: skaliert zusaetzlich mit Naehe/Schaden
Constants.ENEMY_KNOCKBACK_SPEED = (85000 * 1.2) / 100 / Constants.UU_PER_STUD * Constants.ENEMY_KNOCKBACK_MULT
Constants.ENEMY_KNOCKBACK_UP_SPEED = 90000 / 100 / Constants.UU_PER_STUD * Constants.ENEMY_KNOCKBACK_MULT
Constants.DIRECT_KNOCKBACK_MULT = 1.75 -- Direkt-Treffer punten voll entlang der Disc-Flugrichtung
Constants.DIRECT_KNOCKBACK_SPEED = (85000 * 1.2) / 100 / Constants.UU_PER_STUD * Constants.DIRECT_KNOCKBACK_MULT
Constants.DIRECT_KNOCKBACK_UP_SPEED = 90000 / 100 / Constants.UU_PER_STUD * Constants.DIRECT_KNOCKBACK_MULT * 0.55

-- Saubere Mid-Air-Direkttreffer (Gegner schnell UND in der Luft) belohnen: der
-- ikonische Tribes-Skillshot wird lethal. 1.35 * 98 (Soldier) = 132 -> One-Shot
-- bei 100 HP. Bodennahe/langsame Direkttreffer bleiben unveraendert.
Constants.MIDAIR_DIRECT_MULT = 1.35

return Constants
