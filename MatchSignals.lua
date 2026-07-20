-- MatchSignals.lua
-- Ablageort: ReplicatedStorage/Modules/MatchSignals
--
-- Server-interne Signale von MatchManager an andere Systeme (aktuell:
-- SpawnManager) - gleiches Muster wie CTFSignals/PlayerHudState.

local MatchSignals = {}

export type MatchPhase = "Warmup" | "InProgress" | "Overtime" | "PostMatch"

local currentPhase: MatchPhase = "Warmup"
local phaseChanged = Instance.new("BindableEvent")
MatchSignals.PhaseChanged = phaseChanged.Event

function MatchSignals.SetPhase(phase: MatchPhase)
	if currentPhase == phase then return end
	currentPhase = phase
	phaseChanged:Fire(phase)
end

function MatchSignals.GetPhase(): MatchPhase
	return currentPhase
end

local roundStarted = Instance.new("BindableEvent")
MatchSignals.RoundStarted = roundStarted.Event

function MatchSignals.FireRoundStarted()
	roundStarted:Fire()
end

return MatchSignals
