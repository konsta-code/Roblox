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

local function drawTracer(origin: Vector3, endPoint: Vector3, color: Color3, width: number)
	local distance = (endPoint - origin).Magnitude
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = color
	tracer.Size = Vector3.new(width, width, distance)
	tracer.CFrame = CFrame.new(origin, endPoint) * CFrame.new(0, 0, -distance / 2)
	tracer.Parent = workspace

	Debris:AddItem(tracer, 0.05)
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
