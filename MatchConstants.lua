-- MatchConstants.lua
-- Ablageort: ReplicatedStorage/Modules/MatchConstants

local Constants = {}

Constants.MIN_PLAYERS_TO_START = 1   -- für Solo-Testing; für echte Matches hochsetzen
Constants.WARMUP_DURATION = 10       -- Sekunden Countdown vor Rundenstart
Constants.MATCH_DURATION = 600       -- Sekunden (10 Minuten) Zeitlimit pro Runde
Constants.CAPTURES_TO_WIN = 5        -- Team gewinnt sofort bei so vielen Captures
Constants.POSTMATCH_DURATION = 8     -- Sekunden Pause nach Rundenende

return Constants
