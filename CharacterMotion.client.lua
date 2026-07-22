-- Procedural third-person locomotion for the faction bodies.
-- This only changes Motor6D.Transform locally; gameplay physics, hitboxes and
-- server movement remain untouched.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LoadoutConstants = require(ReplicatedStorage.Modules.LoadoutConstants)

local tracks = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local MOTOR_ALIASES = {
	root = { "RootJoint" },
	waist = { "Waist" },
	neck = { "Neck" },
	leftShoulder = { "LeftShoulder", "Left Shoulder" },
	rightShoulder = { "RightShoulder", "Right Shoulder" },
	leftHip = { "LeftHip", "Left Hip" },
	rightHip = { "RightHip", "Right Hip" },
	leftKnee = { "LeftKnee" },
	rightKnee = { "RightKnee" },
	leftAnkle = { "LeftAnkle" },
	rightAnkle = { "RightAnkle" },
}

local function findMotor(model: Model, aliases: { string }): Motor6D?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and table.find(aliases, descendant.Name) then
			return descendant
		end
	end
	return nil
end

local function armorWeight(model: Model): string
	local presentation = model:FindFirstChild("CTFCharacterPresentation")
	local armor = presentation and presentation:GetAttribute("ArmorClass")
	if typeof(armor) == "string" then return armor end
	local loadout = model:GetAttribute("Loadout")
	local definition = typeof(loadout) == "string" and LoadoutConstants.LOADOUTS[loadout] or nil
	return definition and definition.armor or "MEDIUM"
end

local function newTrack(model: Model, root: BasePart, humanoid: Humanoid)
	local motors = {}
	local pose = {}
	for key, aliases in MOTOR_ALIASES do
		local motor = findMotor(model, aliases)
		motors[key] = motor
		pose[key] = CFrame.identity
	end
	local track = {
		model = model,
		root = root,
		humanoid = humanoid,
		motors = motors,
		pose = pose,
		phase = math.random() * math.pi * 2,
		landing = 0,
		wasGrounded = false,
		lastVertical = 0,
	}
	tracks[model] = track
	return track
end

local function getTrack(model: Model)
	local existing = tracks[model]
	if existing and existing.root.Parent and existing.humanoid.Parent then return existing end
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid then
		return newTrack(model, root, humanoid)
	end
	return nil
end

local function grounded(track): boolean
	rayParams.FilterDescendantsInstances = { track.model }
	return workspace:Raycast(track.root.Position, Vector3.new(0, -4.2, 0), rayParams) ~= nil
end

local function movementFlags(track, onGround: boolean, speed: number): (boolean, boolean)
	local model = track.model
	local owner = Players:GetPlayerFromCharacter(model)
	local skiing = model:GetAttribute("IsSkiing") == true
	local jetpacking = model:GetAttribute("IsJetpacking") == true
	if owner then
		skiing = skiing or owner:GetAttribute("IsSkiing") == true
		jetpacking = jetpacking or owner:GetAttribute("IsJetpacking") == true
	end
	-- Remote client attributes may arrive late; fast grounded motion still gets
	-- the characteristic low ski stance.
	if not skiing and onGround and speed > 44 then skiing = true end
	return skiing, jetpacking
end

local function apply(track, key: string, target: CFrame, alpha: number)
	local motor = track.motors[key]
	if not motor then return end
	local current = track.pose[key] or CFrame.identity
	current = current:Lerp(target, alpha)
	track.pose[key] = current
	motor.Transform = current
end

