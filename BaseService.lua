-- BaseService.lua
-- Stromnetz, Generator-Schaden/Reparatur, Inventarstationen und Base-Turrets.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")

local Constants = require(ReplicatedStorage.Modules.BaseSystemConstants)
local MatchSignals = require(ReplicatedStorage.Modules.MatchSignals)
local CombatService = require(script.Parent.CombatService)

local inventoryEvent = ReplicatedStorage:WaitForChild("InventoryStation")

local BaseService = {}

type GeneratorState = {
	part: BasePart,
	team: Team,
	health: number,
	prompt: ProximityPrompt,
}

local generators: { [BasePart]: GeneratorState } = {}
local generatorsByTeam: { [Team]: GeneratorState } = {}
local stations: { [BasePart]: Team } = {}
local turrets: { [BasePart]: Team } = {}
local lastTurretFire: { [BasePart]: number } = {}
local lastStationUse: { [Player]: number } = {}
local lastBaseAttackAlert: { [Team]: number } = {}
local initialized = false
local turretAccumulator = 0
local baseEventSerial = 0

local function publishBaseEvent(kind: string, state: GeneratorState, actor: Player?)
	ReplicatedStorage:SetAttribute("BaseEventKind", kind)
	ReplicatedStorage:SetAttribute("BaseEventTeam", state.team.Name)
	ReplicatedStorage:SetAttribute("BaseEventPlayer", actor and actor.Name or "")
	baseEventSerial += 1
	ReplicatedStorage:SetAttribute("BaseEventSerial", baseEventSerial)
end

local function getTeam(instance: Instance): Team?
	local teamName = instance:GetAttribute("Team")
	local team = typeof(teamName) == "string" and Teams:FindFirstChild(teamName)
	return if team and team:IsA("Team") then team else nil
end

local function isPlayerNearPart(player: Player, part: BasePart, maxDistance: number): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil
		and humanoid.Health > 0
		and root ~= nil
		and root:IsA("BasePart")
		and (root.Position - part.Position).Magnitude <= maxDistance
end

local function setPoweredAttributes(team: Team, powered: boolean)
	ReplicatedStorage:SetAttribute("BasePower_" .. team.Name, powered)
	for part, stationTeam in stations do
		if stationTeam == team then
			part.Material = powered and Enum.Material.Neon or Enum.Material.Metal
			part.Color = powered and team.TeamColor.Color or Color3.fromRGB(70, 70, 75)
		end
	end
	for part, turretTeam in turrets do
		if turretTeam == team then
			part.Material = powered and Enum.Material.Metal or Enum.Material.Slate
			part.Color = powered and team.TeamColor.Color or Color3.fromRGB(55, 55, 60)
		end
	end
end

local function publishGenerator(state: GeneratorState)
	local powered = state.health > 0
	local ratio = math.clamp(state.health / Constants.GENERATOR_MAX_HEALTH, 0, 1)
	state.part:SetAttribute("Health", state.health)
	state.part:SetAttribute("MaxHealth", Constants.GENERATOR_MAX_HEALTH)
	state.part:SetAttribute("Powered", powered)
	state.part:SetAttribute(
		"DamageStage",
		if not powered then "Offline" elseif ratio <= 0.25 then "Critical" elseif ratio <= 0.6 then "Damaged" else "Online"
	)
	state.part.Material = powered and Enum.Material.Neon or Enum.Material.CrackedLava
	state.part.Color = if not powered
		then Color3.fromRGB(45, 45, 48)
		elseif ratio <= 0.25
		then Color3.fromRGB(255, 106, 45)
		else state.team.TeamColor.Color

	local light = state.part:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = if powered then 0.8 + ratio * 2.2 else 0
		light.Range = if powered then 14 + ratio * 18 else 0
	end
	local smoke = state.part:FindFirstChild("DamageSmoke")
	if not smoke then
		smoke = Instance.new("Smoke")
		smoke.Name = "DamageSmoke"
		smoke.Color = Color3.fromRGB(70, 74, 82)
		smoke.Opacity = 0.34
		smoke.RiseVelocity = 5
		smoke.Size = 7
		smoke.Parent = state.part
	end
	(smoke :: Smoke).Enabled = ratio <= 0.6
	state.prompt.ActionText = powered and "Generator reparieren" or "Generator neu starten"
	ReplicatedStorage:SetAttribute("GeneratorHealth_" .. state.team.Name, state.health)
	ReplicatedStorage:SetAttribute("GeneratorMaxHealth_" .. state.team.Name, Constants.GENERATOR_MAX_HEALTH)
	setPoweredAttributes(state.team, powered)
end

local function findGenerator(instance: Instance?): GeneratorState?
	local current = instance
	while current and current ~= workspace do
		if current:IsA("BasePart") and generators[current] then
			return generators[current]
		end
		current = current.Parent
	end
	return nil
