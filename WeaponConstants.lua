-- WeaponConstants.lua
-- Ablageort: ReplicatedStorage/Modules/WeaponConstants
-- v2 - kalibriert anhand der echten Tribes Ascend Projectile-Datamine
-- Quelle: T_A Projectiles.xlsx (UE Explorer Extraktion)

local Constants = {}

--[[
  Umrechnungshinweise aus der Original-Datamine:
  - 50 UU = 1 Meter
  - Speed UU/s * 0.072 = km/h
  - Spinfusor Speed 3920 UU/s ≈ 282 km/h
  - MomentumTransfer 85000 ist der Kernwert für Disc-Jumps
]]

-- === Spinfusor (Standard / Light als Basis) ===
Constants.PROJECTILE_SPEED = 210          -- etwas höher als vorher, näher am Feeling
Constants.PROJECTILE_LIFETIME = 5.5       -- Original LifeSpan = 6
Constants.PROJECTILE_RADIUS = 0.9

-- Schaden (Original Light Spinfusor 550, Standard 650, DirectHitMult 1.4)
Constants.DIRECT_HIT_DAMAGE = 95          -- entspricht ca. 550*1.4 skaliert
Constants.SPLASH_MAX_DAMAGE = 70
Constants.SPLASH_MIN_DAMAGE = 10
Constants.SPLASH_RADIUS = 14              -- Original DamageRadius 360 UU ≈ skaliert

Constants.FIRE_COOLDOWN = 0.75

-- Inheritance (Original m_fProjInheritVelocityPct = 0.5 bei den meisten Discs)
Constants.PROJECTILE_INHERITANCE = 0.5

-- === Disc-Jump / Self-Knockback ===
-- Original: MomentumTransfer 85000 + InstigatorMultiplier 1.2 + ExtraZ 90000
Constants.SELF_KNOCKBACK_ENABLED = true
Constants.SELF_KNOCKBACK_FORCE = 110       -- deutlich stärker (vorher 85)
Constants.SELF_KNOCKBACK_UP_FORCE = 45     -- Extra Z-Komponente (Original ExtraZMomentum)
Constants.SELF_KNOCKBACK_MAX_DISTANCE = 20
Constants.SELF_KNOCKBACK_MIN_DISTANCE = 3  -- zu nah = weniger Boost (wie im Original)

-- === Chaingun (Referenzwerte) ===
Constants.CHAINGUN_DAMAGE = 12            -- skaliert von Original 95 pro Hit
Constants.CHAINGUN_FIRE_RATE = 0.08       -- sehr hohes RPM
Constants.CHAINGUN_SPREAD = 0.015

-- === Nitron Referenz (für später) ===
-- Impact Nitron MomentumTransfer = 54000
-- Explosive Nitron MomentumTransfer = 110000
Constants.NITRON_IMPACT_FORCE = 70
Constants.NITRON_EXPLOSIVE_FORCE = 140

return Constants
