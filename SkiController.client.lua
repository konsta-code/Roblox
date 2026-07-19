-- SkiController.client.lua
-- Ablageort: StarterPlayerScripts/SkiController (LocalScript)
-- Movement v2 - näher am originalen Tribes Ascend Feeling

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.MovementConstants)
local PlayerHudState = require(ReplicatedStorage.Modules.PlayerHudState)

local player = Players.LocalPlayer

local character: Model
local humanoid: Humanoid
local rootPart: BasePart

local State = {
	velocity = Vector3.zero,
	isGrounded = false,
	groundNormal = Vector3.yAxis,
	isSkiing = false,
	jetpackEnergy = Constants.JETPACK_MAX_ENERGY,
	lastThrustTime = 0,
	wasGrounded = false,
}

local Input = {
	moveVector = Vector3.zero,
	jumpHeld = false,
	jetpackHeld = false,
}

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function setupCharacter(newCharacter: Model)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	groundParams.FilterDescendantsInstances = { character }

	State.velocity = Vector3.zero
	State.isGrounded = false
	State.isSkiing = false
	State.jetpackEnergy = Constants.JETPACK_MAX_ENERGY
	State.wasGrounded = false
end

setupCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(setupCharacter)

-- === Input ===

local function updateMoveVector()
	local cam = workspace.CurrentCamera
	if not cam then return end

	local forward = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	local right = cam.CFrame.RightVector * Vector3.new(1, 0, 1)
	local moveVector = Vector3.zero

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector += forward end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector -= forward end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector += right end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector -= right end

	Input.moveVector = moveVector.Magnitude > 0 and moveVector.Unit or Vector3.zero
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Space then
		Input.jumpHeld = true
		if State.isGrounded and not State.isSkiing then
			State.velocity = Vector3.new(State.velocity.X, Constants.JUMP_POWER, State.velocity.Z)
		end
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		Input.jetpackHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then Input.jumpHeld = false end
	if input.KeyCode == Enum.KeyCode.LeftShift then Input.jetpackHeld = false end
end)

-- === Ground Detection ===

local function checkGround(): (boolean, Vector3)
	local result = workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -Constants.GROUND_CHECK_DISTANCE, 0),
		groundParams
	)
	if result then
		return true, result.Normal
	end
	return false, Vector3.yAxis
end

-- === Ski-Physik ===

local function applySkiPhysics(dt: number, justLanded: boolean)
	local normal = State.groundNormal
	local slopeAngle = math.deg(math.acos(math.clamp(normal:Dot(Vector3.yAxis), -1, 1)))
	local isSkiing = Input.jumpHeld
	State.isSkiing = isSkiing

	-- Projiziert die Gravitation auf die Bodenebene. Die Hangbeschleunigung
	-- wächst dadurch natürlich mit der Neigung.
	local gravity = Vector3.new(0, -Constants.GRAVITY, 0)
	local slopeAcceleration = gravity - normal * gravity:Dot(normal)
	if slopeAngle < Constants.SKI_MIN_SLOPE_ANGLE then
		slopeAcceleration = Vector3.zero
	else
		slopeAcceleration *= Constants.SKI_SLOPE_FORCE_MULT
	end

	local horizontalVel = Vector3.new(State.velocity.X, 0, State.velocity.Z)

	-- Behält beim Aufsetzen die Geschwindigkeit entlang der Oberfläche.
	-- Dadurch wird ein Sturz auf einen Hang zu kontrollierbarem Momentum.
	if isSkiing and justLanded and State.velocity.Y < 0 then
		local surfaceVelocity = State.velocity - normal * State.velocity:Dot(normal)
		local landingHorizontal = Vector3.new(surfaceVelocity.X, 0, surfaceVelocity.Z)
		horizontalVel = horizontalVel:Lerp(landingHorizontal, Constants.LANDING_VELOCITY_TRANSFER)
	end

	local slopeHorizontal = Vector3.new(slopeAcceleration.X, 0, slopeAcceleration.Z)
	if isSkiing then
		local inputAcceleration = Input.moveVector * (Constants.WALK_SPEED * 0.38)
		horizontalVel = horizontalVel:Lerp(Vector3.zero, math.clamp(Constants.SKI_GROUND_FRICTION * dt, 0, 1))
		horizontalVel += (slopeHorizontal + inputAcceleration) * dt
	else
		local desiredVel = Input.moveVector * Constants.WALK_SPEED
		horizontalVel = horizontalVel:Lerp(desiredVel, math.clamp(Constants.WALK_GROUND_FRICTION * dt, 0, 1))
	end

	if horizontalVel.Magnitude > Constants.MAX_SKI_SPEED then
		horizontalVel = horizontalVel.Unit * Constants.MAX_SKI_SPEED
	end

	local newY = State.velocity.Y > 0 and State.velocity.Y or 0
	State.velocity = Vector3.new(horizontalVel.X, newY, horizontalVel.Z)
end

-- === Blickrichtung ===

local function updateFacing()
	local cam = workspace.CurrentCamera
	if not cam then return end

	local look = cam.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.001 then return end

	rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + flatLook)
end

-- === Jetpack ===

local function applyJetpack(dt: number)
	local wantsThrust = Input.jetpackHeld and State.jetpackEnergy > 0

	if wantsThrust then
		State.velocity += Vector3.new(0, Constants.JETPACK_THRUST_FORCE * dt, 0)
		State.jetpackEnergy = math.max(0, State.jetpackEnergy - Constants.JETPACK_DRAIN_RATE * dt)
		State.lastThrustTime = os.clock()
	elseif os.clock() - State.lastThrustTime > Constants.JETPACK_REGEN_DELAY then
		State.jetpackEnergy = math.min(Constants.JETPACK_MAX_ENERGY, State.jetpackEnergy + Constants.JETPACK_REGEN_RATE * dt)
	end

	PlayerHudState.SetJetpackEnergy(State.jetpackEnergy)
end

-- === Main Loop ===

RunService.Heartbeat:Connect(function(dt)
	if not character.Parent or not rootPart.Parent then return end

	updateMoveVector()
	local grounded, normal = checkGround()
	State.isGrounded = grounded
	State.groundNormal = normal

	local justLanded = grounded and not State.wasGrounded
	State.wasGrounded = grounded

	if grounded and not Input.jetpackHeld then
		applySkiPhysics(dt, justLanded)
	else
		State.isSkiing = false
		State.velocity += Vector3.new(0, -Constants.GRAVITY * dt, 0)

		-- Eine kontrollierte horizontale Luftbeschleunigung statt zweier
		-- addierter Forward-Boosts.
		local isJetpacking = Input.jetpackHeld and State.jetpackEnergy > 0
		local airAcceleration = isJetpacking
			and Constants.JETPACK_AIR_CONTROL_ACCELERATION
			or Constants.AIR_CONTROL_ACCELERATION
		State.velocity += Input.moveVector * airAcceleration * dt
	end

	applyJetpack(dt)
	updateFacing()

	rootPart.AssemblyLinearVelocity = State.velocity
end)
