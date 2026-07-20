-- SkiController.client.lua
-- Tribes-style skiing and jetpacking adapted from public T:A defaults.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Modules.MovementConstants)
local PlayerHudState = require(ReplicatedStorage.Modules.PlayerHudState)

local player = Players.LocalPlayer
local movementImpulse = ReplicatedStorage:WaitForChild("MovementImpulse")

local character: Model
local humanoid: Humanoid
local rootPart: BasePart

local State = {
	velocity = Vector3.zero,
	lastAirVelocity = Vector3.zero,
	isGrounded = false,
	wasGrounded = false,
	groundNormal = Vector3.yAxis,
	isSkiing = false,
	jetpackEnergy = Constants.JETPACK_MAX_ENERGY,
	jetpackAlpha = 0,
	jetpackStartTime = 0,
	wasJetpacking = false,
}

local Input = {
	moveVector = Vector3.zero,
	skiHeld = false,
	jetpackHeld = false,
}

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local debugAccumulator = 0 -- TEMPORÄR: Drossel für die MoveDBG-Diagnosezeile

local function horizontal(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function projectOntoPlane(vector: Vector3, normal: Vector3): Vector3
	return vector - normal * vector:Dot(normal)
end

local function clampMagnitude(vector: Vector3, maximum: number): Vector3
	local magnitude = vector.Magnitude
	if magnitude > maximum and magnitude > 0 then
		return vector * (maximum / magnitude)
	end
	return vector
end

local function setupCharacter(newCharacter: Model)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 0
	-- PlatformStand: der Humanoid gibt seine eigene Boden-Physik komplett ab
	-- (kein aktives Abbremsen bei WalkSpeed 0, keine HipHeight-Beinfeder die
	-- gegen den Jetpack zieht). Ohne das frisst der Humanoid die per
	-- AssemblyLinearVelocity gesetzte Geschwindigkeit jeden Frame wieder auf -
	-- Ursache für "kaum laufen" + "Jetpack hebt nicht ab". Orientierung hält
	-- updateFacing() jeden Frame aufrecht, der Character kippt also nicht.
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	groundParams.FilterDescendantsInstances = { character }

	State.velocity = rootPart.AssemblyLinearVelocity
	State.lastAirVelocity = State.velocity
	State.isGrounded = false
	State.wasGrounded = false
	State.isSkiing = false
	State.jetpackEnergy = Constants.JETPACK_MAX_ENERGY
	State.jetpackAlpha = 0
	State.jetpackStartTime = 0
	State.wasJetpacking = false
	PlayerHudState.SetJetpackEnergy(State.jetpackEnergy)

	print(string.format("[Movement] %s loaded", Constants.BUILD_ID))
end

setupCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(setupCharacter)

local function updateMoveVector()
	local camera = workspace.CurrentCamera
	if not camera then
		Input.moveVector = Vector3.zero
		return
	end

	local forward = horizontal(camera.CFrame.LookVector)
	local right = horizontal(camera.CFrame.RightVector)
	if forward.Magnitude > 0 then forward = forward.Unit end
	if right.Magnitude > 0 then right = right.Unit end

	local move = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += forward end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= forward end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
	Input.moveVector = move.Magnitude > 0 and move.Unit or Vector3.zero
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Space then
		Input.skiHeld = true
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		Input.jetpackHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then
		Input.skiHeld = false
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		Input.jetpackHeld = false
	end
end)

local function checkGround(): (boolean, Vector3)
	local result = workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -Constants.GROUND_CHECK_DISTANCE, 0),
		groundParams
	)
	if result and result.Normal.Y >= Constants.MAX_WALKABLE_NORMAL_Y then
		return true, result.Normal
	end
	return false, Vector3.yAxis
end

local function getSkiControl(speed: number): number
	local difference = speed - Constants.SKI_PEAK_CONTROL_SPEED
	local exponent = -(difference * difference) / (2 * Constants.SKI_CONTROL_SIGMA_SQUARED)
	return Constants.SKI_MAX_CONTROL_PCT * math.exp(exponent)
end