local function animate(track, dt: number)
	local model = track.model
	local root = track.root
	local humanoid = track.humanoid
	if not model.Parent or humanoid.Health <= 0 then return end

	local velocity = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = horizontal.Magnitude
	local localVelocity = root.CFrame:VectorToObjectSpace(velocity)
	local onGround = grounded(track)
	local skiing, jetpacking = movementFlags(track, onGround, speed)
	local weight = armorWeight(model)
	local heavy = weight == "HEAVY"
	local light = weight == "LIGHT"
	local cadence = if heavy then 0.78 elseif light then 1.12 else 0.94
	local amplitude = if heavy then 0.72 elseif light then 1.08 else 0.9

	if onGround and not track.wasGrounded and track.lastVertical < -18 then
		track.landing = math.clamp((-track.lastVertical - 14) / 50, 0.2, 1)
	end
	track.landing = math.max(0, track.landing - dt * 3.6)
	track.wasGrounded = onGround
	track.lastVertical = velocity.Y

	local moving = speed > 2.5
	local running = onGround and moving and not skiing and not jetpacking
	local phaseRate = (4.8 + math.min(speed, 42) * 0.19) * cadence
	if running then track.phase += dt * phaseRate end
	local cycle = math.sin(track.phase)
	local doubleCycle = math.sin(track.phase * 2)
	local strafe = math.clamp(localVelocity.X / math.max(speed, 1), -1, 1)
	local forward = math.clamp(-localVelocity.Z / math.max(speed, 1), -1, 1)
	local speedAlpha = math.clamp(speed / 70, 0, 1)
	local response = 1 - math.exp(-dt * (if heavy then 8 else 12))

	local rootPose = CFrame.identity
	local waistPose = CFrame.identity
	local neckPose = CFrame.identity
	local leftShoulder = CFrame.identity
	local rightShoulder = CFrame.identity
	local leftHip = CFrame.identity
	local rightHip = CFrame.identity
	local leftKnee = CFrame.identity
	local rightKnee = CFrame.identity
	local leftAnkle = CFrame.identity
	local rightAnkle = CFrame.identity

	if jetpacking then
		local flightPitch = math.rad(-10 - 13 * speedAlpha * math.max(forward, 0))
		local bank = math.rad(-strafe * 15)
		rootPose = CFrame.new(0, -0.08, 0) * CFrame.Angles(flightPitch, 0, bank)
		waistPose = CFrame.Angles(math.rad(-6), math.rad(strafe * 4), math.rad(-strafe * 5))
		neckPose = CFrame.Angles(math.rad(10), 0, math.rad(strafe * 6))
		leftShoulder = CFrame.Angles(math.rad(-34), 0, math.rad(-18))
		rightShoulder = CFrame.Angles(math.rad(-42), 0, math.rad(10))
		leftHip = CFrame.Angles(math.rad(18), 0, math.rad(-5))
		rightHip = CFrame.Angles(math.rad(27), 0, math.rad(5))
		leftKnee = CFrame.Angles(math.rad(22), 0, 0)
		rightKnee = CFrame.Angles(math.rad(34), 0, 0)
	elseif skiing then
		local bank = math.rad(-strafe * (10 + 12 * speedAlpha))
		local carve = math.sin(track.phase * 0.45) * math.rad(2.5) * speedAlpha
		rootPose = CFrame.new(0, -0.42 - speedAlpha * 0.18, 0.12) * CFrame.Angles(math.rad(-12 - speedAlpha * 9), carve, bank)
		waistPose = CFrame.Angles(math.rad(-8), math.rad(strafe * 5), math.rad(-strafe * 7))
		neckPose = CFrame.Angles(math.rad(15 + speedAlpha * 5), 0, math.rad(strafe * 9))
		leftShoulder = CFrame.Angles(math.rad(24), math.rad(-8), math.rad(-12))
		rightShoulder = CFrame.Angles(math.rad(-28), math.rad(7), math.rad(8))
		leftHip = CFrame.Angles(math.rad(-31), 0, math.rad(-4))
		rightHip = CFrame.Angles(math.rad(-35), 0, math.rad(4))
		leftKnee = CFrame.Angles(math.rad(58), 0, 0)
		rightKnee = CFrame.Angles(math.rad(64), 0, 0)
		leftAnkle = CFrame.Angles(math.rad(-20), 0, 0)
		rightAnkle = CFrame.Angles(math.rad(-20), 0, 0)
	elseif running then
		local swing = cycle * math.rad(31) * amplitude
		local bob = math.abs(doubleCycle) * 0.07 * amplitude
		rootPose = CFrame.new(0, -bob, 0) * CFrame.Angles(math.rad(-4 - speedAlpha * 7), 0, math.rad(-strafe * 5))
		waistPose = CFrame.Angles(math.rad(2), cycle * math.rad(4) * amplitude, math.rad(-strafe * 4))
		neckPose = CFrame.Angles(math.rad(3 + speedAlpha * 3), -cycle * math.rad(3), math.rad(strafe * 4))
		leftShoulder = CFrame.Angles(-swing * 0.82, 0, math.rad(-4))
		-- The weapon arm stays disciplined while the off hand counter-swings.
		rightShoulder = CFrame.Angles(swing * 0.34 - math.rad(13), math.rad(4), math.rad(6))
		leftHip = CFrame.Angles(swing, 0, 0)
		rightHip = CFrame.Angles(-swing, 0, 0)
		leftKnee = CFrame.Angles(math.max(0, -cycle) * math.rad(42) * amplitude, 0, 0)
		rightKnee = CFrame.Angles(math.max(0, cycle) * math.rad(42) * amplitude, 0, 0)
	elseif not onGround then
		local falling = math.clamp(-velocity.Y / 70, -1, 1)
		rootPose = CFrame.Angles(math.rad(-forward * 8 + falling * 5), 0, math.rad(-strafe * 8))
		waistPose = CFrame.Angles(math.rad(-3), 0, math.rad(-strafe * 5))
		neckPose = CFrame.Angles(math.rad(5), 0, math.rad(strafe * 6))
		leftShoulder = CFrame.Angles(math.rad(-8), 0, math.rad(-18))
		rightShoulder = CFrame.Angles(math.rad(-20), 0, math.rad(13))
		leftHip = CFrame.Angles(math.rad(12), 0, math.rad(-5))
		rightHip = CFrame.Angles(math.rad(-9), 0, math.rad(5))
		leftKnee = CFrame.Angles(math.rad(25), 0, 0)
		rightKnee = CFrame.Angles(math.rad(42), 0, 0)
	else
		local breath = math.sin(os.clock() * 1.65 + track.phase) * 0.018
		rootPose = CFrame.new(0, breath - track.landing * 0.34, 0) * CFrame.Angles(math.rad(-track.landing * 10), 0, 0)
		waistPose = CFrame.Angles(math.rad(1.5 + breath * 16), 0, 0)
		neckPose = CFrame.Angles(math.rad(-1.5 - breath * 12), 0, 0)
		leftShoulder = CFrame.Angles(math.rad(3 + breath * 20), 0, math.rad(-4))
		rightShoulder = CFrame.Angles(math.rad(-12 - breath * 14), math.rad(4), math.rad(6))
		leftHip = CFrame.Angles(math.rad(-track.landing * 18), 0, 0)
		rightHip = CFrame.Angles(math.rad(-track.landing * 18), 0, 0)
		leftKnee = CFrame.Angles(math.rad(track.landing * 34), 0, 0)
		rightKnee = CFrame.Angles(math.rad(track.landing * 34), 0, 0)
	end

	apply(track, "root", rootPose, response)
	apply(track, "waist", waistPose, response)
	apply(track, "neck", neckPose, response)
	apply(track, "leftShoulder", leftShoulder, response)
	apply(track, "rightShoulder", rightShoulder, response)
	apply(track, "leftHip", leftHip, response)
	apply(track, "rightHip", rightHip, response)
	apply(track, "leftKnee", leftKnee, response)
	apply(track, "rightKnee", rightKnee, response)
	apply(track, "leftAnkle", leftAnkle, response)
	apply(track, "rightAnkle", rightAnkle, response)
end

RunService:BindToRenderStep("CTFCharacterMotion", Enum.RenderPriority.Character.Value + 2, function(dt)
	local active = {}
	for _, candidate in Players:GetPlayers() do
		if candidate.Character then table.insert(active, candidate.Character) end
	end
	local botFolder = workspace:FindFirstChild("CTFBots")
	if botFolder then
		for _, candidate in botFolder:GetChildren() do
			if candidate:IsA("Model") then table.insert(active, candidate) end
		end
	end

	local seen = {}
	for _, model in active do
		seen[model] = true
		local track = getTrack(model)
		if track then animate(track, math.min(dt, 1 / 20)) end
	end
	for model, track in tracks do
		if not seen[model] or not model.Parent then
			for key, motor in track.motors do
				if motor and motor.Parent then motor.Transform = CFrame.identity end
				track.pose[key] = CFrame.identity
			end
			tracks[model] = nil
		end
	end
end)
