-- SpawnManager.server.lua
-- Ablageort: ServerScriptService
--
-- Zwei Spawn-Wege parallel, bewusst nicht dasselbe System:
--  1. Erstes Spawnen und Sterben+Respawn laufen komplett über Robloxens
--     eingebautes SpawnLocation-System - kein Code hier nötig, siehe Setup.
--  2. Rundenstart: schon lebende Spieler werden aktiv zu ihrem Team-Spawn
--     teleportiert. Robloxens automatische Auswahl greift nur bei frisch
--     erzeugten Charakteren, nicht bei einem Spieler, der schon mitten auf
--     der Map steht.
--
-- Manuelle Setup-Schritte:
--  1. Pro Team mindestens ein SpawnLocation-Part im Level platzieren,
--     Neutral = false, TeamColor = Farbe des jeweiligen Teams (deckt Punkt 1 ab)
--  2. Dieselben oder zusätzliche Spawn-Parts zusätzlich mit CollectionService-
--     Tag "PlayerSpawn" + Attribut Team="Red"/"Blue" versehen (deckt Punkt 2 ab)
--
-- Team-Zuweisung beim Beitritt läuft über TeamAssignment.server.lua
-- (Auto-Balance Red/Blue). Ohne dieses Script wäre player.Team für neue
-- Spieler nil, und SpawnLocations mit TeamColor würden nicht gefunden.
--
-- Bekannte Lücke: beide Waffen (ProjectileWeapon, Chaingun) haben aktuell
-- keinen Friendly-Fire-Schutz, weil sie player.Team nirgends abfragen.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.SpawnConstants)
local MatchSignals = require(ReplicatedStorage.Modules.MatchSignals)

local spawnsByTeam: { [Team]: { BasePart } } = {}

local seenSpawns: { [Instance]: boolean } = {}

local function grantSpawnProtection(character: Model)
	local oldForceField = character:FindFirstChildOfClass("ForceField")
	if oldForceField then
		oldForceField:Destroy()
	end

	local forceField = Instance.new("ForceField")
	forceField.Name = "SpawnProtection"
	forceField.Visible = true
	forceField.Parent = character
	local protectedPlayer = Players:GetPlayerFromCharacter(character)
	if protectedPlayer then
		protectedPlayer:SetAttribute(
			"SpawnProtectedUntil",
			workspace:GetServerTimeNow() + Constants.SPAWN_PROTECTION_DURATION
		)
	end
	task.delay(Constants.SPAWN_PROTECTION_DURATION, function()
		if forceField.Parent then
			forceField:Destroy()
			if protectedPlayer and protectedPlayer.Parent == Players then
				protectedPlayer:SetAttribute("SpawnProtectedUntil", 0)
			end
		end
	end)
end

local function bindSpawnProtection(player: Player)
	player.CharacterAdded:Connect(grantSpawnProtection)
	if player.Character then
		grantSpawnProtection(player.Character)
	end
end

local function registerSpawn(spawnPart: Instance)
	if seenSpawns[spawnPart] or not spawnPart:IsA("BasePart") then return end

	local teamName = spawnPart:GetAttribute("Team")
	local team = teamName and Teams:FindFirstChild(teamName)
	if not team then
		warn("PlayerSpawn ohne gültiges Team-Attribut: " .. spawnPart:GetFullName())
		return
	end
	seenSpawns[spawnPart] = true

	spawnsByTeam[team] = spawnsByTeam[team] or {}
	table.insert(spawnsByTeam[team], spawnPart)
end

local function unregisterSpawn(spawnPart: Instance)
	if not seenSpawns[spawnPart] then return end
	seenSpawns[spawnPart] = nil
	for _, list in spawnsByTeam do
		local idx = table.find(list, spawnPart)
		if idx then
			table.remove(list, idx)
		end
	end
end

-- Robust gegen Timing (MapBuilder taggt die Spawns evtl. erst NACH diesem
-- Script - Reihenfolge in ServerScriptService nicht garantiert) und gegen
-- Rebuilds: vorhandene via GetTagged, spätere via Added-Signal, entfernte via
-- Removed-Signal. seen-Set verhindert Doppel-Registrierung.
local function indexSpawns()
	CollectionService:GetInstanceAddedSignal(Constants.SPAWN_TAG):Connect(registerSpawn)
	CollectionService:GetInstanceRemovedSignal(Constants.SPAWN_TAG):Connect(unregisterSpawn)
	for _, spawnPart in CollectionService:GetTagged(Constants.SPAWN_TAG) do
		registerSpawn(spawnPart)
	end
end

local function getRandomSpawnCFrame(team: Team): CFrame?
	local list = spawnsByTeam[team]
	if not list or #list == 0 then return nil end
	local chosen = list[math.random(1, #list)]
	return chosen.CFrame + Vector3.new(0, Constants.SPAWN_HEIGHT_OFFSET, 0)
end

local function teleportToTeamSpawn(player: Player)
	local team = player.Team :: Team?
	local character = player.Character
	if not team or not character then return end

	local spawnCFrame = getRandomSpawnCFrame(team)
	if not spawnCFrame then
		warn("Kein getaggter Spawn für Team " .. team.Name .. " gefunden - " .. player.Name .. " bleibt stehen")
		return
	end

	character:PivotTo(spawnCFrame)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
	grantSpawnProtection(character)
end

MatchSignals.RoundStarted:Connect(function()
	for _, player in Players:GetPlayers() do
		teleportToTeamSpawn(player)
	end
end)

indexSpawns()

Players.PlayerAdded:Connect(bindSpawnProtection)
for _, player in Players:GetPlayers() do
	bindSpawnProtection(player)
end
