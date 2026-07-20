-- CTFSignals.lua
-- Ablageort: ReplicatedStorage/Modules/CTFSignals
--
-- Server-interne Signale zwischen CTFManager und MatchManager - gleiches
-- Muster wie PlayerHudState fürs Client-HUD, nur serverseitig. Hält beide
-- Systeme entkoppelt: CTFManager weiß nichts von Runden/Win-Conditions,
-- MatchManager greift nie direkt auf CTFManager-Internals zu.

local CTFSignals = {}

local captureOccurred = Instance.new("BindableEvent")
CTFSignals.CaptureOccurred = captureOccurred.Event

function CTFSignals.FireCaptureOccurred(team: Team, newScore: number)
	captureOccurred:Fire(team, newScore)
end

local resetScoresRequested = Instance.new("BindableEvent")
CTFSignals.ResetScoresRequested = resetScoresRequested.Event

function CTFSignals.RequestScoreReset()
	resetScoresRequested:Fire()
end

local flagFumbleRequested = Instance.new("BindableEvent")
CTFSignals.FlagFumbleRequested = flagFumbleRequested.Event

function CTFSignals.RequestFlagFumble(player: Player)
	flagFumbleRequested:Fire(player)
end

return CTFSignals
