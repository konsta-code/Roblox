-- Chaingun.client.lua
-- Ablageort: StarterPlayerScripts
--
-- Client simuliert Spin-up/Hitze rein fürs eigene Gefühl und den lokalen
-- Raycast (sofortiges Feedback: Tracer, wen habe ich anvisiert). Die echte,
-- autoritative Version von Feuerrate/Hitze läuft in Chaingun.server.lua -
-- der Server vertraut hier nichts, was der Client behauptet.
--
-- Steuerung: Waffenwahl über WeaponSelector (Taste 2 = Chaingun), Feuern mit
-- gehaltener LINKER Maustaste. Feuert nur, wenn die Chaingun aktuell gewählt
-- ist (WeaponState) - sonst liegt Linksklick beim Spinfusor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local ChaingunConstants = require(ReplicatedStorage.Modules.ChaingunConstants)
local WeaponFeedback = require(ReplicatedStorage.Modules.WeaponFeedback)
local WeaponState = require(ReplicatedStorage.Modules.WeaponState)
local fireEvent = ReplicatedStorage:WaitForChild("FireChaingun")

local player = Players.LocalPlayer

local lastShotTime = 0
local firingStartedAt = 0
local localHeat = 0
local localOverheatUntil = 0

local lastImpactSound = 0

local function showImpact(position: Vector3, normal: Vector3, color: Color3, material: Enum.Material)
	local anchor = Instance.new("Part")
	anchor.Name = "BallisticImpact"
	anchor.Size = Vector3.one * 0.12
	anchor.CFrame = CFrame.lookAt(position + normal * 0.025, position + normal)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Parent = workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.55), color)
	sparks.LightEmission = 0.8
	sparks.Lifetime = NumberRange.new(0.07, 0.20)
	sparks.Speed = NumberRange.new(7, 18)
	sparks.Drag = 5
	sparks.SpreadAngle = Vector2.new(42, 42)
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Rate = 0
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.09),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Parent = attachment
	sparks:Emit(if material == Enum.Material.Metal then 8 else 5)

	local scorch = Instance.new("Part")
	scorch.Name = "ImpactFlash"
	scorch.Shape = Enum.PartType.Ball
	scorch.Size = Vector3.one * 0.22
	scorch.Position = position + normal * 0.03
	scorch.Anchored = true
	scorch.CanCollide = false
	scorch.CanQuery = false
	scorch.CanTouch = false
	scorch.Material = Enum.Material.Neon
	scorch.Color = color
	scorch.Transparency = 0.16
	scorch.Parent = workspace
	TweenService:Create(scorch, TweenInfo.new(0.09), { Size = Vector3.one * 0.55, Transparency = 1 }):Play()
	Debris:AddItem(scorch, 0.12)

	if os.clock() - lastImpactSound > 0.055 then
		lastImpactSound = os.clock()
		local hitSound = Instance.new("Sound")
		hitSound.SoundId = "rbxasset://sounds/collide.wav"
		hitSound.Volume = 0.055
		hitSound.PlaybackSpeed = (if material == Enum.Material.Metal then 1.55 else 0.92) * (0.94 + math.random() * 0.12)
		hitSound.RollOffMinDistance = 4
		hitSound.RollOffMaxDistance = 85
		hitSound.Parent = anchor
		hitSound:Play()
	end
	Debris:AddItem(anchor, 1.2)
end

local function drawTracer(origin: Vector3, endPoint: Vector3, color: Color3, width: number)
	local distance = (endPoint - origin).Magnitude
	if distance <= 0.05 then return end
	local direction = (endPoint - origin).Unit
	-- A ballistic streak is a short moving segment, not a solid laser spanning
	-- the whole ray. Longer shots leave a slightly longer readable segment.
	local visibleLength = math.min(distance, 14 + distance * 0.07)
	local center = endPoint - direction * visibleLength * 0.5
	local tracer = Instance.new("Part")
	tracer.Name = "BallisticTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = color:Lerp(Color3.new(1, 1, 1), 0.28)
	tracer.Transparency = 0.08
	tracer.Size = Vector3.new(math.max(0.035, width * 0.58), math.max(0.035, width * 0.58), visibleLength)
	tracer.CFrame = CFrame.new(center, endPoint)
	tracer.Parent = workspace
	TweenService:Create(tracer, TweenInfo.new(0.075, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0.01, 0.01, visibleLength * 0.72),
	}):Play()
	Debris:AddItem(tracer, 0.09)
