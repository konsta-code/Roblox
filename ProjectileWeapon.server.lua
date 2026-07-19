-- ProjectileWeapon.server.lua
-- Ablageort: ServerScriptService
--
-- Server-autoritative Projectile-Simulation. Client schickt nur "ich feuere,
-- hier Ursprung + Richtung" - der Server simuliert das Geschoss selbst und
-- entscheidet über Treffer/Schaden. Damage-Cheating auf Client-Seite ist
-- damit wirkungslos.
--
-- v2: Self-Knockback nutzt jetzt auch Extra-Z (aus T:A Datamine ExtraZMomentum)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Modules.WeaponConstants)

local fireEvent = ReplicatedStorage:WaitForChild("FireWeapon")

local lastFireTime: { [Player]: number } = {}

local function getDamageForDistance(distance: number): number
	if distance <= 0.5 then
		return Constants.DIRECT_HIT_DAMAGE
	end
	if distance >= Constants.SPLASH_RADIUS then
		return 0
	end
	local falloff = 1 - (distance / Constants.SPLASH_RADIUS)
	return Constants.SPLASH_MIN_DAMAGE + (Constants.SPLASH_MAX_DAMAGE - Constants.SPLASH_MIN_DAMAGE) * falloff
end

local function applyExplosion(position: Vector3, shooter: Player)
	-- Alle Spieler im Splash-Radius finden und Schaden zuweisen
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local distance = (root.Position - position).Magnitude
			local damage = getDamageForDistance(distance)
			if damage > 0 then
				hum:TakeDamage(damage)
			end
		end
	end

	-- Self-Knockback ("Disc-Jump") für den Schützen
	-- Basiert auf Original: MomentumTransfer + InstigatorMultiplier + ExtraZMomentum
	if Constants.SELF_KNOCKBACK_ENABLED then
		local shooterChar = shooter.Character
		local shooterRoot = shooterChar and shooterChar:FindFirstChild("HumanoidRootPart")
		if shooterRoot then
			local distance = (shooterRoot.Position - position).Magnitude
			local minDist = Constants.SELF_KNOCKBACK_MIN_DISTANCE or 3
			local maxDist = Constants.SELF_KNOCKBACK_MAX_DISTANCE or 20

			if distance < maxDist then
				-- Falloff: zu nah oder zu weit = weniger Boost
				local falloff = 1
				if distance < minDist then
					falloff = distance / minDist
				else
					falloff = 1 - ((distance - minDist) / (maxDist - minDist))
				end
				falloff = math.clamp(falloff, 0, 1)

				local direction = shooterRoot.Position - position
				if direction.Magnitude < 0.1 then
					direction = Vector3.yAxis
				else
					direction = direction.Unit
				end

				local force = Constants.SELF_KNOCKBACK_FORCE * falloff
				local upForce = (Constants.SELF_KNOCKBACK_UP_FORCE or 45) * falloff

				-- Horizontaler Anteil + extra vertikaler Boost (wie ExtraZMomentum im Original)
				local knockback = direction * force + Vector3.new(0, upForce, 0)
				shooterRoot.AssemblyLinearVelocity += knockback
			end
		end
	end
end

local function simulateProjectile(shooter: Player, origin: Vector3, direction: Vector3)
	local projectile = Instance.new("Part")
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(Constants.PROJECTILE_RADIUS, Constants.PROJECTILE_RADIUS, Constants.PROJECTILE_RADIUS) * 2
	projectile.Position = origin
	projectile.Anchored = true
	projectile.CanCollide = false
	projectile.Material = Enum.Material.Neon
	projectile.Parent = workspace

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { shooter.Character }

	-- Inheritance: Projektil übernimmt einen Teil der Spieler-Velocity (Original 0.5)
	local inheritance = Constants.PROJECTILE_INHERITANCE or 0.5
	local shooterRoot = shooter.Character and shooter.Character:FindFirstChild("HumanoidRootPart")
	local inheritedVel = Vector3.zero
	if shooterRoot then
		inheritedVel = shooterRoot.AssemblyLinearVelocity * inheritance
	end

	local velocity = direction.Unit * Constants.PROJECTILE_SPEED + inheritedVel
	local startTime = os.clock()
	local currentPos = origin

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if os.clock() - startTime > Constants.PROJECTILE_LIFETIME then
			connection:Disconnect()
			projectile:Destroy()
			return
		end

		local step = velocity * dt
		local result = workspace:Raycast(currentPos, step, rayParams)

		if result then
			connection:Disconnect()
			applyExplosion(result.Position, shooter)
			projectile:Destroy()
			return
		end

		currentPos += step
		projectile.Position = currentPos
	end)
end

fireEvent.OnServerEvent:Connect(function(player: Player, origin: Vector3, direction: Vector3)
	local now = os.clock()
	local last = lastFireTime[player] or 0
	if now - last < Constants.FIRE_COOLDOWN then
		return
	end
	lastFireTime[player] = now

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - origin).Magnitude > 10 then
		return
	end

	simulateProjectile(player, origin, direction)
end)

Players.PlayerRemoving:Connect(function(player)
	lastFireTime[player] = nil
end)