local function applySkiing(dt: number, justLanded: boolean)
	local normal = State.groundNormal
	State.isSkiing = Input.skiHeld

	if not State.isSkiing then
		local desired = Input.moveVector * Constants.WALK_SPEED
		local alpha = 1 - math.exp(-Constants.WALK_RESPONSE * dt)
		local walkingVelocity = horizontal(State.velocity):Lerp(desired, alpha)
		State.velocity = Vector3.new(walkingVelocity.X, 0, walkingVelocity.Z)
		return
	end

	-- T:A projects the incoming velocity onto the hit surface on landing.
	-- It does not invent an arbitrary forward boost.
	if justLanded then
		State.velocity = projectOntoPlane(State.lastAirVelocity, normal)
	else
		State.velocity = projectOntoPlane(State.velocity, normal)
	end

	State.velocity *= math.exp(-Constants.SKI_FRICTION * dt)

	local gravity = Vector3.new(0, -Constants.GRAVITY, 0)
	local slopeAcceleration = projectOntoPlane(gravity, normal)
	State.velocity += slopeAcceleration * Constants.SKI_SLOPE_GRAVITY_BOOST * dt

	local speed = State.velocity.Magnitude
	if speed > 0.5 and Input.moveVector.Magnitude > 0 then
		local desiredOnSurface = projectOntoPlane(Input.moveVector, normal)
		if desiredOnSurface.Magnitude > 0.001 then
			desiredOnSurface = desiredOnSurface.Unit * speed
			local control = getSkiControl(speed)
			local steerAlpha = 1 - math.exp(-Constants.SKI_STEER_RESPONSE * control * dt)
			local steered = State.velocity:Lerp(desiredOnSurface, steerAlpha)
			if steered.Magnitude > 0.001 then
				State.velocity = steered.Unit * speed
			end
		end
	end

	-- Acceleration-cap behavior: input can assist at lower speed, but never
	-- creates unlimited speed on flat terrain.
	if speed < Constants.SKI_ACCEL_CAP_SPEED and Input.moveVector.Magnitude > 0 then
		local assist = projectOntoPlane(Input.moveVector, normal)
		State.velocity += assist * Constants.AIR_CONTROL_ACCELERATION * Constants.SKI_ACCEL_PCT * dt
	end

	State.velocity = clampMagnitude(State.velocity, Constants.SKI_TERMINAL_SPEED)
end

local function smoothstep(value: number): number
	local x = math.clamp(value, 0, 1)
	return x * x * (3 - 2 * x)
end

local function applyAirAndJetpack(dt: number, isJetpacking: boolean)
	State.isSkiing = false
	State.velocity += Vector3.new(0, -Constants.GRAVITY * dt, 0)
	State.velocity += Input.moveVector * Constants.AIR_CONTROL_ACCELERATION * dt

	if not isJetpacking then return end

	local ramp = State.jetpackAlpha
	local upward = Vector3.yAxis
	local desiredDirection = upward + Input.moveVector * Constants.JETPACK_FORWARD_PCT
	if desiredDirection.Magnitude > 0 then desiredDirection = desiredDirection.Unit end

	local speedAlongThrust = math.max(0, State.velocity:Dot(desiredDirection))
	local capRatio = speedAlongThrust / Constants.JETPACK_THRUST_SPEED
	local capBlend = smoothstep(capRatio)
	local fullThrust = Constants.GRAVITY + Constants.JETPACK_LIFT_ACCELERATION
	local thrustAtCap = Constants.GRAVITY + Constants.JETPACK_ACCEL_AT_THRUST_SPEED
	local thrustAcceleration = fullThrust + (thrustAtCap - fullThrust) * capBlend

	local elapsed = os.clock() - State.jetpackStartTime
	local initRemaining = 1 - math.clamp(elapsed / Constants.JETPACK_INIT_DURATION, 0, 1)
	local currentSpeed = State.velocity.Magnitude
	local speedThrottle = 1 - math.clamp(
		currentSpeed / Constants.JETPACK_MAX_BOOST_GROUND_SPEED,
		0,
		1
	)
	local initialBoost = Constants.JETPACK_INIT_BOOST_ACCELERATION * initRemaining * speedThrottle

	State.velocity += desiredDirection * (thrustAcceleration + initialBoost) * ramp * dt
	State.velocity = clampMagnitude(State.velocity, Constants.JETPACK_TERMINAL_SPEED)