end

local function fireOnce(profile: ClassKitConstants.AutomaticProfile)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then return end

	local origin = root.Position
	local direction = camera.CFrame.LookVector

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local pelletCount = math.clamp(math.floor(profile.pellets or 1), 1, 12)
	for _ = 1, pelletCount do
		local spreadPitch = math.rad((math.random() - 0.5) * 2 * profile.spreadAngle)
		local spreadYaw = math.rad((math.random() - 0.5) * 2 * profile.spreadAngle)
		local shotDirection = (camera.CFrame * CFrame.Angles(spreadPitch, spreadYaw, 0)).LookVector
		local result = workspace:Raycast(origin, shotDirection * profile.maxRange, rayParams)
		local endPoint = result and result.Position or (origin + shotDirection * profile.maxRange)
		drawTracer(origin, endPoint, profile.tracerColor, profile.tracerWidth or 0.15)
		if result then
			local surfaceColor = if result.Instance:IsA("BasePart") then result.Instance.Color else profile.tracerColor
			showImpact(result.Position, result.Normal, surfaceColor:Lerp(profile.tracerColor, 0.28), result.Material)
		end
	end
	fireEvent:FireServer(direction)
	WeaponFeedback.Fire("Chaingun")
end

local function tryFire(isInitialPress: boolean)
	if not WeaponState.IsPrimaryDown() then return end
	if player:GetAttribute("LoadoutMenuOpen") then return end
	local silencedUntil = player:GetAttribute("AbilitySilencedUntil")
	if typeof(silencedUntil) == "number" and silencedUntil > workspace:GetServerTimeNow() then return end
	if WeaponState.Get() ~= "Chaingun" then return end -- Linksklick nur wenn Chaingun gewählt
	local now = os.clock()
	local profile = ClassKitConstants.Get(player:GetAttribute("Loadout")).automatic
	if localOverheatUntil > now then return end
	if profile.singleShotCooldown and not isInitialPress then return end
	local spinProgress = math.clamp((now - firingStartedAt) / math.max(profile.spinUpTime, 0.01), 0, 1)
	local cooldown = profile.singleShotCooldown
		or (profile.maxFireInterval - (profile.maxFireInterval - profile.minFireInterval) * spinProgress)
	if now - lastShotTime < cooldown then return end
	lastShotTime = now
	localHeat = math.min(ChaingunConstants.HEAT_MAX, localHeat + profile.heatPerShot)
	if localHeat >= ChaingunConstants.HEAT_MAX then
		localOverheatUntil = now + profile.overheatLockout
	end
	WeaponState.SetAutomaticHeat(localHeat, localOverheatUntil)
	WeaponFeedback.StartCooldown("Chaingun", cooldown)
	fireOnce(profile)
end

WeaponState.PrimaryChanged:Connect(function(down: boolean)
	if down then
		firingStartedAt = os.clock()
		tryFire(true)
	end
end)

local function resetHeat()
	localHeat = 0
	localOverheatUntil = 0
	WeaponState.SetAutomaticHeat(0, 0)
end

player.CharacterAdded:Connect(resetHeat)
player:GetAttributeChangedSignal("Loadout"):Connect(resetHeat)

RunService.RenderStepped:Connect(function(dt)
	local profile = ClassKitConstants.Get(player:GetAttribute("Loadout")).automatic
	localHeat = math.max(0, localHeat - profile.heatCooldownRate * dt)
	if localOverheatUntil <= os.clock() and localHeat < ChaingunConstants.HEAT_MAX then
		localOverheatUntil = 0
	end
	WeaponState.SetAutomaticHeat(localHeat, localOverheatUntil)
	tryFire(false)
end)
