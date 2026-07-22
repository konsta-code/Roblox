-- Camera-local alpine weather. No particles are replicated, and the emitter
-- follows only the local view so a large arena never needs a giant particle
-- volume on the server.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local anchor = Instance.new("Part")
anchor.Name = "LocalTitanWeather"
anchor.Size = Vector3.new(125, 2, 96)
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanTouch = false
anchor.CanQuery = false
anchor.CastShadow = false
anchor.Transparency = 1
anchor.Parent = workspace

local snow = Instance.new("ParticleEmitter")
snow.Name = "TitanSnow"
snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
snow.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(244, 250, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(176, 211, 236)),
})
snow.LightEmission = 0.08
snow.LightInfluence = 0.55
snow.Lifetime = NumberRange.new(2.7, 4.1)
snow.Rate = 92
snow.Speed = NumberRange.new(18, 31)
snow.Acceleration = Vector3.new(7, -5, 3)
snow.Drag = 0.35
snow.EmissionDirection = Enum.NormalId.Bottom
snow.SpreadAngle = Vector2.new(12, 12)
snow.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.13),
	NumberSequenceKeypoint.new(0.72, 0.09),
	NumberSequenceKeypoint.new(1, 0.02),
})
snow.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.25),
	NumberSequenceKeypoint.new(0.15, 0.05),
	NumberSequenceKeypoint.new(0.84, 0.18),
	NumberSequenceKeypoint.new(1, 1),
})
snow.Shape = Enum.ParticleEmitterShape.Box
snow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
snow.Parent = anchor

local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.04 then return end
	accumulator = 0
	local camera = workspace.CurrentCamera
	if not camera then return end
	anchor.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 38, 0))
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local speed = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity.Magnitude else 0
	snow.Rate = 86 + math.clamp(speed * 0.16, 0, 34)
end)

script.Destroying:Connect(function()
	anchor:Destroy()
end)
