-- SkiController.client.lua
-- Tribes-style skiing and jetpacking adapted from public T:A defaults.

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
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
	hoverHeight = 3, -- Ziel-Abstand RootPart-Mitte -> Boden, ersetzt HipHeight
}

local function getMaxJetpackEnergy(): number
	local value = player:GetAttribute("MaxEnergy")
	return if typeof(value) == "number" then math.clamp(value, 50, 150) else Constants.JETPACK_MAX_ENERGY
end

local function getMovementScale(attributeName: string, minimum: number): number
	local value = player:GetAttribute(attributeName)
	local baseScale = if typeof(value) == "number" then value else 1
	local abilityValue = player:GetAttribute("AbilityMoveScale")
	local abilityScale = if typeof(abilityValue) == "number" then abilityValue else 1
	return math.clamp(baseScale * abilityScale, minimum, 1.5)
end

local Input = {
	moveVector = Vector3.zero,
	skiHeld = false,
	jetpackHeld = false,
	controllerMove = Vector2.zero,
	actionSkiHeld = false,
	actionJetpackHeld = false,
}

local function clearMovementInput()
	Input.moveVector = Vector3.zero
	Input.skiHeld = false
	Input.jetpackHeld = false
	Input.controllerMove = Vector2.zero
	Input.actionSkiHeld = false
	Input.actionJetpackHeld = false
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

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

-- === Debug-Overlay (F3 schaltet ein/aus, standardmäßig aus) ===
-- Zeigt Speed / Grounded / Ski / Jetpack / Energie. Zum dauerhaften Entfernen
-- einfach diesen Block, den F3-Handler und den Debug-Update im Heartbeat löschen.
local debugEnabled = false
local debugLabel: TextLabel? = nil

local function ensureDebugLabel(): TextLabel
	if debugLabel then
		return debugLabel
	end
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MovementDebug"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromOffset(240, 104)
	lbl.Position = UDim2.fromOffset(16, 130)
	lbl.BackgroundTransparency = 0.35
	lbl.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	lbl.BorderSizePixel = 0
	lbl.TextColor3 = Color3.fromRGB(120, 255, 160)
	lbl.Font = Enum.Font.Code
	lbl.TextSize = 14
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	lbl.Text = ""
	lbl.Parent = screenGui
	debugLabel = lbl
	return lbl
end

local function setupCharacter(newCharacter: Model)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	local boundHumanoid = humanoid
	local boundRoot = rootPart

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

	-- Schwebehöhe aus der Avatar-Geometrie: PlatformStand deaktiviert die
	-- HipHeight-Beinfeder, die den RootPart sonst so hoch hält, dass die Füße
	-- genau auf dem Boden stehen. Denselben Abstand halten wir unten selbst
	-- (RootPart-Mitte = HipHeight + halbe RootPart-Höhe über dem Boden), sonst
	-- sinken die Füße in den Boden ein.
	State.hoverHeight = humanoid.HipHeight + rootPart.Size.Y / 2

	groundParams.FilterDescendantsInstances = { character }

	State.velocity = rootPart.AssemblyLinearVelocity
	State.lastAirVelocity = State.velocity
	State.isGrounded = false
	State.wasGrounded = false
	State.isSkiing = false
	State.jetpackEnergy = getMaxJetpackEnergy()
	State.jetpackAlpha = 0
	State.jetpackStartTime = 0
	State.wasJetpacking = false
	player:SetAttribute("IsSkiing", false)
	player:SetAttribute("IsJetpacking", false)
	PlayerHudState.SetJetpackEnergy(State.jetpackEnergy)

	boundHumanoid.Died:Connect(function()
		if humanoid ~= boundHumanoid then return end
		clearMovementInput()
		State.velocity = Vector3.zero
		State.lastAirVelocity = Vector3.zero
		State.isGrounded = false
		State.wasGrounded = false
		State.isSkiing = false
		State.wasJetpacking = false
		State.jetpackAlpha = 0
		player:SetAttribute("IsSkiing", false)
		player:SetAttribute("IsJetpacking", false)
		if boundRoot.Parent then
			boundRoot.AssemblyLinearVelocity = Vector3.zero
			boundRoot.AssemblyAngularVelocity = Vector3.zero
		end
	end)

	print(string.format("[Movement] %s loaded", Constants.BUILD_ID))
