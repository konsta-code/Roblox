-- ProjectileWeapon.client.lua
-- Ablageort: StarterPlayerScripts
--
-- Rein visuelle, "gefälschte" Kopie des Geschosses für sofortiges Feedback.
-- Diese Version trifft niemanden und macht keinen Schaden - das entscheidet
-- ausschließlich der Server. Sobald das echte, serverseitige Geschoss
-- eintrifft (repliziert automatisch an alle Clients), läuft es einfach
-- daneben her.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.WeaponConstants)
local fireEvent = ReplicatedStorage:WaitForChild("FireWeapon")

local player = Players.LocalPlayer

local lastFireTime = 0

local function spawnVisualProjectile(origin: Vector3, direction: Vector3)
	local visual = Instance.new("Part")
	visual.Shape = Enum.PartType.Ball
	visual.Size = Vector3.new(Constants.PROJECTILE_RADIUS, Constants.PROJECTILE_RADIUS, Constants.PROJECTILE_RADIUS) * 2
	visual.Position = origin
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanQuery = false -- taucht nicht in Maus-Raycasts o.ä. auf
	visual.Material = Enum.Material.Neon
	visual.Parent = workspace

	local velocity = direction.Unit * Constants.PROJECTILE_SPEED
	local startTime = os.clock()

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if os.clock() - startTime > Constants.PROJECTILE_LIFETIME then
			connection:Disconnect()
			visual:Destroy()
			return
		end
		visual.Position += velocity * dt
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	local now = os.clock()
	if now - lastFireTime < Constants.FIRE_COOLDOWN then return end
	lastFireTime = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local camera = workspace.CurrentCamera
	local origin = root.Position
	local direction = camera.CFrame.LookVector

	spawnVisualProjectile(origin, direction)
	fireEvent:FireServer(origin, direction)
end)
