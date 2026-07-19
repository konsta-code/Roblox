-- MovementConstants.lua
-- Ablageort: ReplicatedStorage/Modules/MovementConstants
-- Movement v2 - näher am originalen Tribes Ascend Feeling

local Constants = {}

-- Grundbewegung
Constants.WALK_SPEED = 16
Constants.MAX_SKI_SPEED = 220          -- höherer Soft-Cap
Constants.GRAVITY = 100                -- stärkere Gravitation für schnelleres "Fallen = Speed"
Constants.JUMP_POWER = 48              -- etwas schwächerer Jump (Original war nicht stark)

-- Skiing
Constants.SKI_GROUND_FRICTION = 0.004  -- extrem niedrig → Momentum bleibt sehr lange
Constants.WALK_GROUND_FRICTION = 12.0
Constants.SKI_MIN_SLOPE_ANGLE = 2.5    -- früher skien können
Constants.SKI_SLOPE_FORCE_MULT = 1.65  -- deutlich stärkere Hangabtriebskraft

-- Jetpack
Constants.JETPACK_MAX_ENERGY = 100
Constants.JETPACK_DRAIN_RATE = 36
Constants.JETPACK_REGEN_RATE = 24
Constants.JETPACK_REGEN_DELAY = 0.35
Constants.JETPACK_THRUST_FORCE = 175
Constants.JETPACK_FORWARD_MULT = 0.72  -- mehr Forward-Thrust (wichtig!)

-- Ground Detection + Landing
Constants.GROUND_CHECK_DISTANCE = 4.0
Constants.LANDING_VELOCITY_TRANSFER = 0.92  -- fast volle Übernahme der Fallgeschwindigkeit

return Constants
