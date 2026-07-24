-- Local-only movement VFX. This observes the controller state and never changes physics.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

-- Ski-/Jet-Status an den Server melden (MovementGuard spiegelt ihn als
-- Character-Attribut fuer alle): der SkiController setzt die Attribute nur
-- CLIENT-seitig, die repliziert Roblox nicht -- Fremd-Clients sahen deshalb
-- laufende Beine statt Ski-Haltung. Event wird serverseitig dynamisch erzeugt,
-- daher WaitForChild mit Timeout statt haengen.
local movementStateSync: RemoteEvent? = nil
task.spawn(function()
	local event = ReplicatedStorage:WaitForChild("MovementStateSync", 30)
	if event and event:IsA("RemoteEvent") then
		movementStateSync = event
	end
end)
local lastSentSkiing = false
local lastSentJetpacking = false
local lastSyncTime = 0

-- High-speed presentation is deliberately screen-space only. It makes routes
-- above skiing speed readable without adding camera shake to precision aim.
local speedGui = Instance.new("ScreenGui")
speedGui.Name = "TitanKineticFeedback"
speedGui.ResetOnSpawn = false
speedGui.IgnoreGuiInset = true
speedGui.DisplayOrder = 4
speedGui.Parent = player:WaitForChild("PlayerGui")

local speedLayer = Instance.new("CanvasGroup")
speedLayer.Name = "SpeedStreaks"
speedLayer.Size = UDim2.fromScale(1, 1)
speedLayer.BackgroundTransparency = 1
speedLayer.GroupTransparency = 1
speedLayer.Parent = speedGui

local speedStreaks: { Frame } = {}
for index = 1, 18 do
	local angle = (index / 18) * math.pi * 2 + (index % 3) * 0.07
	local streak = Instance.new("Frame")
	streak.Name = "Streak" .. index
	streak.AnchorPoint = Vector2.new(0.5, 0.5)
	streak.BorderSizePixel = 0
	streak.BackgroundColor3 = if index % 4 == 0
		then Color3.fromRGB(255, 196, 92)
		else Color3.fromRGB(108, 220, 255)
	streak.BackgroundTransparency = 0.22
	streak.Rotation = math.deg(angle) + 90
	streak:SetAttribute("Angle", angle)
	streak:SetAttribute("Phase", (index * 0.137) % 1)
	streak.Parent = speedLayer
	table.insert(speedStreaks, streak)
end

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

-- Ski-Rutsch-Loop: zwei Schichten aus derselben Rausch-Quelle wie der Wind.
-- Hiss (hochgepitcht, Hoehen betont) = Kanten-Zischen auf der Flaeche,
-- Rumble (stark runtergepitcht, Baesse betont) = Vibration/Grollen unterm
-- Brett. Beide skalieren mit Bodengeschwindigkeit und sind in der Luft stumm.
local function newSkiLayer(name: string, pitch: number, lowGain: number, highGain: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxasset://sounds/action_falling.ogg"
	sound.Looped = true
	sound.Volume = 0
	sound.PlaybackSpeed = pitch
	local equalizer = Instance.new("EqualizerSoundEffect")
	equalizer.LowGain = lowGain
	equalizer.MidGain = 0
	equalizer.HighGain = highGain
	equalizer.Parent = sound
	sound.Parent = SoundService
	sound:Play()
	return sound
end

local skiHiss = newSkiLayer("SkiSlideHiss", 1.7, -10, 6)
local skiRumble = newSkiLayer("SkiSlideRumble", 0.32, 8, -10)

-- Standard-Roblox-Schrittgeraeusch ("Running" im RootPart) beim Skiing
-- stummschalten -- sonst klingt Skifahren wie normales Laufen. Beim Verlassen
-- des Ski-Zustands einmalig auf den Roblox-Default (0.65) zurueck.
local DEFAULT_FOOTSTEP_VOLUME = 0.65
local wasSkiing = false

local function defaultRunningSound(character: Model): Sound?
	local root = character:FindFirstChild("HumanoidRootPart")
	local sound = root and root:FindFirstChild("Running")
	return if sound and sound:IsA("Sound") then sound else nil
end

player.CharacterAdded:Connect(install)
if player.Character then
	task.spawn(install, player.Character)
end

RunService.RenderStepped:Connect(function(dt)
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

	-- Ski-Audio: Lautstaerke/Pitch aus der Bodengeschwindigkeit. IsSkiing ist
	-- nur bei Bodenkontakt gesetzt (SkiController), ueber Kuppen wird der Loop
	-- also automatisch kurz still -- der Tribes-Rhythmus aus Zischen und Stille.
	local skiAlpha = math.clamp((horizontalSpeed - 8) / 95, 0, 1)
	local hissTarget = if skiing then 0.08 + skiAlpha * 0.5 else 0
	local rumbleTarget = if skiing then 0.06 + skiAlpha * 0.36 else 0
	local fade = math.clamp(dt * 10, 0, 1)
	skiHiss.Volume += (hissTarget - skiHiss.Volume) * fade
	skiRumble.Volume += (rumbleTarget - skiRumble.Volume) * fade
	skiHiss.PlaybackSpeed = 1.5 + skiAlpha * 0.75
	skiRumble.PlaybackSpeed = 0.3 + skiAlpha * 0.14

	local runningSound = defaultRunningSound(character)
	if skiing then
		if runningSound then runningSound.Volume = 0 end
	elseif wasSkiing and runningSound then
		runningSound.Volume = DEFAULT_FOOTSTEP_VOLUME
	end
	wasSkiing = skiing

	-- Status-Sync an den Server: nur bei Aenderung, max ~10/s.
	local now = os.clock()
	if movementStateSync
		and (skiing ~= lastSentSkiing or jetpacking ~= lastSentJetpacking)
		and now - lastSyncTime > 0.1 then
		movementStateSync:FireServer(skiing, jetpacking)
		lastSentSkiing = skiing
		lastSentJetpacking = jetpacking
		lastSyncTime = now
	end

	local speedAlpha = math.clamp((horizontalSpeed - 72) / 115, 0, 1)
	speedLayer.GroupTransparency += ((1 - speedAlpha * 0.72) - speedLayer.GroupTransparency)
		* math.clamp(dt * 6, 0, 1)
	for index, streak in speedStreaks do
		local phase = ((streak:GetAttribute("Phase") :: number) + dt * (0.34 + speedAlpha * 0.82)) % 1
		streak:SetAttribute("Phase", phase)
		local angle = streak:GetAttribute("Angle") :: number
		local radius = 0.12 + phase * 0.62
		local x = 0.5 + math.cos(angle) * radius
		local y = 0.5 + math.sin(angle) * radius * 0.78
		streak.Position = UDim2.fromScale(x, y)
		streak.Size = UDim2.fromOffset(1 + speedAlpha * 2, 10 + phase * (44 + speedAlpha * 55))
		streak.BackgroundTransparency = math.clamp(0.22 + phase * 0.5 + (index % 3) * 0.06, 0, 0.92)
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
