-- WeaponViewmodel.client.lua
-- Cosmetic first-person Spinfusor viewmodel. The server still owns every gameplay
-- decision (see ProjectileWeapon.server.lua); this script only draws the weapon in
-- front of the local camera and kicks it on fire.
--
-- It uses the imported mesh at ReplicatedStorage.WeaponAssets.Spinfusor (a Model or
-- MeshPart) when present, and otherwise builds a primitive placeholder so the weapon
-- is always visible. Import the baked LP mesh into that path to upgrade the look.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Modules.WeaponConstants)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Where the gun sits relative to the camera (studs): right, down, forward.
local BASE_OFFSET = CFrame.new(0.85, -0.75, -1.6)
-- Extra rotation applied to the IMPORTED mesh only, to face its barrel forward.
-- Blender exports the weapon down -Y; tweak this if the mesh comes in rotated.
local MESH_ALIGN = CFrame.Angles(0, math.rad(-90), 0)
local TARGET_LENGTH = 2.6          -- fit the model's longest axis to this many studs
local BOB_SPEED, BOB_AMOUNT = 6.5, 0.03

local viewmodel: Model? = nil
local viewmodelAlign = CFrame.identity
local recoil = 0                    -- decaying kick, 0..1
local lastFire = 0

-- ---------------------------------------------------------------- placeholder
local function part(name, size, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildPlaceholder(): Model
	local m = Instance.new("Model")
	m.Name = "SpinfusorPlaceholder"
	local graphite = Color3.fromRGB(38, 42, 48)
	local ivory = Color3.fromRGB(196, 184, 152)
	local orange = Color3.fromRGB(255, 120, 20)

	local body = part("Body", Vector3.new(0.55, 0.9, 1.9), graphite, Enum.Material.Metal, m)
	part("UpperArmor", Vector3.new(0.62, 0.28, 1.7), ivory, Enum.Material.SmoothPlastic, m).CFrame =
		body.CFrame * CFrame.new(0, 0.55, 0.1)
	part("Barrel", Vector3.new(0.42, 0.42, 0.9), graphite, Enum.Material.Metal, m).CFrame =
		body.CFrame * CFrame.new(0, 0.05, -1.25)
	local grip = part("Grip", Vector3.new(0.45, 0.75, 0.35), Color3.fromRGB(27, 27, 27),
		Enum.Material.Metal, m)
	grip.CFrame = body.CFrame * CFrame.new(0, -0.7, 0.75) * CFrame.Angles(math.rad(18), 0, 0)

	-- glowing energy disc on each side
	for _, side in ipairs({ 1, -1 }) do
		local ring = Instance.new("Part")
		ring.Name = "EnergyRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.12, 1.05, 1.05)
		ring.Color = orange
		ring.Material = Enum.Material.Neon
		ring.Anchored = true; ring.CanCollide = false; ring.CanQuery = false
		ring.CastShadow = false; ring.Massless = true
		ring.CFrame = body.CFrame * CFrame.new(0.34 * side, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = m
	end

	m.PrimaryPart = body
	return m
end

-- ------------------------------------------------------------- model resolution
local function findImportedAsset(): Instance?
	local folder = ReplicatedStorage:FindFirstChild("WeaponAssets")
	local asset = (folder and folder:FindFirstChild("Spinfusor"))
		or ReplicatedStorage:FindFirstChild("Spinfusor")
	return asset
end

local function prepare(inst: Instance): Model
	local model: Model
	if inst:IsA("BasePart") then
		model = Instance.new("Model")
		inst.Parent = model
		model.PrimaryPart = inst
	else
		model = inst :: Model
		if not model.PrimaryPart then
			model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
			d.Massless = true
		end
	end
	-- scale so the longest axis matches TARGET_LENGTH
	local size = model:GetExtentsSize()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 0 then
		model:ScaleTo(TARGET_LENGTH / longest)
	end
	return model
end

local function buildViewmodel()
	if viewmodel then
		viewmodel:Destroy()
		viewmodel = nil
	end
	local asset = findImportedAsset()
	local model
	if asset then
		model = prepare(asset:Clone())
		viewmodelAlign = MESH_ALIGN
	else
		model = buildPlaceholder()
		viewmodelAlign = CFrame.identity
	end
	model.Parent = camera            -- parented to Camera => local-only, no collisions
	viewmodel = model
end

-- ------------------------------------------------------------------ per-frame
RunService:BindToRenderStep("SpinfusorViewmodel", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not viewmodel or not viewmodel.PrimaryPart then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = humanoid and humanoid.Health > 0
	for _, d in ipairs(viewmodel:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = alive and 0 or 1
		end
	end
	if not alive then
		return
	end

	recoil = math.max(0, recoil - dt * 5)
	local t = os.clock()
	local bob = CFrame.new(
		math.sin(t * BOB_SPEED * 0.5) * BOB_AMOUNT,
		math.abs(math.sin(t * BOB_SPEED)) * BOB_AMOUNT,
		0)
	local kick = CFrame.new(0, 0, recoil * 0.35) * CFrame.Angles(recoil * 0.25, 0, 0)
	viewmodel:PivotTo(camera.CFrame * BASE_OFFSET * bob * kick * viewmodelAlign)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local now = os.clock()
	if now - lastFire < Constants.FIRE_COOLDOWN then
		return
	end
	lastFire = now
	recoil = 1
end)

-- rebuild on respawn / when the asset is imported at runtime
player.CharacterAdded:Connect(buildViewmodel)
ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == "Spinfusor" or child.Name == "WeaponAssets" then
		task.wait(0.1)
		buildViewmodel()
	end
end)

buildViewmodel()
print(string.format("[Spinfusor] %s viewmodel loaded (%s)",
	Constants.BUILD_ID, findImportedAsset() and "mesh" or "placeholder"))
