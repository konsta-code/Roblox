-- MovementConstants.lua
-- Movement v3 - näher an originalem Tribes Ascend Verhalten
-- Basiert auf Community-Datamines + Hi-Rez Physics-Parametern (2012/13)

local Constants = {}

-- Grundbewegung
Constants.WALK_SPEED = 16
Constants.MAX_SKI_SPEED = 240          -- Soft-Cap für Skiing (Original hatte kaum harten Cap)
Constants.GRAVITY = 105               -- etwas stärker für besseres "Fallen = Speed"
Constants.JUMP_POWER = 45             -- schwacher Jump (Original war nie stark)

-- Skiing
Constants.SKI_GROUND_FRICTION = 0.003 -- extrem niedrig
Constants.WALK_GROUND_FRICTION = 14.0
Constants.SKI_MIN_SLOPE_ANGLE = 2.0
Constants.SKI_SLOPE_FORCE_MULT = 1.8   -- starke Hangabtriebskraft

-- Jetpack (wichtiger Teil der Authentizität)
Constants.JETPACK_MAX_ENERGY = 100
Constants.JETPACK_DRAIN_RATE = 35
Constants.JETPACK_REGEN_RATE = 23
Constants.JETPACK_REGEN_DELAY = 0.3
Constants.JETPACK_THRUST_FORCE = 160
Constants.JETPACK_FORWARD_MULT = 0.65

-- Soft-Cap für reines Jetten (Original ~72-74 km/h)
-- Ab dieser horizontalen Geschwindigkeit wird der Thrust stark abgeschwächt
Constants.JET_SOFT_CAP_SPEED = 85     -- studs/s (~ ca. 72-80 km/h Bereich)
Constants.JET_OVER_CAP_MULT = 0.18    -- wie stark der Thrust über dem Cap abfällt

-- Landing / Velocity Transfer
Constants.GROUND_CHECK_DISTANCE = 4.2
Constants.LANDING_VELOCITY_TRANSFER = 0.95  -- fast volle Übernahme der Fallgeschwindigkeit

return Constants