end

local function damageGenerator(attacker: Player, state: GeneratorState, amount: number): boolean
	local phase = MatchSignals.GetPhase()
	if phase ~= "InProgress" and phase ~= "Overtime" then
		return false
	end
	if attacker.Team == state.team or state.health <= 0 or amount <= 0 then
		return false
	end
	local previousHealth = state.health
	state.health = math.max(0, state.health - math.clamp(amount, 0, 500))
	publishGenerator(state)
	if previousHealth > 0 and state.health <= 0 then
		CombatService.AddObjective(attacker, 250, "GENERATOR DESTROYED")
		publishBaseEvent("Destroyed", state, attacker)
	elseif os.clock() - (lastBaseAttackAlert[state.team] or -math.huge) >= 6 then
		lastBaseAttackAlert[state.team] = os.clock()
		publishBaseEvent("UnderAttack", state, attacker)
	end
	return true
end

function BaseService.DamageHit(attacker: Player, hit: Instance, amount: number): boolean
	local state = findGenerator(hit)
	return state ~= nil and damageGenerator(attacker, state, amount)
end

function BaseService.DamageExplosion(
	attacker: Player,
	position: Vector3,
	radius: number,
	maxDamage: number,
	minDamage: number,
	excludedHit: Instance?
)
	local excludedState = findGenerator(excludedHit)
	for _, state in generators do
		if state ~= excludedState and state.health > 0 then
			local offset = state.part.Position - position
			local distance = offset.Magnitude
			if distance <= radius then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { attacker.Character, state.part }
				local blocked = distance > 0.1 and workspace:Raycast(position, offset, params) ~= nil
				if not blocked then
					local ratio = math.clamp(distance / radius, 0, 1)
					damageGenerator(attacker, state, maxDamage + (minDamage - maxDamage) * ratio)
				end
			end
		end
	end
end

function BaseService.IsPowered(team: Team): boolean
	local state = generatorsByTeam[team]
	return state ~= nil and state.health > 0
end

local function registerGenerator(instance: Instance)
	if not instance:IsA("BasePart") or generators[instance] then
		return
	end
	local team = getTeam(instance)
	if not team then
		warn("PowerGenerator ohne gültiges Team: " .. instance:GetFullName())
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RepairPrompt"
	prompt.ObjectText = team.Name .. " Generator"
	prompt.ActionText = "Generator reparieren"
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = true
	prompt.Parent = instance

	local state: GeneratorState = {
		part = instance,
		team = team,
		health = Constants.GENERATOR_MAX_HEALTH,
		prompt = prompt,
	}
	generators[instance] = state
	generatorsByTeam[team] = state
	publishGenerator(state)

	prompt.Triggered:Connect(function(player)
		if
			player.Team ~= team
			or state.health >= Constants.GENERATOR_MAX_HEALTH
			or not isPlayerNearPart(player, instance, prompt.MaxActivationDistance + 3)
		then
			return
		end
		local previousHealth = state.health
		state.health = math.min(Constants.GENERATOR_MAX_HEALTH, state.health + Constants.GENERATOR_REPAIR_AMOUNT)
		publishGenerator(state)
		local repaired = state.health - previousHealth
		if repaired > 0 then
			CombatService.AddObjective(player, math.max(10, math.floor(repaired / 4)), "GENERATOR REPAIR")
			if previousHealth <= 0 then
				publishBaseEvent("Restored", state, player)
			elseif state.health >= Constants.GENERATOR_MAX_HEALTH then
				publishBaseEvent("Repaired", state, player)
			end
		end
	end)
end

local function unregisterGenerator(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local state = generators[instance]
	if state then
		generators[instance] = nil
		if generatorsByTeam[state.team] == state then
			generatorsByTeam[state.team] = nil
			setPoweredAttributes(state.team, false)
		end
	end
end

local function registerStation(instance: Instance)
	if not instance:IsA("BasePart") or stations[instance] then
		return
	end
	local team = getTeam(instance)
	if not team then
		return
	end
	stations[instance] = team

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "InventoryPrompt"
	prompt.ObjectText = team.Name .. " Inventory Station"
	prompt.ActionText = "Ausrüsten / Auffüllen"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		if
			player.Team ~= team
			or now - (lastStationUse[player] or -math.huge) < Constants.INVENTORY_USE_COOLDOWN
			or not isPlayerNearPart(player, instance, prompt.MaxActivationDistance + 3)
		then
			return
		end
		lastStationUse[player] = now
		if not BaseService.IsPowered(team) then
			inventoryEvent:FireClient(player, false, "Station ohne Strom - Generator reparieren")
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = humanoid.MaxHealth
		end
		local maxGrenades = player:GetAttribute("MaxGrenades")
		if typeof(maxGrenades) == "number" then
			player:SetAttribute("Grenades", maxGrenades)
		end
		player:SetAttribute("InventoryAccessUntil", os.clock() + Constants.INVENTORY_ACCESS_TIME)
		inventoryEvent:FireClient(player, true, "Station aktiv: Gesundheit und Ausrüstung aufgefüllt")
	end)
	setPoweredAttributes(team, BaseService.IsPowered(team))
