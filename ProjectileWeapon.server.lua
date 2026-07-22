-- ProjectileWeapon.server.lua
-- Server-authoritative Spinfusor simulation. The client supplies only an aim
-- direction; origin, velocity inheritance, collision, damage and knockback
-- are all calculated by the server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Modules.WeaponConstants)
local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local CombatService = require(script.Parent.CombatService)
local BaseService = require(script.Parent.BaseService)
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
	profile: ClassKitConstants.DiscProfile,
	targetRoot: BasePart?,
}

local projectiles: { Projectile } = {}
local lastFireTime: { [Player]: number } = {}

local function isFiniteVector(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < 1e6 and math.abs(value.Y) < 1e6 and math.abs(value.Z) < 1e6
end

local function getSplashDamage(profile: ClassKitConstants.DiscProfile, distance: number): number
	if distance > profile.splashRadius then return 0 end
	local ratio = distance / profile.splashRadius
	if ratio <= Constants.SPLASH_FULL_DAMAGE_PCT then
		return profile.splashMaxDamage
	end
	if ratio >= Constants.SPLASH_MIN_DAMAGE_PCT then
		return profile.splashMinDamage
	end
	local alpha = (ratio - Constants.SPLASH_FULL_DAMAGE_PCT)
		/ (Constants.SPLASH_MIN_DAMAGE_PCT - Constants.SPLASH_FULL_DAMAGE_PCT)
	return profile.splashMaxDamage
		+ (profile.splashMinDamage - profile.splashMaxDamage) * alpha
end

local function hasExplosionLineOfSight(
	position: Vector3,
	targetCharacter: Model,
	targetRoot: BasePart,
	shooterCharacter: Model?
): boolean
	local offset = targetRoot.Position - position
	if offset.Magnitude <= 0.1 then return true end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { targetCharacter }
	if shooterCharacter then table.insert(excluded, shooterCharacter) end
	rayParams.FilterDescendantsInstances = excluded

	local direction = offset.Unit
	local origin = position + direction * 0.02
	local distance = math.max(0, offset.Magnitude - 0.04)
	return workspace:Raycast(origin, direction * distance, rayParams) == nil
end

local function showExplosion(position: Vector3, profile: ClassKitConstants.DiscProfile)
	local sphere = Instance.new("Part")
	sphere.Name = "SpinfusorExplosion"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.one * 1.5
	sphere.Position = position
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = profile.projectileColor
	sphere.Transparency = 0.2
	sphere.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = profile.projectileColor
	light.Brightness = 4
	light.Range = math.max(18, profile.splashRadius * 1.3)
	light.Shadows = true
	light.Parent = sphere

	local flash = Instance.new("ParticleEmitter")
	flash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	flash.Color = ColorSequence.new(profile.projectileColor, Color3.new(1, 1, 1))
	flash.LightEmission = 1
	flash.Lifetime = NumberRange.new(0.16, 0.35)
	flash.Speed = NumberRange.new(12, 28)
	flash.SpreadAngle = Vector2.new(180, 180)
	flash.Rate = 0
	flash.Parent = sphere
	flash:Emit(math.clamp(math.floor(profile.splashRadius * 1.5), 12, 38))

	local vapor = Instance.new("ParticleEmitter")
	vapor.Texture = "rbxasset://textures/particles/smoke_main.dds"
	vapor.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, profile.projectileColor:Lerp(Color3.new(1, 1, 1), 0.55)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 48, 64)),
	})
	vapor.LightEmission = 0.35
	vapor.Lifetime = NumberRange.new(0.45, 0.9)
	vapor.Speed = NumberRange.new(4, 13)
	vapor.Drag = 4
	vapor.SpreadAngle = Vector2.new(180, 180)
	vapor.Rate = 0
	vapor.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.35, 2.2),
		NumberSequenceKeypoint.new(1, 4.8),
	})
	vapor.Transparency = NumberSequence.new(0.18, 1)
	vapor.Parent = sphere
	vapor:Emit(math.clamp(math.floor(profile.splashRadius * 0.75), 8, 24))

	-- Three staggered plasma shells give the disc an energy-wave silhouette at
	-- long range, while remaining non-queryable and extremely short-lived.
	for waveIndex = 1, 3 do
		local wave = Instance.new("Part")
		wave.Name = "PlasmaWave"
		wave.Shape = Enum.PartType.Ball
		wave.Size = Vector3.one * (0.8 + waveIndex * 0.35)
		wave.Position = position
		wave.Anchored = true
		wave.CanCollide = false
		wave.CanQuery = false
		wave.CanTouch = false
		wave.Material = Enum.Material.ForceField
		wave.Color = profile.projectileColor:Lerp(Color3.new(1, 1, 1), 0.18 * waveIndex)
		wave.Transparency = 0.28 + waveIndex * 0.1
		wave.Parent = workspace
		local delayTime = (waveIndex - 1) * 0.035
		task.delay(delayTime, function()
			if not wave.Parent then return end
			TweenService:Create(wave, TweenInfo.new(0.24 + waveIndex * 0.055, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = Vector3.one * profile.splashRadius * (1.25 + waveIndex * 0.28),
				Transparency = 1,
			}):Play()
		end)
		Debris:AddItem(wave, 0.55)
	end

	local impactSound = Instance.new("Sound")
	impactSound.SoundId = "rbxasset://sounds/impact_explosion_03.mp3"
	impactSound.Volume = 0.5
	impactSound.PlaybackSpeed = math.clamp(1.25 - profile.splashRadius / 70, 0.72, 1.05)
	impactSound.RollOffMinDistance = 10
	impactSound.RollOffMaxDistance = 220
	impactSound.Parent = sphere
	impactSound:Play()

	TweenService:Create(sphere, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * profile.splashRadius * 2,
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(0.18), { Brightness = 0, Range = 0 }):Play()
	Debris:AddItem(sphere, 0.65)
