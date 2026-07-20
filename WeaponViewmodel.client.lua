-- WeaponViewmodel.client.lua
-- Prozedurales First-Person-Viewmodel ohne externe Assets. Alle Teile sind
-- rein lokal, haben keine Kollision und beeinflussen das Gameplay nicht.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local WeaponState = require(ReplicatedStorage.Modules.WeaponState)
local WeaponFeedback = require(ReplicatedStorage.Modules.WeaponFeedback)

local player = Players.LocalPlayer
local VIEWMODEL_SCALE = 0.72

type ViewModel = {
	model: Model,
	root: BasePart,
	parts: { BasePart },
	muzzle: BasePart,
}

local function makePart(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	localCFrame: CFrame,
	shape: Enum.PartType?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size * VIEWMODEL_SCALE
	part.Color = color
	part.Material = material
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.CFrame = root.CFrame
		* CFrame.new(localCFrame.Position * VIEWMODEL_SCALE)
		* localCFrame.Rotation
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function createRoot(name: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name

	local root = Instance.new("Part")
	root.Name = "ViewRoot"
	root.Size = Vector3.new(0.1, 0.1, 0.1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end

local function createSpinfusor(): ViewModel
	local model, root = createRoot("SpinfusorViewmodel")
	local parts = {}
	local dark = Color3.fromRGB(78, 92, 112)
	local metal = Color3.fromRGB(150, 168, 188)
	local energy = Color3.fromRGB(75, 205, 255)

	table.insert(parts, makePart(model, root, "Body", Vector3.new(1.05, 0.8, 2.5), dark, Enum.Material.SmoothPlastic, CFrame.new()))
	table.insert(parts, makePart(model, root, "TopRail", Vector3.new(0.35, 0.28, 1.8), metal, Enum.Material.DiamondPlate, CFrame.new(0, 0.5, 0.05)))
	table.insert(parts, makePart(model, root, "EnergyChamber", Vector3.new(0.72, 0.72, 0.72), energy, Enum.Material.Neon, CFrame.new(0, 0.12, -1.05), Enum.PartType.Ball))
	table.insert(parts, makePart(model, root, "Grip", Vector3.new(0.48, 1.05, 0.65), dark, Enum.Material.SmoothPlastic, CFrame.new(0, -0.75, 0.55) * CFrame.Angles(math.rad(-12), 0, 0)))
	table.insert(parts, makePart(model, root, "MuzzleRing", Vector3.new(0.82, 0.82, 0.32), metal, Enum.Material.Metal, CFrame.new(0, 0, -1.42) * CFrame.Angles(0, math.rad(90), 0), Enum.PartType.Cylinder))
	local muzzle = makePart(model, root, "MuzzleFlash", Vector3.new(0.38, 0.38, 0.38), energy, Enum.Material.Neon, CFrame.new(0, 0, -1.72), Enum.PartType.Ball)
	muzzle.LocalTransparencyModifier = 1

	return { model = model, root = root, parts = parts, muzzle = muzzle }
end

local function createChaingun(): ViewModel
	local model, root = createRoot("ChaingunViewmodel")
	local parts = {}
	local dark = Color3.fromRGB(92, 88, 84)
	local metal = Color3.fromRGB(172, 158, 134)
	local hot = Color3.fromRGB(255, 180, 65)

	table.insert(parts, makePart(model, root, "Body", Vector3.new(1.0, 0.9, 2.15), dark, Enum.Material.SmoothPlastic, CFrame.new(0, 0, 0.18)))
	table.insert(parts, makePart(model, root, "AmmoBox", Vector3.new(0.72, 0.95, 0.82), metal, Enum.Material.DiamondPlate, CFrame.new(0.68, -0.2, 0.45)))
	table.insert(parts, makePart(model, root, "Grip", Vector3.new(0.45, 1.0, 0.6), dark, Enum.Material.SmoothPlastic, CFrame.new(0, -0.75, 0.55) * CFrame.Angles(math.rad(-10), 0, 0)))
	for index, offset in { -0.28, 0, 0.28 } do
		table.insert(parts, makePart(model, root, "Barrel" .. index, Vector3.new(0.16, 0.16, 1.75), metal, Enum.Material.Metal, CFrame.new(offset, 0.18, -1.32)))
	end
	local muzzle = makePart(model, root, "MuzzleFlash", Vector3.new(0.3, 0.3, 0.3), hot, Enum.Material.Neon, CFrame.new(0, 0.18, -2.25), Enum.PartType.Ball)
	muzzle.LocalTransparencyModifier = 1

	return { model = model, root = root, parts = parts, muzzle = muzzle }
end

local spinfusor = createSpinfusor()
local chaingun = createChaingun()
local viewmodels = {
	Spinfusor = spinfusor,
	Chaingun = chaingun,
}

local function addClassAccessory(
	viewmodel: ViewModel,
	className: string,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	shape: Enum.PartType?
)
	local part = makePart(
		viewmodel.model,
		viewmodel.root,
		name,
		size,
		Color3.new(1, 1, 1),
		Enum.Material.Neon,
		localCFrame,
		shape
	)
	part:SetAttribute("ClassOnly", className)
	part:SetAttribute("Accent", true)
	table.insert(viewmodel.parts, part)
end

local discAccessories = {
	Pathfinder = { "AeroFin", Vector3.new(0.12, 0.75, 1.5), CFrame.new(0, 0.72, 0.1), nil },
	Sentinel = { "NovaFork", Vector3.new(1.15, 0.14, 1.2), CFrame.new(0, 0.55, -0.75), nil },
	Infiltrator = { "StealthShroud", Vector3.new(0.82, 0.25, 1.45), CFrame.new(0, 0.42, -0.15), nil },
	Soldier = { "CoreGuard", Vector3.new(0.86, 0.86, 0.22), CFrame.new(0, 0.1, -1.28), Enum.PartType.Cylinder },
	Technician = { "TechCoil", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 0.25, -0.6), Enum.PartType.Ball },
	Raider = { "BurstRack", Vector3.new(1.3, 0.28, 0.72), CFrame.new(0, 0.62, 0.35), nil },
	Juggernaut = { "HeavyPlate", Vector3.new(1.42, 0.35, 1.6), CFrame.new(0, 0.52, 0.2), nil },
	Brute = { "BruteCage", Vector3.new(1.25, 0.18, 1.95), CFrame.new(0, 0.7, -0.1), nil },
	Doombringer = { "SaberFin", Vector3.new(1.55, 0.14, 0.95), CFrame.new(0, 0.38, -1), nil },
}

local automaticAccessories = {
	Pathfinder = { "LightBarrel", Vector3.new(0.18, 0.18, 2.35), CFrame.new(0, 0.45, -1.28), nil },
	Sentinel = { "PrecisionScope", Vector3.new(0.48, 1.15, 0.48), CFrame.new(0, 0.72, -0.05) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder },
	Infiltrator = { "Suppressor", Vector3.new(0.48, 1.35, 0.48), CFrame.new(0, 0.18, -2.45) * CFrame.Angles(math.rad(90), 0, 0), Enum.PartType.Cylinder },
	Soldier = { "BattleRail", Vector3.new(0.32, 0.22, 1.75), CFrame.new(0, 0.68, -0.25), nil },
	Technician = { "TechCell", Vector3.new(0.68, 0.68, 0.68), CFrame.new(-0.62, 0.12, -0.2), Enum.PartType.Ball },
	Raider = { "NJ5Magazine", Vector3.new(0.62, 1.15, 0.78), CFrame.new(0.62, -0.35, 0.25), nil },
	Juggernaut = { "LMGShield", Vector3.new(1.5, 0.95, 0.18), CFrame.new(0, 0.2, -1.25), nil },
	Brute = { "ShotgunDrum", Vector3.new(1.05, 1.05, 0.5), CFrame.new(0.65, -0.1, -0.15) * CFrame.Angles(0, math.rad(90), 0), Enum.PartType.Cylinder },
	Doombringer = { "ChainHousing", Vector3.new(1.38, 0.38, 1.7), CFrame.new(0, 0.58, -0.45), nil },
}

for className, definition in discAccessories do
	addClassAccessory(spinfusor, className, definition[1], definition[2], definition[3], definition[4])
end
for className, definition in automaticAccessories do
	addClassAccessory(chaingun, className, definition[1], definition[2], definition[3], definition[4])
end

local recoil = 0
local meleeSwing = 0
local switchDrop = 1
local flashUntil = 0
local elapsed = 0
local VIEWMODEL_FOV = 85
local smoothedSway = Vector2.zero

local function parentToCamera()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	for _, viewmodel in viewmodels do
		if viewmodel.model.Parent ~= camera then
			viewmodel.model.Parent = camera
		end
	end
end

local function setVisible(viewmodel: ViewModel, visible: boolean, flashVisible: boolean)
	local loadout = player:GetAttribute("Loadout")
	for _, part in viewmodel.parts do
		local classOnly = part:GetAttribute("ClassOnly")
		local matchesClass = classOnly == nil or classOnly == loadout
		part.LocalTransparencyModifier = visible and matchesClass and 0 or 1
	end
	viewmodel.muzzle.LocalTransparencyModifier = visible and flashVisible and 0 or 1
end

local function applyKitColors()
	local kit = ClassKitConstants.Get(player:GetAttribute("Loadout"))
	for _, part in spinfusor.parts do
		if part.Material == Enum.Material.Neon or part:GetAttribute("Accent") then
			part.Color = kit.disc.projectileColor
		end
	end
	spinfusor.muzzle.Color = kit.disc.projectileColor
	for _, part in chaingun.parts do
		if part.Material == Enum.Material.Neon or part:GetAttribute("Accent") then
			part.Color = kit.automatic.tracerColor
		end
	end
	chaingun.muzzle.Color = kit.automatic.tracerColor
end

WeaponState.Changed:Connect(function()
	switchDrop = 1
end)
player:GetAttributeChangedSignal("Loadout"):Connect(applyKitColors)

WeaponFeedback.Fired:Connect(function(weapon: WeaponFeedback.Weapon)
	if weapon == "Melee" then
		meleeSwing = 1
		return
	end
	if weapon == "Grenade" then
		switchDrop = math.max(switchDrop, 0.45)
		return
	end
	if weapon ~= WeaponState.Get() then
		return
	end
	local kit = ClassKitConstants.Get(player:GetAttribute("Loadout"))
	local recoilKick = if weapon == "Spinfusor"
		then math.clamp(kit.disc.directDamage / 105, 0.65, 1.15)
		else math.clamp(kit.automatic.damagePerHit / 30 + (kit.automatic.pellets or 1) * 0.025, 0.12, 0.55)
	recoil = math.min(1.25, recoil + recoilKick)
	flashUntil = os.clock() + (weapon == "Spinfusor" and 0.09 or 0.045)
end)

RunService:BindToRenderStep("WeaponViewmodel", Enum.RenderPriority.Camera.Value + 1, function(dt)
	parentToCamera()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if player:GetAttribute("LoadoutMenuOpen") then
		setVisible(spinfusor, false, false)
		setVisible(chaingun, false, false)
		return
	end

	elapsed += dt
	recoil *= math.exp(-14 * dt)
	meleeSwing *= math.exp(-10 * dt)
	switchDrop *= math.exp(-9 * dt)

	local speed = 0
	local lateralSpeed = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local velocity = root.AssemblyLinearVelocity
		speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		lateralSpeed = velocity:Dot(camera.CFrame.RightVector)
	end
	local zoomFov = player:GetAttribute("WeaponZoomFov")
	local zoomed = typeof(zoomFov) == "number"
	local targetFov = if zoomed then zoomFov else VIEWMODEL_FOV + math.clamp((speed - 35) / 35, 0, 7)
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.clamp(dt * (zoomed and 16 or 6), 0, 1)

	local mouseDelta = UserInputService:GetMouseDelta()
	local targetSway = Vector2.new(
		math.clamp(mouseDelta.X, -18, 18),
		math.clamp(mouseDelta.Y, -18, 18)
	)
	smoothedSway = smoothedSway:Lerp(targetSway, math.clamp(dt * 10, 0, 1))
	local bobStrength = math.clamp(speed / 80, 0, 1) * (zoomed and 0.12 or 1)
	local bobX = math.sin(elapsed * 8) * 0.025 * bobStrength
	local bobY = math.abs(math.cos(elapsed * 8)) * 0.018 * bobStrength
	local roll = math.clamp(-lateralSpeed / 180, -0.025, 0.025)
	local baseCFrame = camera.CFrame
		* CFrame.new(
			1.05 + bobX - smoothedSway.X * 0.0025,
			-1.05 - bobY - switchDrop * 0.28 + smoothedSway.Y * 0.002,
			-3.65 + recoil * 0.13
		)
		* CFrame.Angles(
			math.rad(recoil * 6 + meleeSwing * 12 - smoothedSway.Y * 0.07),
			math.rad(-2 - meleeSwing * 18 - smoothedSway.X * 0.08),
			math.rad(bobX * 20 - meleeSwing * 28) + roll
		)

	for _, viewmodel in viewmodels do
		viewmodel.root.CFrame = baseCFrame
	end

	local selected = WeaponState.Get()
	local flashVisible = os.clock() < flashUntil
	setVisible(spinfusor, not zoomed and selected == "Spinfusor", flashVisible and selected == "Spinfusor")
	setVisible(chaingun, not zoomed and selected == "Chaingun", flashVisible and selected == "Chaingun")
end)

applyKitColors()