end

setupCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(setupCharacter)

local function updateMoveVector()
	if not humanoid or humanoid.Health <= 0 then
		clearMovementInput()
		return
	end
	if player:GetAttribute("LoadoutMenuOpen") then
		Input.moveVector = Vector3.zero
		Input.skiHeld = false
		Input.jetpackHeld = false
		return
	end
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

	local controllerMagnitude = Input.controllerMove.Magnitude
	if controllerMagnitude > 0 then
		move += forward * -Input.controllerMove.Y + right * Input.controllerMove.X
	end
	if humanoid and humanoid.MoveDirection.Magnitude > move.Magnitude then
		move = horizontal(humanoid.MoveDirection)
	end
	Input.moveVector = if move.Magnitude > 1 then move.Unit else move

	-- Kontinuierliche Abfrage der Halte-Eingaben (statt Event-Flags):
	-- Space = Ski, Shift ODER rechte Maustaste = Jetpack.
	Input.skiHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or Input.actionSkiHeld
	Input.jetpackHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		or Input.actionJetpackHeld
end

local function updateHoldAction(field: "actionSkiHeld" | "actionJetpackHeld", inputState: Enum.UserInputState)
	if not humanoid or humanoid.Health <= 0 then
		clearMovementInput()
		return Enum.ContextActionResult.Sink
	end
	if inputState == Enum.UserInputState.Begin then
		Input[field] = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		Input[field] = false
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("TribesSki", function(_name, state)
	return updateHoldAction("actionSkiHeld", state)
end, true, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("TribesSki", "SKI")
ContextActionService:SetPosition("TribesSki", UDim2.new(1, -190, 1, -120))

ContextActionService:BindAction("TribesJetpack", function(_name, state)
	return updateHoldAction("actionJetpackHeld", state)
end, true, Enum.KeyCode.ButtonA)
ContextActionService:SetTitle("TribesJetpack", "JET")
ContextActionService:SetPosition("TribesJetpack", UDim2.new(1, -95, 1, -120))

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick1 then
		local raw = Vector2.new(input.Position.X, input.Position.Y)
		local magnitude = raw.Magnitude
		if magnitude <= 0.12 then
			Input.controllerMove = Vector2.zero
		else
			Input.controllerMove = raw.Unit * math.clamp((magnitude - 0.12) / 0.88, 0, 1)
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F3 then
		debugEnabled = not debugEnabled
		if debugLabel then
			debugLabel.Visible = debugEnabled
		end
	end
end)

