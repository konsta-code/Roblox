-- MatchConstants.lua
-- Ablageort: ReplicatedStorage/Modules/MatchConstants

local Constants = {}

Constants.MIN_PLAYERS_TO_START = 1   -- für Solo-Testing; für echte Matches hochsetzen
Constants.WARMUP_DURATION = 10       -- Sekunden Countdown vor Rundenstart
Constants.MATCH_DURATION = 600       -- Sekunden (10 Minuten) Zeitlimit pro Runde
Constants.OVERTIME_DURATION = 120   -- Sudden Death bei Gleichstand
Constants.CAPTURES_TO_WIN = 5        -- Team gewinnt sofort bei so vielen Captures
Constants.POSTMATCH_DURATION = 25    -- Sekunden nach Rundenende: Podium + Map-Voting

return Constants
