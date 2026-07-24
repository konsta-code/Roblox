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

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Modules.MatchConstants)
local CTFSignals = require(ReplicatedStorage.Modules.CTFSignals)
local MatchSignals = require(ReplicatedStorage.Modules.MatchSignals)

local matchStateEvent = ReplicatedStorage:WaitForChild("MatchStateChanged")
local teamPingEvent = ReplicatedStorage:FindFirstChild("TeamPing")
if not teamPingEvent or not teamPingEvent:IsA("RemoteEvent") then
	if teamPingEvent then
		teamPingEvent:Destroy()
	end
	teamPingEvent = Instance.new("RemoteEvent")
	teamPingEvent.Name = "TeamPing"
	teamPingEvent.Parent = ReplicatedStorage
end

local lastTeamPing: { [Player]: number } = {}

local function isFinitePosition(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < 1e5 and math.abs(value.Y) < 1e5 and math.abs(value.Z) < 1e5
end

local function resolvePingKind(player: Player, position: Vector3): string
	for _, instance in CollectionService:GetTagged("CTFFlag") do
		if instance:IsA("BasePart") and (instance.Position - position).Magnitude <= 20 then
			local flagTeam = string.gsub(instance.Name, "Flag$", "")
			return if player.Team and flagTeam == player.Team.Name then "DEFEND FLAG" else "ATTACK FLAG"
		end
	end
	for _, instance in CollectionService:GetTagged("PowerGenerator") do
		if instance:IsA("BasePart") and (instance.Position - position).Magnitude <= 24 then
			local generatorTeam = instance:GetAttribute("Team")
			return if player.Team and generatorTeam == player.Team.Name then "DEFEND GENERATOR" else "ATTACK GENERATOR"
		end
	end
	return "MOVE"
end

(teamPingEvent :: RemoteEvent).OnServerEvent:Connect(function(player: Player, requestedPosition: any)
	local now = os.clock()
	if now - (lastTeamPing[player] or -math.huge) < 1 then
		return
	end
	if not isFinitePosition(requestedPosition) or not player.Team then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	local position = requestedPosition :: Vector3
	-- Bounds an die groesseren Pool-Maps angepasst (X +-760, Z +-952); die
	-- Magnitude erlaubt Pings ueber die ganze Karte (Diagonale ~2400).
	if (position - root.Position).Magnitude > 2600
		or math.abs(position.X) > 820
		or math.abs(position.Z) > 1000
		or position.Y < -155
		or position.Y > 450 then
		return
	end

	lastTeamPing[player] = now
	local kind = resolvePingKind(player, position)
	local expiresAt = workspace:GetServerTimeNow() + 6
	for _, teammate in Players:GetPlayers() do
		if teammate.Team == player.Team then
			(teamPingEvent :: RemoteEvent):FireClient(teammate, player.DisplayName, position, kind, expiresAt)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastTeamPing[player] = nil
end)

type MatchPhase = "Warmup" | "InProgress" | "Overtime" | "PostMatch"

local phase: MatchPhase = "Warmup"
local phaseTimeRemaining = Constants.WARMUP_DURATION
local liveScores: { [Team]: number } = {}
local lastBroadcastSecond = -1
local mapVotes: { [Player]: string } = {}
local transitioning = false

-- Map-Voting: Stimmen werden NUR in der PostMatch-Phase gezaehlt. Jeder Spieler
-- hat eine (aenderbare) Stimme; die Gewinner-Map baut MatchManager am Ende der
-- PostMatch-Phase (siehe Heartbeat) ueber _G.RequestMapSwitch (MapDirector).
local mapVoteEvent = ReplicatedStorage:WaitForChild("MapVote", 10)
if mapVoteEvent and mapVoteEvent:IsA("RemoteEvent") then
	mapVoteEvent.OnServerEvent:Connect(function(player: Player, mapId)
		if phase == "PostMatch" and typeof(mapId) == "string" then
			mapVotes[player] = mapId
		end
	end)
end
Players.PlayerRemoving:Connect(function(player)
	mapVotes[player] = nil
end)

local function broadcastState(winnerName: string?)
	local roundedTime = math.max(0, math.ceil(phaseTimeRemaining))
	lastBroadcastSecond = roundedTime
	ReplicatedStorage:SetAttribute("MatchPhase", phase)
	ReplicatedStorage:SetAttribute("MatchTimeRemaining", roundedTime)
	ReplicatedStorage:SetAttribute("MatchWinner", winnerName)
	matchStateEvent:FireAllClients(phase, roundedTime, winnerName)
end

local function enoughPlayers(): boolean
	return #Players:GetPlayers() >= Constants.MIN_PLAYERS_TO_START
end

local function startWarmup()
	phase = "Warmup"
	phaseTimeRemaining = Constants.WARMUP_DURATION
	ReplicatedStorage:SetAttribute("MatchOvertime", false)
	ReplicatedStorage:SetAttribute("MatchMVP", nil)
	ReplicatedStorage:SetAttribute("MatchMVPScore", nil)
	MatchSignals.SetPhase(phase)
	broadcastState()
end

local function startMatch()
	phase = "InProgress"
	phaseTimeRemaining = Constants.MATCH_DURATION
	ReplicatedStorage:SetAttribute("MatchOvertime", false)
	ReplicatedStorage:SetAttribute("MatchMVP", nil)
	ReplicatedStorage:SetAttribute("MatchMVPScore", nil)
	for placeIndex = 1, 3 do
		ReplicatedStorage:SetAttribute("MatchTop" .. placeIndex .. "Name", nil)
		ReplicatedStorage:SetAttribute("MatchTop" .. placeIndex .. "Score", nil)
	end

	CTFSignals.RequestScoreReset()
	liveScores = {}
	for _, team in Teams:GetTeams() do
		liveScores[team] = 0
	end

	MatchSignals.SetPhase(phase)
	broadcastState()
	MatchSignals.FireRoundStarted()
end

local function startOvertime()
	phase = "Overtime"
	phaseTimeRemaining = Constants.OVERTIME_DURATION
	ReplicatedStorage:SetAttribute("MatchOvertime", true)
	MatchSignals.SetPhase(phase)
	broadcastState()
end

local function scoresAreTied(): boolean
	local highest = -math.huge
	local teamsAtHighest = 0
	for _, score in liveScores do
		if score > highest then
			highest = score
			teamsAtHighest = 1
		elseif score == highest then
			teamsAtHighest += 1
		end
	end
	return teamsAtHighest > 1
end

local function endMatch()
	phase = "PostMatch"
	phaseTimeRemaining = Constants.POSTMATCH_DURATION
	MatchSignals.SetPhase(phase)

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

	local bestPlayer: Player? = nil
	local bestScore = -1
	for _, player in Players:GetPlayers() do
		if tie or not winner or player.Team == winner then
			local roundScore = player:GetAttribute("RoundScore")
			local score = if typeof(roundScore) == "number" then roundScore else 0
			if score > bestScore then
				bestPlayer = player
				bestScore = score
			end
		end
	end
	ReplicatedStorage:SetAttribute("MatchMVP", bestPlayer and bestPlayer.DisplayName or nil)
	ReplicatedStorage:SetAttribute("MatchMVPScore", bestPlayer and bestScore or nil)
	ReplicatedStorage:SetAttribute("MatchOvertime", false)

	-- Top 3 nach RoundScore fuers Podium (ReplicatedStorage-Attribute wie MVP).
	local ranking = {}
	for _, participant in Players:GetPlayers() do
		local roundScore = participant:GetAttribute("RoundScore")
		table.insert(ranking, {
			name = participant.DisplayName,
			score = if typeof(roundScore) == "number" then roundScore else 0,
		})
	end
	table.sort(ranking, function(a, b)
		return a.score > b.score
	end)
	for placeIndex = 1, 3 do
		local entry = ranking[placeIndex]
		ReplicatedStorage:SetAttribute("MatchTop" .. placeIndex .. "Name", entry and entry.name or nil)
		ReplicatedStorage:SetAttribute("MatchTop" .. placeIndex .. "Score", entry and entry.score or nil)
	end

	broadcastState(tie and "Unentschieden" or (winner and winner.Name or nil))
end

CTFSignals.CaptureOccurred:Connect(function(team: Team, newScore: number)
	if phase ~= "InProgress" and phase ~= "Overtime" then return end
	liveScores[team] = newScore
	if phase == "Overtime" or newScore >= Constants.CAPTURES_TO_WIN then
		endMatch()
	end
end)

RunService.Heartbeat:Connect(function(dt)
	phaseTimeRemaining -= dt
	if math.max(0, math.ceil(phaseTimeRemaining)) ~= lastBroadcastSecond then
		local winnerAttribute = ReplicatedStorage:GetAttribute("MatchWinner")
		broadcastState(if typeof(winnerAttribute) == "string" then winnerAttribute else nil)
	end
	if phaseTimeRemaining > 0 then return end

	if phase == "Warmup" then
		if enoughPlayers() then
			startMatch()
		else
			phaseTimeRemaining = Constants.WARMUP_DURATION
		end
	elseif phase == "InProgress" then
		if scoresAreTied() then
			startOvertime()
		else
			endMatch()
		end
	elseif phase == "Overtime" then
		endMatch()
	elseif phase == "PostMatch" then
		-- Voting auswerten, Gewinner-Map bauen (yields ~5-15s, Spieler werden vom
		-- MapDirector sicher gehalten), dann die naechste Runde starten.
		if not transitioning then
			transitioning = true
			task.spawn(function()
				local tally: { [string]: number } = {}
				local bestId, bestVotes = nil, 0
				for _, votedId in mapVotes do
					local n = (tally[votedId] or 0) + 1
					tally[votedId] = n
					if n > bestVotes then
						bestId, bestVotes = votedId, n
					end
				end
				mapVotes = {}

				local currentId = workspace:GetAttribute("CurrentMapId")
				if bestId and bestId ~= currentId and typeof(_G.RequestMapSwitch) == "function" then
					_G.RequestMapSwitch(bestId)
				end

				transitioning = false
				startWarmup()
			end)
		end
	end
end)

startWarmup()
