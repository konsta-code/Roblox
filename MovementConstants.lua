-- MovementConstants.lua
-- Ablageort: ReplicatedStorage/Modules/MovementConstants
-- Movement v2 - näher am originalen Tribes Ascend Feeling

local Constants = {}

-- Grundbewegung
Constants.WALK_SPEED = 16
Constants.MAX_SKI_SPEED = 220          -- Sicherheitsgrenze gegen instabile Extremgeschwindigkeiten
Constants.GRAVITY = 100                -- stärkere Gravitation für schnelleres "Fallen = Speed"
Constants.JUMP_POWER = 48              -- etwas schwächerer Jump (Original war nicht stark)

-- Skiing
Constants.SKI_GROUND_FRICTION = 0.004  -- extrem niedrig → Momentum bleibt sehr lange
Constants.WALK_GROUND_FRICTION = 12.0
Constants.SKI_MIN_SLOPE_ANGLE = 2.5    -- früher skien können
Constants.SKI_SLOPE_FORCE_MULT = 1.65  -- deutlich stärkere Hangabtriebskraft
Constants.SKI_PEAK_CONTROL_SPEED = 90  -- beste Steuerbarkeit bei mittlerer/hoher Geschwindigkeit
Constants.SKI_CONTROL_WIDTH = 70
Constants.SKI_MIN_CONTROL_RATE = 0.15
Constants.SKI_MAX_CONTROL_RATE = 1.2

-- Jetpack
Constants.JETPACK_MAX_ENERGY = 100
Constants.JETPACK_DRAIN_RATE = 36
Constants.JETPACK_REGEN_RATE = 24
Constants.JETPACK_REGEN_DELAY = 0.35
Constants.JETPACK_THRUST_START = 60
Constants.JETPACK_THRUST_MAX = 80
Constants.JETPACK_RAMP_UP_TIME = 0.65
Constants.JETPACK_RAMP_DOWN_TIME = 0.2
Constants.JETPACK_GRAVITY_SCALE = 0.45
Constants.JETPACK_SOFT_CAP_SPEED = 85
Constants.JETPACK_MIN_THRUST_SCALE = 0.55
Constants.AIR_CONTROL_ACCELERATION = 9
Constants.JETPACK_AIR_CONTROL_ACCELERATION = 12

-- Ground Detection + Landing
Constants.GROUND_CHECK_DISTANCE = 4.0
Constants.LANDING_VELOCITY_TRANSFER = 0.92  -- Anteil der tangentialen Landegeschwindigkeit

return Constants