end

local function applyExplosion(
	position: Vector3,
	shooter: Player,
	directHumanoid: Humanoid?,
	profile: ClassKitConstants.DiscProfile
)
	for _, targetPlayer in Players:GetPlayers() do
		local targetCharacter = targetPlayer.Character
		local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
		local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
		local canDamage = targetPlayer == shooter or targetPlayer.Team ~= shooter.Team
		if canDamage and targetCharacter and targetRoot and targetRoot:IsA("BasePart")
			and targetHumanoid and targetHumanoid.Health > 0
			and targetHumanoid ~= directHumanoid then
			local damage = getSplashDamage(profile, (targetRoot.Position - position).Magnitude)
			if damage > 0 and hasExplosionLineOfSight(position, targetCharacter, targetRoot, shooter.Character) then
				CombatService.Damage(shooter, targetHumanoid, damage, profile.name)
			end
		end
	end
	for _, targetCharacter in CollectionService:GetTagged("CTFBot") do
		if targetCharacter:IsA("Model") and targetCharacter:GetAttribute("BotTeam") ~= (shooter.Team and shooter.Team.Name) then
			local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
			local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
			if targetRoot and targetRoot:IsA("BasePart") and targetHumanoid and targetHumanoid.Health > 0
				and targetHumanoid ~= directHumanoid then
				local damage = getSplashDamage(profile, (targetRoot.Position - position).Magnitude)
				if damage > 0 and hasExplosionLineOfSight(position, targetCharacter, targetRoot, shooter.Character) then
					CombatService.Damage(shooter, targetHumanoid, damage, profile.name)
				end
			end
		end
	end

	local shooterCharacter = shooter.Character
	local shooterRoot = shooterCharacter and shooterCharacter:FindFirstChild("HumanoidRootPart")
	if shooterRoot and shooterRoot:IsA("BasePart") then
		local offset = shooterRoot.Position - position
		local damage = getSplashDamage(profile, offset.Magnitude)
		if damage > 0 then
			local direction = offset.Magnitude > 0.05 and offset.Unit or Vector3.yAxis
			local strength = damage / profile.splashMaxDamage
			local impulse = direction * Constants.SELF_KNOCKBACK_SPEED * profile.selfKnockbackScale * strength
				+ Vector3.yAxis * Constants.SELF_KNOCKBACK_UP_SPEED * profile.selfKnockbackScale * strength
			if impulse.Magnitude > Constants.MAX_EXTERNAL_IMPULSE then
				impulse = impulse.Unit * Constants.MAX_EXTERNAL_IMPULSE
			end
			shooterRoot.AssemblyLinearVelocity += impulse
			movementImpulse:FireClient(shooter, impulse)
		end
	end

	showExplosion(position, profile)
