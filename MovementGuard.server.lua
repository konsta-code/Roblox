-- MovementGuard.server.lua
-- Hard safety limits for invalid/excessive velocity plus conservative
-- detection-only telemetry for teleport and acceleration anomalies. Position
-- corrections are deliberately avoided so legitimate skiing never jitters.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Modules.MovementConstants)
local MatchSignals = require(ReplicatedStorage.Modules.MatchSignals)

type Snapshot = {
	position: Vector3,
	velocity: Vector3,
	time: number,
	graceUntil: number,
	lastWarning: number,
}

local snapshots: { [Player]: Snapshot } = {}
local accumulator = 0
local CHECK_INTERVAL = 0.1
local WARNING_COOLDOWN = 2

-- Praesentations-Sync: der Client meldet Ski-/Jet-Status (MovementPresentation),
-- der Server spiegelt ihn als CHARACTER-Attribut -- das repliziert an alle
-- Clients, damit Fremd-Charaktere echte Ski-Posen + Ski-Sounds kriegen
-- (CharacterMotion liest genau diese Model-Attribute). Rein kosmetisch, hat
-- keinerlei Einfluss auf Physik oder Schaden -- deshalb reicht Typ-Check +
-- Rate-Limit statt Plausibilitaetspruefung. Dynamisch erzeugt statt in
-- default.project.json (kein rojo-serve-Neustart noetig).
local stateSyncEvent = ReplicatedStorage:FindFirstChild("MovementStateSync") :: RemoteEvent?
if not stateSyncEvent then
	local event = Instance.new("RemoteEvent")
	event.Name = "MovementStateSync"
	event.Parent = ReplicatedStorage
	stateSyncEvent = event
end
local lastStateSync: { [Player]: number } = {}

assert(stateSyncEvent).OnServerEvent:Connect(function(player, skiing, jetpacking)
	if typeof(skiing) ~= "boolean" or typeof(jetpacking) ~= "boolean" then return end
	local now = os.clock()
	if now - (lastStateSync[player] or 0) < 0.08 then return end
	lastStateSync[player] = now
	local character = player.Character
	if character then
		character:SetAttribute("IsSkiing", skiing)
		character:SetAttribute("IsJetpacking", jetpacking)
	end
end)

local function isFinite(vector: Vector3): boolean
	return vector.X == vector.X
		and vector.Y == vector.Y
		and vector.Z == vector.Z
		and math.abs(vector.X) < 1e7
		and math.abs(vector.Y) < 1e7
		and math.abs(vector.Z) < 1e7
end

local function grantGrace(player: Player)
	local snapshot = snapshots[player]
	if snapshot then
		snapshot.graceUntil = os.clock() + Constants.SERVER_SPAWN_GRACE_TIME
	else
		player:SetAttribute("MovementGuardGrace", true)
	end
end

local function resetForCharacter(player: Player, character: Model)
	snapshots[player] = nil
	player:SetAttribute("MovementGuardGrace", true)
	task.delay(Constants.SERVER_SPAWN_GRACE_TIME, function()
		if player.Parent and player.Character == character then
			player:SetAttribute("MovementGuardGrace", nil)
		end
	end)
end

local function registerPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		resetForCharacter(player, character)
	end)
	if player.Character then
		resetForCharacter(player, player.Character)
	end
end

local function warnSuspicious(player: Player, snapshot: Snapshot, reason: string)
	local now = os.clock()
	if now - snapshot.lastWarning < WARNING_COOLDOWN then
		return
	end
	snapshot.lastWarning = now
	warn(string.format("[MovementGuard] %s: %s", player.Name, reason))
end

for _, player in Players:GetPlayers() do
	registerPlayer(player)
end
Players.PlayerAdded:Connect(registerPlayer)
Players.PlayerRemoving:Connect(function(player)
	snapshots[player] = nil
	lastStateSync[player] = nil
end)

MatchSignals.RoundStarted:Connect(function()
	for _, player in Players:GetPlayers() do
		grantGrace(player)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < CHECK_INTERVAL then
		return
	end
	accumulator = 0
	local now = os.clock()

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end

		local position = root.Position
		local velocity = root.AssemblyLinearVelocity
		if not isFinite(position) then
			warn("[MovementGuard] invalid position for " .. player.Name)
			continue
		end
		if not isFinite(velocity) then
			root.AssemblyLinearVelocity = Vector3.zero
			velocity = Vector3.zero
		elseif velocity.Magnitude > Constants.SERVER_MAX_LINEAR_SPEED then
			root.AssemblyLinearVelocity = velocity.Unit * Constants.SERVER_MAX_LINEAR_SPEED
			velocity = root.AssemblyLinearVelocity
		end

		local snapshot = snapshots[player]
		if not snapshot then
			snapshot = {
				position = position,
				velocity = velocity,
				time = now,
				graceUntil = now + Constants.SERVER_SPAWN_GRACE_TIME,
				lastWarning = -math.huge,
			}
			snapshots[player] = snapshot
			continue
		end

		if player:GetAttribute("MovementGuardGrace") then
			snapshot.graceUntil = now + Constants.SERVER_SPAWN_GRACE_TIME
			player:SetAttribute("MovementGuardGrace", nil)
		end

		local elapsed = math.max(now - snapshot.time, 1 / 240)
		if now >= snapshot.graceUntil then
			local travelSpeed = (position - snapshot.position).Magnitude / elapsed
			local acceleration = (velocity - snapshot.velocity).Magnitude / elapsed
			if travelSpeed > Constants.SERVER_MAX_TELEPORT_SPEED then
				warnSuspicious(player, snapshot, string.format("position jump %.0f studs/s", travelSpeed))
			elseif acceleration > Constants.SERVER_MAX_ACCELERATION then
				warnSuspicious(player, snapshot, string.format("acceleration spike %.0f studs/s^2", acceleration))
			end
		end

		snapshot.position = position
		snapshot.velocity = velocity
		snapshot.time = now
	end
end)
