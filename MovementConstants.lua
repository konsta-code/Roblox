-- MovementConstants.lua
-- Movement v4 - kritische Fixes

local Constants = {}

Constants.WALK_SPEED = 16
Constants.MAX_SKI_SPEED = 240
Constants.GRAVITY = 105
Constants.JUMP_POWER = 0

Constants.SKI_GROUND_FRICTION = 0.003
Constants.WALK_GROUND_FRICTION = 14.0
Constants.SKI_MIN_SLOPE_ANGLE = 0
Constants.SKI_SLOPE_FORCE_MULT = 1.8

Constants.JETPACK_MAX_ENERGY = 100
Constants.JETPACK_DRAIN_RATE = 35
Constants.JETPACK_REGEN_RATE = 23
Constants.JETPACK_REGEN_DELAY = 0.3
Constants.JETPACK_THRUST_FORCE = 160
Constants.JETPACK_FORWARD_MULT = 0.65

Constants.JET_SOFT_CAP_SPEED = 85
Constants.JET_OVER_CAP_MULT = 0.18

Constants.GROUND_CHECK_DISTANCE = 4.2
Constants.LANDING_VELOCITY_TRANSFER = 0.95
Constants.EXTERNAL_IMPULSE_BLEND = 0.85

return Constants
