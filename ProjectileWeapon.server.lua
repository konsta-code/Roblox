-- ProjectileWeapon.server.lua
-- Server-authoritative Spinfusor simulation. The client supplies only an aim
-- direction; origin, velocity inheritance, collision, damage and knockback
-- are all calculated by the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Modules.WeaponConstants)
local fireEvent = ReplicatedStorage:WaitForChild("FireWeapon")
local movementImpulse = ReplicatedStorage:WaitForChild("MovementImpulse")

type Projectile = {
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	shooter: Player,
	character: Model,
	rayParams: RaycastParams,
	spawnTime: number,
}

local projectiles: { Projectile } = {}
local lastFireTime: { [Player]: number } = {}

local function isFiniteVector(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < 1e6 and math.abs(value.Y) < 1e6 and math.abs(value.Z) < 1e6
end

local function getSplashDamage(distance: number): number
	if distance > Constants.SPLASH_RADIUS then return 0 end
	local ratio = distance / Constants.SPLASH_RADIUS
	if ratio <= Constants.SPLASH_FULL_DAMAGE_PCT then
		return Constants.SPLASH_MAX_DAMAGE
	end
	if ratio >= Constants.SPLASH_MIN_DAMAGE_PCT then
		return Constants.SPLASH_MIN_DAMAGE
	end
	local alpha = (ratio - Constants.SPLASH_FULL_DAMAGE_PCT)
		/ (Constants.SPLASH_MIN_DAMAGE_PCT - Constants.SPLASH_FULL_DAMAGE_PCT)
	return Constants.SPLASH_MAX_DAMAGE
		+ (Constants.SPLASH_MIN_DAMAGE - Constants.SPLASH_MAX_DAMAGE) * alpha
end

local function showExplosion(position: Vector3)
	local sphere = Instance.new("Part")
	sphere.Name = "SpinfusorExplosion"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.one * 1.5
	sphere.Position = position
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = Color3.fromRGB(80, 190, 255)
	sphere.Transparency = 0.2
	sphere.Parent = workspace

	task.delay(0.12, function()
		if sphere.Parent then sphere:Destroy() end
	end)
end

local function applyExplosion(position: Vector3, shooter: Player, directHumanoid: Humanoid?)
	for _, targetPlayer in Players:GetPlayers() do
		local targetCharacter = targetPlayer.Character
		local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
		local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
		local canDamage = targetPlayer == shooter or targetPlayer.Team ~= shooter.Team
		if canDamage and targetRoot and targetRoot:IsA("BasePart")
			and targetHumanoid and targetHumanoid.Health > 0
			and targetHumanoid ~= directHumanoid then
			local damage = getSplashDamage((targetRoot.Position - position).Magnitude)
			if damage > 0 then targetHumanoid:TakeDamage(damage) end
		end
	end

	local shooterCharacter = shooter.Character
	local shooterRoot = shooterCharacter and shooterCharacter:FindFirstChild("HumanoidRootPart")
	if shooterRoot and shooterRoot:IsA("BasePart") then
		local offset = shooterRoot.Position - position
		local damage = getSplashDamage(offset.Magnitude)
		if damage > 0 then
			local direction = offset.Magnitude > 0.05 and offset.Unit or Vector3.yAxis
			local strength = damage / Constants.SPLASH_MAX_DAMAGE
			local impulse = direction * Constants.SELF_KNOCKBACK_SPEED * strength
				+ Vector3.yAxis * Constants.SELF_KNOCKBACK_UP_SPEED * strength
			if impulse.Magnitude > Constants.MAX_EXTERNAL_IMPULSE then
				impulse = impulse.Unit * Constants.MAX_EXTERNAL_IMPULSE
			end
			shooterRoot.AssemblyLinearVelocity += impulse
			movementImpulse:FireClient(shooter, impulse)
		end
	end

	showExplosion(position)
end

local function hitHumanoid(instance: Instance): Humanoid?
	local model = instance:FindFirstAncestorOfClass("Model")
	if not model then return nil end
	return model:FindFirstChildOfClass("Humanoid")
end

local function spawnProjectile(shooter: Player, character: Model, root: BasePart, direction: Vector3)
	local unitDirection = direction.Unit
	local origin = root.Position + unitDirection * 2

	local part = Instance.new("Part")
	part.Name = "SpinfusorDisc"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * Constants.PROJECTILE_RADIUS * 2
	part.Position = origin
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(65, 170, 255)
	part.Parent = workspace

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character, part }

	table.insert(projectiles, {
		part = part,
		position = origin,
		velocity = unitDirection * Constants.PROJECTILE_SPEED
			+ root.AssemblyLinearVelocity * Constants.PROJECTILE_INHERITANCE,
		shooter = shooter,
		character = character,
		rayParams = rayParams,
		spawnTime = os.clock(),
	})
end

fireEvent.OnServerEvent:Connect(function(player: Player, direction: any)
	if not isFiniteVector(direction) or direction.Magnitude < 0.5 then return end

	local now = os.clock()
	if now - (lastFireTime[player] or 0) < Constants.FIRE_COOLDOWN then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0
		or not root or not root:IsA("BasePart") then return end

	lastFireTime[player] = now
	spawnProjectile(player, character, root, direction)
end)

RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.1)
	for index = #projectiles, 1, -1 do
		local projectile = projectiles[index]
		local expired = os.clock() - projectile.spawnTime >= Constants.PROJECTILE_LIFETIME
		local invalid = not projectile.part.Parent or not projectile.shooter.Parent
		if expired or invalid then
			if projectile.part.Parent then projectile.part:Destroy() end
			table.remove(projectiles, index)
		else
			local step = projectile.velocity * dt
			local result = workspace:Raycast(projectile.position, step, projectile.rayParams)
			if result then
				local directHumanoid = hitHumanoid(result.Instance)
				local directPlayer = directHumanoid
					and Players:GetPlayerFromCharacter(directHumanoid.Parent)
				local canDamageDirect = not directPlayer
					or directPlayer == projectile.shooter
					or directPlayer.Team ~= projectile.shooter.Team
				if directHumanoid and directHumanoid.Health > 0 and canDamageDirect then
					directHumanoid:TakeDamage(Constants.DIRECT_HIT_DAMAGE)
				else
					directHumanoid = nil
				end
				applyExplosion(result.Position, projectile.shooter, directHumanoid)
				projectile.part:Destroy()
				table.remove(projectiles, index)
			else
				projectile.position += step
				projectile.part.Position = projectile.position
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastFireTime[player] = nil
end)

print(string.format("[Spinfusor] %s server loaded", Constants.BUILD_ID))
