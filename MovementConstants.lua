-- MovementConstants.lua
-- Clean-room Roblox adaptation of values exposed by the old Tribes: Ascend
-- UnrealScript defaults. The original game used Unreal Units (UU); this
-- project consistently maps 20 UU to one Roblox stud.

local Constants = {}

Constants.BUILD_ID = "tribes-core-4"
Constants.UU_PER_STUD = 20

-- Base movement (TrFamilyInfo: GroundSpeed 440, JumpZ 322).
Constants.WALK_SPEED = 440 / Constants.UU_PER_STUD
Constants.JUMP_SPEED = 322 / Constants.UU_PER_STUD
Constants.GRAVITY = 520 / Constants.UU_PER_STUD
Constants.WALK_RESPONSE = 12
Constants.GROUND_CHECK_DISTANCE = 4.2
Constants.MAX_WALKABLE_NORMAL_Y = 0.55

-- Skiing (TrFamilyInfo / TrPawn defaults).
Constants.SKI_FRICTION = 0.003
Constants.SKI_SLOPE_GRAVITY_BOOST = 2
Constants.SKI_LANDING_TRANSFER = 1
Constants.SKI_MAX_SPEED = 2500 / Constants.UU_PER_STUD
Constants.SKI_TERMINAL_SPEED = 3000 / Constants.UU_PER_STUD
Constants.SKI_PEAK_CONTROL_SPEED = 1600 / Constants.UU_PER_STUD
Constants.SKI_CONTROL_SIGMA_SQUARED = 100000 / (Constants.UU_PER_STUD ^ 2)
Constants.SKI_MAX_CONTROL_PCT = 0.65
Constants.SKI_STEER_RESPONSE = 4
Constants.SKI_ACCEL_CAP_SPEED = 1700 / Constants.UU_PER_STUD
Constants.SKI_ACCEL_PCT = 0.4
-- Absprung-Schwelle: trägt die Velocity den Skifahrer über einer konvexen
-- Kuppe (Kamm/Rampen-Lippe) mit mehr als diesem Wert (Studs/s) von der Fläche
-- WEG, wird er in die Luft entlassen statt an den Boden gesnappt. Klein genug,
-- dass echte Kämme/Schanzen mit Speed sicher abheben, groß genug, dass sanfte
-- Bodenwellen beim normalen Skiing nicht ungewollt Sprünge auslösen.
Constants.SKI_LAUNCH_THRESHOLD = 6

-- Air control (AirSpeed 550 * AirControl 0.2).
Constants.AIR_CONTROL_ACCELERATION = (550 * 0.2) / Constants.UU_PER_STUD

-- Jetpack / power pool defaults.
Constants.JETPACK_MAX_ENERGY = 100
Constants.JETPACK_DRAIN_RATE = 30
Constants.JETPACK_REGEN_RATE = 13
Constants.JETPACK_INITIAL_COST = 1
Constants.JETPACK_RESTART_ENERGY = 10
Constants.JETPACK_FORWARD_PCT = 0.4
Constants.JETPACK_INIT_DURATION = 2.4
Constants.JETPACK_INIT_BOOST_ACCELERATION = 12
Constants.JETPACK_MAX_BOOST_GROUND_SPEED = 1600 / Constants.UU_PER_STUD
Constants.JETPACK_THRUST_SPEED = 1000 / Constants.UU_PER_STUD
Constants.JETPACK_ACCEL_AT_THRUST_SPEED = 16 / Constants.UU_PER_STUD
Constants.JETPACK_LIFT_ACCELERATION = 150 / Constants.UU_PER_STUD
Constants.JETPACK_RAMP_UP_TIME = 0.3
Constants.JETPACK_RAMP_DOWN_TIME = 0.15
Constants.JETPACK_TERMINAL_SPEED = 3000 / Constants.UU_PER_STUD

-- Server sanity limits leave room for a full-strength disc jump.
Constants.SERVER_MAX_LINEAR_SPEED = 225
Constants.SERVER_MAX_TELEPORT_SPEED = 500
Constants.SERVER_MAX_ACCELERATION = 2500
Constants.SERVER_SPAWN_GRACE_TIME = 3
Constants.MAX_EXTERNAL_IMPULSE = 140

return Constants
