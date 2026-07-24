-- MatchConstants.lua
-- Ablageort: ReplicatedStorage/Modules/MatchConstants

local Constants = {}

Constants.MIN_PLAYERS_TO_START = 1   -- für Solo-Testing; für echte Matches hochsetzen
Constants.LOBBY_DURATION = 45        -- max. Sekunden Lobby (Klassenwahl + Ready), danach geht's automatisch weiter
Constants.LOBBY_READY_FRACTION = 0.6 -- Anteil bereiter Spieler, der die Lobby sofort beendet (min. 1)
Constants.WARMUP_DURATION = 6        -- Sekunden Countdown vor Rundenstart (vorher 10)
Constants.MATCH_DURATION = 600       -- Sekunden (10 Minuten) Zeitlimit pro Runde
Constants.OVERTIME_DURATION = 90     -- Sudden Death bei Gleichstand (vorher 120)
Constants.CAPTURES_TO_WIN = 5        -- Team gewinnt sofort bei so vielen Captures
Constants.POSTMATCH_DURATION = 18    -- Sekunden nach Rundenende: Podium + Map-Voting (vorher 25)

return Constants