end

local function updateJetpack(dt: number): boolean
	local canStart = State.jetpackEnergy >= Constants.JETPACK_RESTART_ENERGY
	local hasEnergy = State.jetpackEnergy > 0
	local isJetpacking = Input.jetpackHeld and hasEnergy and (State.wasJetpacking or canStart)

	if isJetpacking and not State.wasJetpacking then
		State.jetpackEnergy = math.max(0, State.jetpackEnergy - Constants.JETPACK_INITIAL_COST)
		State.jetpackStartTime = os.clock()
	end

	if isJetpacking then
		State.jetpackAlpha = math.min(1, State.jetpackAlpha + dt / Constants.JETPACK_RAMP_UP_TIME)
		State.jetpackEnergy = math.max(0, State.jetpackEnergy - Constants.JETPACK_DRAIN_RATE * dt)
	else
		State.jetpackAlpha = math.max(0, State.jetpackAlpha - dt / Constants.JETPACK_RAMP_DOWN_TIME)
		State.jetpackEnergy = math.min(
			Constants.JETPACK_MAX_ENERGY,
			State.jetpackEnergy + Constants.JETPACK_REGEN_RATE * dt
		)
	end

	State.wasJetpacking = isJetpacking and State.jetpackEnergy > 0
	PlayerHudState.SetJetpackEnergy(State.jetpackEnergy)
	return State.wasJetpacking
end

local function updateFacing()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local look = horizontal(camera.CFrame.LookVector)
	if look.Magnitude < 0.001 then return end
	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + look.Unit)
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

movementImpulse.OnClientEvent:Connect(function(impulse)
	if typeof(impulse) ~= "Vector3" then return end
	if impulse.X ~= impulse.X or impulse.Y ~= impulse.Y or impulse.Z ~= impulse.Z then return end
	local safeImpulse = clampMagnitude(impulse, Constants.MAX_EXTERNAL_IMPULSE)
	State.velocity += safeImpulse
	State.lastAirVelocity = State.velocity
	if rootPart and rootPart.Parent then
		rootPart.AssemblyLinearVelocity = State.velocity
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if not character or not character.Parent or not rootPart or not rootPart.Parent then return end
	dt = math.min(dt, 1 / 20)

	updateMoveVector()
	local grounded, normal = checkGround()
	local justLanded = grounded and not State.wasGrounded
	State.isGrounded = grounded
	State.groundNormal = normal

	-- Adopt engine/server changes such as collisions and knockback, while
	-- preserving the final airborne velocity for the landing projection.
	-- Schwelle bewusst hoch (8): nur echte externe Eingriffe (Wand-Kollision)
	-- übernehmen, NICHT das kleinbetragige Physik-Rauschen jeden Frame - sonst
	-- adoptiert der Controller seine eigene abgebremste Velocity und bremst
	-- sich selbst aus. Disc-Jumps kommen ohnehin explizit über MovementImpulse.
	local actualVelocity = rootPart.AssemblyLinearVelocity
	if not justLanded and (actualVelocity - State.velocity).Magnitude > 8 then
		State.velocity = actualVelocity
	end
	local isJetpacking = updateJetpack(dt)
	if grounded and not isJetpacking then
		applySkiing(dt, justLanded)
	else
		applyAirAndJetpack(dt, isJetpacking)
	end
	if not grounded then
		State.lastAirVelocity = State.velocity
	end

	State.wasGrounded = grounded
	updateFacing()
	rootPart.AssemblyLinearVelocity = State.velocity

	-- TEMPORÄR: Diagnose einmal pro Sekunde. Wenn Bewegung/Jetpack noch klemmt,
	-- verrät diese Zeile in der Ausgabe sofort die Ursache. Danach entfernen.
	debugAccumulator += dt
	if debugAccumulator >= 1 then
		debugAccumulator = 0
		print(string.format(
			"[MoveDBG] grounded=%s jet=%s speed=%.1f energy=%.0f",
			tostring(grounded), tostring(isJetpacking), State.velocity.Magnitude, State.jetpackEnergy
		))
	end
end)
