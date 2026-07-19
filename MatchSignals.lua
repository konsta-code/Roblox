-- MatchSignals.lua
-- Ablageort: ReplicatedStorage/Modules/MatchSignals
--
-- Server-interne Signale von MatchManager an andere Systeme (aktuell:
-- SpawnManager) - gleiches Muster wie CTFSignals/PlayerHudState.

local MatchSignals = {}

local roundStarted = Instance.new("BindableEvent")
MatchSignals.RoundStarted = roundStarted.Event

function MatchSignals.FireRoundStarted()
	roundStarted:Fire()
end

return MatchSignals
