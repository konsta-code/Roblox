-- MovementConstants.lua
-- Ablageort: ReplicatedStorage/Modules/MovementConstants
-- Optimiert auf Tribes Ascend Feeling (Juli 2026)

local Constants = {}

-- Grundbewegung
Constants.WALK_SPEED = 16
Constants.MAX_SKI_SPEED = 180          -- höherer Soft-Cap (Original hat kaum harten Cap)
Constants.GRAVITY = 95                 -- etwas stärker für schnelleres "Fallen = Speed"
Constants.JUMP_POWER = 55

-- Skiing (Kern des Original-Feelings)
Constants.SKI_GROUND_FRICTION = 0.008  -- fast null → Momentum bleibt extrem lange
Constants.WALK_GROUND_FRICTION = 10.0
Constants.SKI_MIN_SLOPE_ANGLE = 3      -- früher skien können
Constants.SKI_SLOPE_FORCE_MULT = 1.35  -- stärkere Hangabtriebskraft

-- Jetpack
Constants.JETPACK_MAX_ENERGY = 100
Constants.JETPACK_DRAIN_RATE = 38
Constants.JETPACK_REGEN_RATE = 22
Constants.JETPACK_REGEN_DELAY = 0.4
Constants.JETPACK_THRUST_FORCE = 165   -- muss > Gravity sein
Constants.JETPACK_FORWARD_MULT = 0.55  -- wichtiger: Forward-Thrust beim Jetten

-- Ground Detection
Constants.GROUND_CHECK_DISTANCE = 3.8
Constants.LANDING_VELOCITY_TRANSFER = 0.85  -- wie viel Fallgeschwindigkeit in Ski übergeht

return Constants
