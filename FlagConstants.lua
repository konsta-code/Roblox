-- FlagConstants.lua
-- Ablageort: ReplicatedStorage/Modules/FlagConstants

local Constants = {}

Constants.CAPTURE_RADIUS = 5            -- Studs, Nähe zum eigenen Stand zum Werten
Constants.RETURN_TIMER = 20             -- Sekunden bis eine gedroppte Flagge automatisch heimkehrt
Constants.FLAG_STAND_TAG = "FlagStand"  -- CollectionService-Tag für Flaggen-Stands im Level

return Constants