end

local function hitHumanoid(instance: Instance): Humanoid?
	local model = instance:FindFirstAncestorOfClass("Model")
	if not model then return nil end
	return model:FindFirstChildOfClass("Humanoid")
end

local function directHitAward(humanoid: Humanoid, profile: ClassKitConstants.DiscProfile): string?
	if not string.find(profile.name, "Spinfusor", 1, true) then
		return nil
	end
	local character = humanoid.Parent
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") or root.AssemblyLinearVelocity.Magnitude < 18 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	if workspace:Raycast(root.Position, Vector3.new(0, -8, 0), params) then
		return nil
	end
	return "BLUE PLATE SPECIAL"
end

local function findHomingTarget(
	shooter: Player,
	origin: Vector3,
	direction: Vector3,
	profile: ClassKitConstants.DiscProfile
): BasePart?
	local range = profile.homingRange or 0
	if range <= 0 or (profile.homingStrength or 0) <= 0 then
		return nil
	end

	local bestRoot: BasePart? = nil
	local bestScore = math.huge
	for _, targetPlayer in Players:GetPlayers() do
		if targetPlayer ~= shooter and targetPlayer.Team ~= shooter.Team then
			local targetCharacter = targetPlayer.Character
			local humanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
			local root = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
			if targetCharacter and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				local offset = root.Position - origin
				local distance = offset.Magnitude
				if distance <= range and distance > 0.1 and direction:Dot(offset.Unit) >= 0.55 then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { shooter.Character }
					local result = workspace:Raycast(origin, offset, params)
					if result and result.Instance:IsDescendantOf(targetCharacter) then
						local score = distance * (1.4 - direction:Dot(offset.Unit))
						if score < bestScore then
							bestScore = score
							bestRoot = root
						end
					end
				end
			end
		end
	end
	return bestRoot
end

local function spawnProjectile(
	shooter: Player,
	character: Model,
	root: BasePart,
	direction: Vector3,
	profile: ClassKitConstants.DiscProfile
)
	local unitDirection = direction.Unit
	local origin = root.Position + unitDirection * 2

	local part = Instance.new("Part")
	part.Name = "SpinfusorDisc"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * profile.projectileRadius * 2
	part.Position = origin
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = profile.projectileColor
	part.Parent = workspace

	local core = Instance.new("Part")
	core.Name = "DiscCore"
	core.Shape = Enum.PartType.Ball
	core.Size = part.Size * 0.48
	core.CFrame = part.CFrame
	core.Anchored = false
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Massless = true
	core.Material = Enum.Material.Neon
	core.Color = profile.projectileColor:Lerp(Color3.new(1, 1, 1), 0.72)
	core.Parent = part
	local coreWeld = Instance.new("WeldConstraint")
	coreWeld.Part0 = part
	coreWeld.Part1 = core
	coreWeld.Parent = core
	local projectileLight = Instance.new("PointLight")
	projectileLight.Color = profile.projectileColor
	projectileLight.Brightness = 2.4
	projectileLight.Range = math.clamp(profile.splashRadius * 0.55, 10, 22)
	projectileLight.Shadows = false
	projectileLight.Parent = part

	local trailTop = Instance.new("Attachment")
	trailTop.Position = Vector3.new(0, profile.projectileRadius * 0.45, 0)
	trailTop.Parent = part
	local trailBottom = Instance.new("Attachment")
	trailBottom.Position = Vector3.new(0, -profile.projectileRadius * 0.45, 0)
	trailBottom.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = trailTop
	trail.Attachment1 = trailBottom
	trail.Color = ColorSequence.new(profile.projectileColor:Lerp(Color3.new(1, 1, 1), 0.4), profile.projectileColor)
	trail.Lifetime = 0.16
	trail.LightEmission = 1
	trail.Parent = part

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character, part }

	table.insert(projectiles, {
		part = part,
		position = origin,
		velocity = unitDirection * profile.projectileSpeed
			+ root.AssemblyLinearVelocity * Constants.PROJECTILE_INHERITANCE,
		shooter = shooter,
		character = character,
		rayParams = rayParams,
		spawnTime = os.clock(),
		profile = profile,
		targetRoot = findHomingTarget(shooter, origin, unitDirection, profile),
	})