local function checkGround(): (boolean, Vector3, number)
	local result = workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -Constants.GROUND_CHECK_DISTANCE, 0),
		groundParams
	)
	if result and result.Normal.Y >= Constants.MAX_WALKABLE_NORMAL_Y then
		return true, result.Normal, result.Distance
	end
	return false, Vector3.yAxis, math.huge
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
		local desired = Input.moveVector * Constants.WALK_SPEED * getMovementScale("WalkSpeedScale", 0.5)
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
			local control = getSkiControl(speed) * getMovementScale("SkiControlScale", 0.5)
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
		State.velocity += assist
			* Constants.AIR_CONTROL_ACCELERATION
			* getMovementScale("AirControlScale", 0.5)
			* Constants.SKI_ACCEL_PCT
			* dt
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
	State.velocity += Input.moveVector
		* Constants.AIR_CONTROL_ACCELERATION
		* getMovementScale("AirControlScale", 0.5)
		* dt

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

	State.velocity += desiredDirection
		* (thrustAcceleration + initialBoost)
		* getMovementScale("JetThrustScale", 0.5)
		* ramp
		* dt
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
			getMaxJetpackEnergy(),
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
	if not humanoid or humanoid.Health <= 0 then return end
	if typeof(impulse) ~= "Vector3" then return end
	if impulse.X ~= impulse.X or impulse.Y ~= impulse.Y or impulse.Z ~= impulse.Z then return end
	local safeImpulse = clampMagnitude(impulse, Constants.MAX_EXTERNAL_IMPULSE)
		* getMovementScale("ImpulseScale", 0.4)
	State.velocity += safeImpulse
	State.lastAirVelocity = State.velocity
	if rootPart and rootPart.Parent then
		rootPart.AssemblyLinearVelocity = State.velocity
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if not character or not character.Parent or not rootPart or not rootPart.Parent then return end
	if not humanoid or humanoid.Health <= 0 then
		clearMovementInput()
		return
	end
	dt = math.min(dt, 1 / 20)

	updateMoveVector()
	local grounded, normal, groundDist = checkGround()

	-- Kamm-/Schanzen-Absprung: fahren wir skiend über eine konvexe Kuppe
	-- (Bergkamm, Rampen-Lippe), trägt uns das Momentum von der Fläche WEG -
	-- die Geschwindigkeit zeigt dann entlang der +Normalen (velocity·normal
	-- positiv). In dem Fall NICHT zurück an die Fläche snappen (was die
	-- Aufwärts-Geschwindigkeit in Abwärts umbiegen würde -> man klebt am Boden
	-- und rutscht nur runter), sondern das Momentum in einen echten Sprung
	-- übergehen lassen. Beim Landen zeigt die Velocity in die Fläche hinein
	-- (negativ), dann greift das hier nicht und man skiet normal weiter.
	if grounded and State.velocity:Dot(normal) > Constants.SKI_LAUNCH_THRESHOLD then
		grounded = false
	end

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

	-- Beim Jetpack am Boden keine Abwärts-Geschwindigkeit in den Boden
	-- kommandieren: während der Schub-Rampe (0 -> voll über JETPACK_RAMP_UP_TIME)
	-- ist die Gravitation kurz stärker als der Schub, das drückte die Füße in
	-- den Boden bis der Schub greift. Y auf >= 0 klemmen, bis man abhebt.
	if grounded and isJetpacking and State.velocity.Y < 0 then
		State.velocity = Vector3.new(State.velocity.X, 0, State.velocity.Z)
	end

	-- Schwebehöhe halten (ersetzt die per PlatformStand abgeschaltete HipHeight):
	-- RootPart vertikal nachführen, damit die Füße auf der Fläche stehen statt
	-- einzusinken. Beim Jetpack nur ANHEBEN (max(0, ...)), nie nach unten ziehen,
	-- sonst würde die Korrektur den Aufstieg bremsen.
	if grounded then
		local correction = State.hoverHeight - groundDist
		if isJetpacking then
			correction = math.max(0, correction)
		end
		rootPart.CFrame += Vector3.new(0, correction, 0)
	end

	State.wasGrounded = grounded
	player:SetAttribute("IsSkiing", State.isSkiing and grounded)
	player:SetAttribute("IsJetpacking", isJetpacking)
	updateFacing()
	rootPart.AssemblyLinearVelocity = State.velocity

	if debugEnabled then
		local lbl = ensureDebugLabel()
		lbl.Visible = true
		lbl.Text = string.format(
			"[%s]\nspeed:    %.1f\ngrounded: %s\nski:      %s\njetpack:  %s\nenergy:   %.0f",
			Constants.BUILD_ID,
			State.velocity.Magnitude,
			tostring(grounded),
			tostring(State.isSkiing),
			tostring(isJetpacking),
			State.jetpackEnergy
		)
	end
end)
