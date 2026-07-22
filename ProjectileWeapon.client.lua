-- ProjectileWeapon.client.lua
-- Immediate client tracer only. The server owns all gameplay decisions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Modules.WeaponConstants)
local fireEvent = ReplicatedStorage:WaitForChild("FireWeapon")
local player = Players.LocalPlayer

type Tracer = { part: BasePart, velocity: Vector3, expiresAt: number }
local tracers: { Tracer } = {}
local lastFireTime = 0

local function spawnTracer(origin: Vector3, velocity: Vector3)
	local part = Instance.new("Part")
	part.Name = "PredictedSpinfusorDisc"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * Constants.PROJECTILE_RADIUS * 2
	part.Position = origin
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(120, 215, 255)
	part.Parent = workspace
	table.insert(tracers, {
		part = part,
		velocity = velocity,
		expiresAt = os.clock() + Constants.CLIENT_PREDICTION_LIFETIME,
	})
end

RunService.RenderStepped:Connect(function(dt)
	for index = #tracers, 1, -1 do
		local tracer = tracers[index]
		if os.clock() >= tracer.expiresAt or not tracer.part.Parent then
			if tracer.part.Parent then tracer.part:Destroy() end
			table.remove(tracers, index)
		else
			tracer.part.Position += tracer.velocity * dt
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if player:GetAttribute("EquippedWeapon") ~= "Spinfusor" then return end

	local now = os.clock()
	if now - lastFireTime < Constants.FIRE_COOLDOWN then return end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 or not camera then return end

	lastFireTime = now
	local direction = camera.CFrame.LookVector.Unit
	local origin = root.Position + direction * 2
	local velocity = direction * Constants.PROJECTILE_SPEED
		+ root.AssemblyLinearVelocity * Constants.PROJECTILE_INHERITANCE
	spawnTracer(origin, velocity)
	fireEvent:FireServer(direction)
end)

print(string.format("[Spinfusor] %s client loaded", Constants.BUILD_ID))