end

fireEvent.OnServerEvent:Connect(function(player: Player, direction: any)
	if not isFiniteVector(direction) or direction.Magnitude < 0.5 then return end
	local silencedUntil = player:GetAttribute("AbilitySilencedUntil")
	if typeof(silencedUntil) == "number" and silencedUntil > workspace:GetServerTimeNow() then return end
	-- Serverautoritative Waffenwahl (WeaponState.server): nur feuern, wenn der
	-- Spinfusor wirklich ausgerüstet ist - verhindert gleichzeitiges Feuern
	-- beider Waffen über gespoofte Remotes.
	if player:GetAttribute("EquippedWeapon") ~= "Spinfusor" then return end
	local profile = ClassKitConstants.Get(player:GetAttribute("Loadout")).disc

	local now = os.clock()
	if now - (lastFireTime[player] or 0) < profile.fireCooldown then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0
		or not root or not root:IsA("BasePart") then return end

	CombatService.BreakSpawnProtection(player)
	lastFireTime[player] = now
	local burstCount = math.clamp(math.floor(profile.burstCount or 1), 1, 6)
	local burstInterval = math.clamp(profile.burstInterval or 0, 0, 0.4)
	for shot = 1, burstCount do
		task.delay((shot - 1) * burstInterval, function()
			if player.Parent ~= Players or player.Character ~= character then
				return
			end
			local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
			if not currentHumanoid or currentHumanoid.Health <= 0 or not root.Parent then
				return
			end
			spawnProjectile(player, character, root, direction, profile)
		end)
	end
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
			local gravity = projectile.profile.gravity or 0
			if gravity > 0 then
				projectile.velocity += Vector3.new(0, -gravity * dt, 0)
			end
			local targetRoot = projectile.targetRoot
			if targetRoot and targetRoot.Parent and (projectile.profile.homingStrength or 0) > 0 then
				local offset = targetRoot.Position - projectile.position
				if offset.Magnitude > 0.1 then
					local targetVelocity = offset.Unit * math.max(projectile.profile.projectileSpeed, projectile.velocity.Magnitude)
					local homingAlpha = math.clamp((projectile.profile.homingStrength or 0) * dt, 0, 1)
					projectile.velocity = projectile.velocity:Lerp(targetVelocity, homingAlpha)
				end
			end
			local step = projectile.velocity * dt
			local result = workspace:Raycast(projectile.position, step, projectile.rayParams)
			if result then
				local directHumanoid = hitHumanoid(result.Instance)
				local hitBase = false
				local directCharacter = directHumanoid and directHumanoid.Parent
				local directPlayer = directHumanoid
					and Players:GetPlayerFromCharacter(directCharacter)
				local directBotTeam = directCharacter and directCharacter:GetAttribute("BotTeam")
				local canDamageDirect = if directPlayer
					then directPlayer == projectile.shooter or directPlayer.Team ~= projectile.shooter.Team
					else directBotTeam == nil or directBotTeam ~= (projectile.shooter.Team and projectile.shooter.Team.Name)
				if directHumanoid and directHumanoid.Health > 0 and canDamageDirect then
					local award = directHitAward(directHumanoid, projectile.profile)
					CombatService.Damage(
						projectile.shooter,
						directHumanoid,
						projectile.profile.directDamage,
						projectile.profile.name,
						award
					)
				else
					directHumanoid = nil
					hitBase = BaseService.DamageHit(projectile.shooter, result.Instance, projectile.profile.directDamage)
				end
				applyExplosion(result.Position, projectile.shooter, directHumanoid, projectile.profile)
				BaseService.DamageExplosion(
					projectile.shooter,
					result.Position,
					projectile.profile.splashRadius,
					projectile.profile.splashMaxDamage,
					projectile.profile.splashMinDamage,
					hitBase and result.Instance or nil
				)
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
