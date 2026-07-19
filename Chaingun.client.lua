-- Chaingun.client.lua
-- Ablageort: StarterPlayerScripts
--
-- Client simuliert Spin-up/Hitze rein fürs eigene Gefühl und den lokalen
-- Raycast (sofortiges Feedback: Tracer, wen habe ich anvisiert). Die echte,
-- autoritative Version von Feuerrate/Hitze läuft in Chaingun.server.lua -
-- der Server vertraut hier nichts, was der Client behauptet.
--
-- Steuerung: rechte Maustaste = Zweitwaffe (linke Maustaste bleibt die
-- Splash-Primärwaffe aus ProjectileWeapon.client.lua). Kein Waffenwechsel-
-- System - beide Waffen sind aktuell parallel über feste Tasten nutzbar.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Constants = require(ReplicatedStorage.Modules.ChaingunConstants)
local fireEvent = ReplicatedStorage:WaitForChild("FireChaingun")

local player = Players.LocalPlayer

local isFiring = false
local fireStartTime = 0
local lastShotTime = 0

local function drawTracer(origin: Vector3, endPoint: Vector3)
	local distance = (endPoint - origin).Magnitude
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 220, 120)
	tracer.Size = Vector3.new(0.15, 0.15, distance)
	tracer.CFrame = CFrame.new(origin, endPoint) * CFrame.new(0, 0, -distance / 2)
	tracer.Parent = workspace

	Debris:AddItem(tracer, 0.05)
end

local function fireOnce()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then return end

	local origin = root.Position
	local spreadPitch = math.rad((math.random() - 0.5) * 2 * Constants.SPREAD_ANGLE)
	local spreadYaw = math.rad((math.random() - 0.5) * 2 * Constants.SPREAD_ANGLE)
	local direction = (camera.CFrame * CFrame.Angles(spreadPitch, spreadYaw, 0)).LookVector

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(origin, direction * Constants.MAX_RANGE, rayParams)
	local endPoint = result and result.Position or (origin + direction * Constants.MAX_RANGE)
	local claimedTarget: Player? = nil

	if result then
		local hitCharacter = result.Instance:FindFirstAncestorOfClass("Model")
		claimedTarget = hitCharacter and Players:GetPlayerFromCharacter(hitCharacter)
	end

	drawTracer(origin, endPoint)
	fireEvent:FireServer(origin, direction, claimedTarget)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
	isFiring = true
	fireStartTime = os.clock()
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isFiring = false
	end
end)

RunService.Heartbeat:Connect(function()
	if not isFiring then return end

	local now = os.clock()
	local spinProgress = math.clamp((now - fireStartTime) / Constants.SPIN_UP_TIME, 0, 1)
	local currentInterval = Constants.MAX_FIRE_INTERVAL
		- (Constants.MAX_FIRE_INTERVAL - Constants.MIN_FIRE_INTERVAL) * spinProgress

	if now - lastShotTime >= currentInterval then
		lastShotTime = now
		fireOnce()
	end
end)
