-- Local-only movement VFX. This observes the controller state and never changes physics.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

local activeCharacter: Model? = nil
local jetEmitters: { ParticleEmitter } = {}
local skiEmitters: { ParticleEmitter } = {}
local landingEmitter: ParticleEmitter? = nil
local lastGrounded = false
local lastVerticalSpeed = 0

local function newEmitter(parent: Attachment, name: string): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
end

local function install(character: Model)
	activeCharacter = character
	table.clear(jetEmitters)
	table.clear(skiEmitters)
	landingEmitter = nil
	lastGrounded = false
	lastVerticalSpeed = 0

	local root = character:WaitForChild("HumanoidRootPart", 8)
	if not root or not root:IsA("BasePart") or character ~= activeCharacter then
		return
	end

	for index, side in { -1, 1 } do
		local jetPoint = Instance.new("Attachment")
		jetPoint.Name = "JetNozzle" .. index
		jetPoint.Position = Vector3.new(side * 0.62, 0.15, 0.62)
		jetPoint.Orientation = Vector3.new(0, 0, 180)
		jetPoint.Parent = root

		local flame = newEmitter(jetPoint, "JetFlame")
		flame.Texture = "rbxasset://textures/particles/fire_main.dds"
		flame.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(225, 250, 255)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(54, 194, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(39, 81, 255)),
		})
		flame.LightEmission = 1
		flame.Lifetime = NumberRange.new(0.12, 0.23)
		flame.Speed = NumberRange.new(18, 27)
		flame.SpreadAngle = Vector2.new(9, 9)
		flame.EmissionDirection = Enum.NormalId.Bottom
		flame.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.38),
			NumberSequenceKeypoint.new(0.45, 0.7),
			NumberSequenceKeypoint.new(1, 0.06),
		})
		flame.Transparency = NumberSequence.new(0.08, 1)
		table.insert(jetEmitters, flame)

		local skiPoint = Instance.new("Attachment")
		skiPoint.Name = "SkiContact" .. index
		skiPoint.Position = Vector3.new(side * 0.62, -2.45, 0.12)
		skiPoint.Parent = root

		local spray = newEmitter(skiPoint, "SkiSpray")
		spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
		spray.Color = ColorSequence.new(Color3.fromRGB(215, 235, 247))
		spray.LightEmission = 0.18
		spray.Lifetime = NumberRange.new(0.24, 0.5)
		spray.Speed = NumberRange.new(4, 10)
		spray.Acceleration = Vector3.new(0, -4, 0)
		spray.Drag = 3
		spray.SpreadAngle = Vector2.new(35, 35)
		spray.EmissionDirection = Enum.NormalId.Back
		spray.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.28),
			NumberSequenceKeypoint.new(0.55, 0.7),
			NumberSequenceKeypoint.new(1, 1.05),
		})
		spray.Transparency = NumberSequence.new(0.25, 1)
		table.insert(skiEmitters, spray)
	end

	local impactPoint = Instance.new("Attachment")
	impactPoint.Name = "LandingImpact"
	impactPoint.Position = Vector3.new(0, -2.35, 0)
	impactPoint.Parent = root
	local impact = newEmitter(impactPoint, "LandingBurst")
	impact.Texture = "rbxasset://textures/particles/smoke_main.dds"
	impact.Color = ColorSequence.new(Color3.fromRGB(224, 240, 250))
	impact.Lifetime = NumberRange.new(0.3, 0.7)
	impact.Speed = NumberRange.new(8, 16)
	impact.SpreadAngle = Vector2.new(180, 20)
	impact.Size = NumberSequence.new(0.45, 1.4)
	impact.Transparency = NumberSequence.new(0.15, 1)
	landingEmitter = impact
end

local function playLanding(volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/action_jump_land.mp3"
	sound.Volume = volume
	sound.PlaybackSpeed = 0.82 + math.random() * 0.12
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 2)
end

player.CharacterAdded:Connect(install)
if player.Character then
	task.spawn(install, player.Character)
end

RunService.RenderStepped:Connect(function()
	local character = activeCharacter
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local skiing = player:GetAttribute("IsSkiing") == true
	local jetpacking = player:GetAttribute("IsJetpacking") == true
	local grounded = skiing or math.abs(velocity.Y) < 1.2

	for _, emitter in jetEmitters do
		emitter.Enabled = jetpacking
		emitter.Rate = 42 + math.clamp(horizontalSpeed * 0.18, 0, 28)
	end
	for _, emitter in skiEmitters do
		emitter.Enabled = skiing and horizontalSpeed > 18
		emitter.Rate = math.clamp((horizontalSpeed - 12) * 0.48, 0, 62)
	end

	if grounded and not lastGrounded and lastVerticalSpeed < -25 then
		local strength = math.clamp((-lastVerticalSpeed - 20) / 55, 0.2, 1)
		if landingEmitter then
			landingEmitter:Emit(math.floor(8 + 18 * strength))
		end
		playLanding(0.12 + strength * 0.18)
	end

	lastGrounded = grounded
	lastVerticalSpeed = velocity.Y
end)
