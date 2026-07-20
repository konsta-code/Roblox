-- Equipment.server.lua
-- Serverautoritäre Granaten- und Nahkampfsimulation.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Modules.EquipmentConstants)
local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local CTFSignals = require(ReplicatedStorage.Modules.CTFSignals)
local MatchSignals = require(ReplicatedStorage.Modules.MatchSignals)
local CombatService = require(script.Parent.CombatService)
local BaseService = require(script.Parent.BaseService)

local throwEvent = ReplicatedStorage:WaitForChild("ThrowGrenade")
local meleeEvent = ReplicatedStorage:WaitForChild("MeleeAttack")
local movementImpulse = ReplicatedStorage:WaitForChild("MovementImpulse")

type Grenade = {
	part: BasePart,
	shooter: Player,
	position: Vector3,
	velocity: Vector3,
	explodeAt: number,
	rayParams: RaycastParams,
	profile: ClassKitConstants.GrenadeProfile,
	stuck: boolean,
}

local grenades: { Grenade } = {}
local lastThrow: { [Player]: number } = {}
local lastMelee: { [Player]: number } = {}

local function isFiniteVector(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < 1e6
		and math.abs(value.Y) < 1e6
		and math.abs(value.Z) < 1e6
end

local function setGrenadeAmmo(player: Player, amount: number)
	local maxGrenades = player:GetAttribute("MaxGrenades")
	if typeof(maxGrenades) ~= "number" then
		maxGrenades = Constants.MAX_GRENADES
	end
	player:SetAttribute("Grenades", math.clamp(amount, 0, maxGrenades))
end

local function refillGrenades(player: Player)
	local maxGrenades = player:GetAttribute("MaxGrenades")
	setGrenadeAmmo(player, typeof(maxGrenades) == "number" and maxGrenades or Constants.MAX_GRENADES)
end

local function showExplosion(position: Vector3, profile: ClassKitConstants.GrenadeProfile)
	local sphere = Instance.new("Part")
	sphere.Name = "GrenadeExplosion"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.one
	sphere.Position = position
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanTouch = false
	sphere.CanQuery = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = profile.color
	sphere.Transparency = 0.15
	sphere.Parent = workspace
	TweenService:Create(sphere, TweenInfo.new(0.16), {
		Size = Vector3.one * profile.radius * 2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(sphere, 0.2)
end

local function hasExplosionLineOfSight(position: Vector3, targetCharacter: Model, targetRoot: BasePart): boolean
	local offset = targetRoot.Position - position
	if offset.Magnitude <= 0.1 then
		return true
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { targetCharacter }
	return workspace:Raycast(position + offset.Unit * 0.05, offset - offset.Unit * 0.1, rayParams) == nil
end

local function explodeGrenade(grenade: Grenade)
	local position = grenade.position
	local profile = grenade.profile
	for _, targetPlayer in Players:GetPlayers() do
		local character = targetPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local offset = root.Position - position
			local distance = offset.Magnitude
			if distance <= profile.radius and hasExplosionLineOfSight(position, character, root) then
				local ratio = math.clamp(distance / profile.radius, 0, 1)
				local damage = profile.maxDamage + (profile.minDamage - profile.maxDamage) * ratio
				if CombatService.Damage(grenade.shooter, humanoid, damage, profile.name) then
					if profile.causesFlagFumble and targetPlayer ~= grenade.shooter then
						CTFSignals.RequestFlagFumble(targetPlayer)
					end
					local direction = distance > 0.05 and offset.Unit or Vector3.yAxis
					local strength = 1 - ratio
					local impulse = direction * profile.knockbackSpeed * strength
						+ Vector3.yAxis * profile.knockbackUpSpeed * strength
					if impulse.Magnitude > Constants.GRENADE_MAX_IMPULSE then
						impulse = impulse.Unit * Constants.GRENADE_MAX_IMPULSE
					end
					root.AssemblyLinearVelocity += impulse
					movementImpulse:FireClient(targetPlayer, impulse)
				end
			end
		end
	end

	showExplosion(position, profile)
	BaseService.DamageExplosion(
		grenade.shooter,
		position,
		profile.radius,
		profile.maxDamage,
		profile.minDamage,
		nil
	)
	grenade.part:Destroy()
end

local function spawnGrenade(
	player: Player,
	root: BasePart,
	direction: Vector3,
	profile: ClassKitConstants.GrenadeProfile
)
	local unitDirection = direction.Unit
	local origin = root.Position + Vector3.yAxis * 1.2 + unitDirection * 2

	local part = Instance.new("Part")
	part.Name = "ThrownGrenade"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * 0.75
	part.Position = origin
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Metal
	part.Color = profile.color
	part.Parent = workspace

	local attachment0 = Instance.new("Attachment")
	attachment0.Position = Vector3.new(0, 0.25, 0)
	attachment0.Parent = part
	local attachment1 = Instance.new("Attachment")
	attachment1.Position = Vector3.new(0, -0.25, 0)
	attachment1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Color = ColorSequence.new(profile.color:Lerp(Color3.new(1, 1, 1), 0.35), profile.color)
	trail.Lifetime = 0.18
	trail.LightEmission = 0.8
	trail.Parent = part

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { player.Character, part }

	table.insert(grenades, {
		part = part,
		shooter = player,
		position = origin,
		velocity = unitDirection * profile.throwSpeed
			+ root.AssemblyLinearVelocity * Constants.GRENADE_VELOCITY_INHERITANCE,
		explodeAt = os.clock() + profile.fuseTime,
		rayParams = rayParams,
		profile = profile,
		stuck = false,
	})
end

throwEvent.OnServerEvent:Connect(function(player: Player, direction: any)
	if not isFiniteVector(direction) or direction.Magnitude < 0.5 then
		return
	end
	local silencedUntil = player:GetAttribute("AbilitySilencedUntil")
	if typeof(silencedUntil) == "number" and silencedUntil > workspace:GetServerTimeNow() then return end

	local now = os.clock()
	if now - (lastThrow[player] or 0) < Constants.GRENADE_THROW_COOLDOWN then
		return
	end
	local ammo = player:GetAttribute("Grenades")
	if typeof(ammo) ~= "number" or ammo < 1 then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end

	lastThrow[player] = now
	setGrenadeAmmo(player, ammo - 1)
	local profile = ClassKitConstants.Get(player:GetAttribute("Loadout")).grenade
	spawnGrenade(player, root, direction, profile)
end)

local function findMeleeTarget(attacker: Player, origin: Vector3, direction: Vector3): Player?
	local bestTarget: Player? = nil
	local bestDistance = math.huge
	for _, target in Players:GetPlayers() do
		if target ~= attacker and target.Team ~= attacker.Team then
			local character = target.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				local offset = root.Position - origin
				local distance = offset.Magnitude
				if distance <= Constants.MELEE_RANGE
					and distance < bestDistance
					and distance > 0.05
					and direction:Dot(offset.Unit) >= Constants.MELEE_CONE_DOT then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { attacker.Character }
					local result = workspace:Raycast(origin, offset, params)
					if result and result.Instance:IsDescendantOf(character) then
						bestTarget = target
						bestDistance = distance
					end
				end
			end
		end
	end
	return bestTarget
end

meleeEvent.OnServerEvent:Connect(function(player: Player, direction: any)
	if not isFiniteVector(direction) or direction.Magnitude < 0.5 then
		return
	end
	local silencedUntil = player:GetAttribute("AbilitySilencedUntil")
	if typeof(silencedUntil) == "number" and silencedUntil > workspace:GetServerTimeNow() then return end

	local now = os.clock()
	if now - (lastMelee[player] or 0) < Constants.MELEE_COOLDOWN then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end

	local aimDirection = direction.Unit
	local horizontalAim = Vector3.new(aimDirection.X, 0, aimDirection.Z)
	if horizontalAim.Magnitude > 0.05 and horizontalAim.Unit:Dot(root.CFrame.LookVector) < 0.35 then
		return
	end
	lastMelee[player] = now

	local target = findMeleeTarget(player, root.Position + Vector3.yAxis * 1.5, aimDirection)
	if not target then
		return
	end
	local targetHumanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if targetHumanoid and CombatService.Damage(player, targetHumanoid, Constants.MELEE_DAMAGE, "Melee") then
		CTFSignals.RequestFlagFumble(target)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.05)
	for index = #grenades, 1, -1 do
		local grenade = grenades[index]
		if not grenade.part.Parent or grenade.shooter.Parent ~= Players then
			if grenade.part.Parent then
				grenade.part:Destroy()
			end
			table.remove(grenades, index)
		elseif os.clock() >= grenade.explodeAt then
			explodeGrenade(grenade)
			table.remove(grenades, index)
		elseif grenade.stuck then
			continue
		else
			local acceleration = Vector3.new(0, -Constants.GRENADE_GRAVITY, 0)
			local step = grenade.velocity * dt + acceleration * (0.5 * dt * dt)
			local result = workspace:Raycast(grenade.position, step, grenade.rayParams)
			grenade.velocity += acceleration * dt
			if result and grenade.profile.explodeOnImpact then
				grenade.position = result.Position
				explodeGrenade(grenade)
				table.remove(grenades, index)
			elseif result and grenade.profile.stickOnImpact then
				grenade.position = result.Position + result.Normal * 0.08
				grenade.velocity = Vector3.zero
				grenade.stuck = true
			elseif result then
				grenade.position = result.Position + result.Normal * 0.08
				local normalVelocity = result.Normal * grenade.velocity:Dot(result.Normal)
				local tangentVelocity = grenade.velocity - normalVelocity
				grenade.velocity = tangentVelocity * Constants.GRENADE_TANGENTIAL_FRICTION
					- normalVelocity * Constants.GRENADE_BOUNCE
				if grenade.velocity.Magnitude < 2 then
					grenade.velocity = Vector3.zero
				end
			else
				grenade.position += step
			end
			if grenade.part.Parent then
				grenade.part.Position = grenade.position
			end
		end
	end
end)

local function setupPlayer(player: Player)
	refillGrenades(player)
	player.CharacterAdded:Connect(function()
		refillGrenades(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

MatchSignals.RoundStarted:Connect(function()
	for _, player in Players:GetPlayers() do
		refillGrenades(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastThrow[player] = nil
	lastMelee[player] = nil
end)
