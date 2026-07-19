-- MovementConstants.lua
-- Ablageort: ReplicatedStorage/Modules/MovementConstants
-- Zentrale Tuning-Werte für Skiing + Jetpack. Alles hier verändern, nicht im Controller-Code.

local Constants = {}

-- Grundbewegung
Constants.WALK_SPEED = 16          -- normale Laufgeschwindigkeit (studs/s)
Constants.MAX_SKI_SPEED = 120      -- Speed-Cap beim Skiing, verhindert unendliche Beschleunigung
Constants.GRAVITY = 90             -- eigene Gravitationskonstante (studs/s^2).
                                    -- workspace.Gravity in Studio auf 0 setzen, sonst wirkt
                                    -- Roblox' eingebaute Gravitation zusätzlich zu dieser hier.
Constants.JUMP_POWER = 50          -- initiale Sprung-Geschwindigkeit nach oben (studs/s)

-- Skiing
Constants.SKI_GROUND_FRICTION = 0.02   -- Reibung beim Skiing (fast 0 = Momentum bleibt erhalten)
Constants.WALK_GROUND_FRICTION = 8.0   -- Reibung beim normalen Laufen (hohe Bremsung)
Constants.SKI_MIN_SLOPE_ANGLE = 5      -- Grad; unterhalb dieses Winkels zählt der Boden als "flach"

-- Jetpack
Constants.JETPACK_MAX_ENERGY = 100
Constants.JETPACK_DRAIN_RATE = 40      -- Energie/Sekunde während Thrust
Constants.JETPACK_REGEN_RATE = 20      -- Energie/Sekunde wenn nicht aktiv
Constants.JETPACK_REGEN_DELAY = 0.5    -- Sekunden Pause nach letztem Thrust, bevor Regen startet
Constants.JETPACK_THRUST_FORCE = 150   -- Beschleunigung nach oben (studs/s^2) - muss > GRAVITY
                                        -- sein, sonst sinkt man beim Thrusten nur langsamer statt zu steigen

-- Ground Detection
Constants.GROUND_CHECK_DISTANCE = 3.5  -- Raycast-Länge nach unten (Studs)

return Constants