end

local function unregisterStation(instance: Instance)
	if instance:IsA("BasePart") then
		stations[instance] = nil
	end
end

local function registerTurret(instance: Instance)
	if not instance:IsA("BasePart") or turrets[instance] then
		return
	end
	local team = getTeam(instance)
	if not team then
		return
	end
	turrets[instance] = team
	lastTurretFire[instance] = -math.huge
	setPoweredAttributes(team, BaseService.IsPowered(team))
end

local function unregisterTurret(instance: Instance)
	if instance:IsA("BasePart") then
		turrets[instance] = nil
		lastTurretFire[instance] = nil
	end
end

local function findTurretTarget(turret: BasePart, team: Team): (Player?, BasePart?)
	local bestPlayer: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = Constants.TURRET_RANGE
	for _, player in Players:GetPlayers() do
		if player.Team ~= team then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				local offset = root.Position - turret.Position
				local distance = offset.Magnitude
				if distance < bestDistance then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { turret }
					local result = workspace:Raycast(turret.Position, offset, params)
					if result and result.Instance:IsDescendantOf(character) then
						bestDistance = distance
						bestPlayer = player
						bestRoot = root
					end
				end
			end
		end
	end
	return bestPlayer, bestRoot
end

local function showTurretTracer(origin: Vector3, target: Vector3, color: Color3)
	local distance = (target - origin).Magnitude
	local tracer = Instance.new("Part")
	tracer.Name = "BaseTurretTracer"
	tracer.Size = Vector3.new(0.12, 0.12, distance)
	tracer.CFrame = CFrame.lookAt(origin, target) * CFrame.new(0, 0, -distance / 2)
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = color
	tracer.Parent = workspace
	Debris:AddItem(tracer, 0.06)
end

RunService.Heartbeat:Connect(function(dt)
	turretAccumulator += dt
	if turretAccumulator < Constants.TURRET_UPDATE_INTERVAL then
		return
	end
	turretAccumulator = 0
	local now = os.clock()

	for turret, team in turrets do
		if not turret.Parent then
			turrets[turret] = nil
			lastTurretFire[turret] = nil
			continue
		end
		if not BaseService.IsPowered(team) then
			continue
		end

		local targetPlayer, targetRoot = findTurretTarget(turret, team)
		if targetPlayer and targetRoot then
			turret.CFrame = CFrame.lookAt(turret.Position, targetRoot.Position)
			if now - (lastTurretFire[turret] or -math.huge) >= Constants.TURRET_FIRE_INTERVAL then
				lastTurretFire[turret] = now
				showTurretTracer(turret.Position, targetRoot.Position, team.TeamColor.Color)
				local humanoid = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					CombatService.DamageFromTeam(
						team,
						team.Name .. " Base Turret",
						humanoid,
						Constants.TURRET_DAMAGE,
						"Base Turret"
					)
				end
			end
		end
	end
end)

local function resetGenerators()
	table.clear(lastBaseAttackAlert)
	for _, state in generators do
		state.health = Constants.GENERATOR_MAX_HEALTH
		publishGenerator(state)
	end
end

function BaseService.Init()
	if initialized then
		return
	end
	initialized = true

	CollectionService:GetInstanceAddedSignal(Constants.GENERATOR_TAG):Connect(registerGenerator)
	CollectionService:GetInstanceRemovedSignal(Constants.GENERATOR_TAG):Connect(unregisterGenerator)
	CollectionService:GetInstanceAddedSignal(Constants.INVENTORY_STATION_TAG):Connect(registerStation)
	CollectionService:GetInstanceRemovedSignal(Constants.INVENTORY_STATION_TAG):Connect(unregisterStation)
	CollectionService:GetInstanceAddedSignal(Constants.BASE_TURRET_TAG):Connect(registerTurret)
	CollectionService:GetInstanceRemovedSignal(Constants.BASE_TURRET_TAG):Connect(unregisterTurret)

	for _, instance in CollectionService:GetTagged(Constants.GENERATOR_TAG) do
		registerGenerator(instance)
	end
	for _, instance in CollectionService:GetTagged(Constants.INVENTORY_STATION_TAG) do
		registerStation(instance)
	end
	for _, instance in CollectionService:GetTagged(Constants.BASE_TURRET_TAG) do
		registerTurret(instance)
	end

	MatchSignals.RoundStarted:Connect(resetGenerators)
	Players.PlayerRemoving:Connect(function(player)
		lastStationUse[player] = nil
	end)
end

BaseService.Init()

return BaseService
