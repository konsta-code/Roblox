-- SkiController.client.lua
-- Movement v4 - kritische Fixes

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
	skiHeld = false,
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
	State.jetpackEnergy = Constants.JETPACK_MAX_ENERGY
	State.wasGrounded = false
end

setupCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(setupCharacter)

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
		Input.skiHeld = true
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		Input.jetpackHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then Input.skiHeld = false end
	if input.KeyCode == Enum.KeyCode.LeftShift then Input.jetpackHeld = false end
end)

local function checkGround(): (boolean, Vector3)
	local result = workspace:Raycast(
		rootPart.Position, Vector3.new(0, -Constants.GROUND_CHECK_DISTANCE, 0), groundParams)
	if result then return true, result.Normal end
	return false, Vector3.yAxis
end

local function applySkiPhysics(dt: number)
	local isSkiing = Input.skiHeld
	State.isSkiing = isSkiing

	local slopeDir = Vector3.new(-State.groundNormal.X, 0, -State.groundNormal.Z)
	if slopeDir.Magnitude > 0.01 then slopeDir = slopeDir.Unit end
	local slopeForce = slopeDir * Constants.GRAVITY * (Constants.SKI_SLOPE_FORCE_MULT or 1.8)

	local horizontalVel = Vector3.new(State.velocity.X, 0, State.velocity.Z)

	if isSkiing then
		local inputForce = Input.moveVector * (Constants.WALK_SPEED * 0.32)
		horizontalVel = horizontalVel:Lerp(Vector3.zero, math.clamp(Constants.SKI_GROUND_FRICTION * dt, 0, 1))
		horizontalVel += slopeForce * dt + inputForce * dt
	else
		local desiredVel = Input.moveVector * Constants.WALK_SPEED
		horizontalVel = horizontalVel:Lerp(desiredVel, math.clamp(Constants.WALK_GROUND_FRICTION * dt, 0, 1))
		horizontalVel += slopeForce * dt * 0.25
	end

	if horizontalVel.Magnitude > Constants.MAX_SKI_SPEED then
		horizontalVel = horizontalVel.Unit * Constants.MAX_SKI_SPEED
	end

	local newY = State.velocity.Y > 0 and State.velocity.Y or 0
	State.velocity = Vector3.new(horizontalVel.X, newY, horizontalVel.Z)
end

local function updateFacing()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local look = cam.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.001 then return end
	rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + flatLook)
end

local function applyJetpack(dt: number)
	local wantsThrust = Input.jetpackHeld and State.jetpackEnergy > 0
	if wantsThrust then
		local horizontalSpeed = Vector3.new(State.velocity.X, 0, State.velocity.Z).Magnitude
		local thrustMult = horizontalSpeed > (Constants.JET_SOFT_CAP_SPEED or 85) and (Constants.JET_OVER_CAP_MULT or 0.18) or 1
		local forwardBoost = Input.moveVector * Constants.JETPACK_THRUST_FORCE * (Constants.JETPACK_FORWARD_MULT or 0.65) * thrustMult * dt
		local upThrust = Constants.JETPACK_THRUST_FORCE * thrustMult * dt
		State.velocity += Vector3.new(0, upThrust, 0) + forwardBoost
		State.jetpackEnergy = math.max(0, State.jetpackEnergy - Constants.JETPACK_DRAIN_RATE * dt)
		State.lastThrustTime = os.clock()
	elseif os.clock() - State.lastThrustTime > Constants.JETPACK_REGEN_DELAY then
		State.jetpackEnergy = math.min(Constants.JETPACK_MAX_ENERGY, State.jetpackEnergy + Constants.JETPACK_REGEN_RATE * dt)
	end
	PlayerHudState.SetJetpackEnergy(State.jetpackEnergy)
end

RunService.Heartbeat:Connect(function(dt)
	if not character.Parent or not rootPart.Parent then return end

	updateMoveVector()
	local grounded, normal = checkGround()
	State.isGrounded = grounded
	State.groundNormal = normal

	-- Disc-Jump Impulse vom Server uebernehmen
	local actualVel = rootPart.AssemblyLinearVelocity
	local diff = actualVel - State.velocity
	if diff.Magnitude > 8 then
		State.velocity = State.velocity:Lerp(actualVel, Constants.EXTERNAL_IMPULSE_BLEND or 0.85)
	end

	if grounded and not State.wasGrounded then
		local fallSpeed = math.abs(math.min(State.velocity.Y, 0))
		if fallSpeed > 8 then
			local horizontal = Vector3.new(State.velocity.X, 0, State.velocity.Z)
			local transfer = fallSpeed * (Constants.LANDING_VELOCITY_TRANSFER or 0.95)
			local boostDir = horizontal.Magnitude > 2 and horizontal.Unit or (Input.moveVector.Magnitude > 0 and Input.moveVector or Vector3.new(0, 0, -1))
			State.velocity = Vector3.new(State.velocity.X + boostDir.X * transfer * 0.75, 0, State.velocity.Z + boostDir.Z * transfer * 0.75)
		end
	end
	State.wasGrounded = grounded

	if grounded and not Input.jetpackHeld then
		applySkiPhysics(dt)
	else
		State.velocity += Vector3.new(0, -Constants.GRAVITY * dt, 0)
		local airControl = Input.moveVector * (Constants.WALK_SPEED * 0.55) * dt
		if Input.jetpackHeld then airControl *= 1.4 end
		State.velocity += airControl
	end

	applyJetpack(dt)
	updateFacing()
	rootPart.AssemblyLinearVelocity = State.velocity
end)
