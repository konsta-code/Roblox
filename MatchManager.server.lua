-- MatchManager.server.lua
-- Ablageort: ServerScriptService
--
-- Orchestriert den Runden-Loop: Warmup -> InProgress -> PostMatch -> Warmup.
-- Win-Condition: zuerst X Captures ODER Zeitlimit erreicht (wer vorne liegt
-- gewinnt, bei Gleichstand: Unentschieden).
--
-- Reagiert auf Captures über CTFSignals statt direktem Zugriff auf
-- CTFManager - beide Systeme bleiben unabhängig voneinander.
--
-- Manueller Setup-Schritt: RemoteEvent "MatchStateChanged" in
-- ReplicatedStorage anlegen (Server -> Client, fürs HUD: Phase, Timer, Sieger)
--
-- Bekannte Lücke: Captures werden aktuell auch außerhalb von "InProgress"
-- physisch nicht verhindert (CTFManager kennt keine Match-Phasen) - sie
-- zählen nur nicht fürs Match. Für echte Turniere später CTFManager um
-- eine "Capturing erlaubt?"-Abfrage erweitern.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Modules.MatchConstants)
local CTFSignals = require(ReplicatedStorage.Modules.CTFSignals)
local MatchSignals = require(ReplicatedStorage.Modules.MatchSignals)

local matchStateEvent = ReplicatedStorage:WaitForChild("MatchStateChanged")

type MatchPhase = "Warmup" | "InProgress" | "PostMatch"

local phase: MatchPhase = "Warmup"
local phaseTimeRemaining = Constants.WARMUP_DURATION
local liveScores: { [Team]: number } = {}

local function broadcastState(winnerName: string?)
	matchStateEvent:FireAllClients(phase, math.max(0, math.ceil(phaseTimeRemaining)), winnerName)
end

local function enoughPlayers(): boolean
	return #Players:GetPlayers() >= Constants.MIN_PLAYERS_TO_START
end

local function startWarmup()
	phase = "Warmup"
	phaseTimeRemaining = Constants.WARMUP_DURATION
	broadcastState()
end

local function startMatch()
	phase = "InProgress"
	phaseTimeRemaining = Constants.MATCH_DURATION

	CTFSignals.RequestScoreReset()
	liveScores = {}
	for _, team in Teams:GetTeams() do
		liveScores[team] = 0
	end

	broadcastState()
	MatchSignals.FireRoundStarted()
end

local function endMatch()
	phase = "PostMatch"
	phaseTimeRemaining = Constants.POSTMATCH_DURATION

	local winner: Team? = nil
	local highest = -1
	local tie = false
	for team, score in liveScores do
		if score > highest then
			highest = score
			winner = team
			tie = false
		elseif score == highest then
			tie = true
		end
	end

	broadcastState(tie and "Unentschieden" or (winner and winner.Name or nil))
end

CTFSignals.CaptureOccurred:Connect(function(team: Team, newScore: number)
	if phase ~= "InProgress" then return end
	liveScores[team] = newScore
	if newScore >= Constants.CAPTURES_TO_WIN then
		endMatch()
	end
end)

RunService.Heartbeat:Connect(function(dt)
	phaseTimeRemaining -= dt
	if phaseTimeRemaining > 0 then return end

	if phase == "Warmup" then
		if enoughPlayers() then
			startMatch()
		else
			phaseTimeRemaining = Constants.WARMUP_DURATION
		end
	elseif phase == "InProgress" then
		endMatch() -- Zeitlimit erreicht
	elseif phase == "PostMatch" then
		startWarmup()
	end
end)

startWarmup()
