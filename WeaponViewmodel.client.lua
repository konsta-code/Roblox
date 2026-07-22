-- WeaponViewmodel.client.lua
-- First-Person-Viewmodel. Bevorzugt die klassenspezifischen Blender-Meshes und
-- nutzt die prozeduralen Waffen als Fallback, falls ein Asset noch fehlt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local WeaponState = require(ReplicatedStorage.Modules.WeaponState)
local WeaponFeedback = require(ReplicatedStorage.Modules.WeaponFeedback)

local player = Players.LocalPlayer

-- Give the server-side Studio import organizer a moment to move freshly
-- imported FBX models out of Workspace before viewmodels are discovered.
local importDeadline = os.clock() + 3
while ReplicatedStorage:GetAttribute("ImportedWeaponsResolved") ~= true and os.clock() < importDeadline do
	task.wait(0.05)
end
local VIEWMODEL_SCALE = 0.72
local IMPORTED_WEAPON_LENGTH = {
	Spinfusor = 2.5,
	Chaingun = 3.15,
}
local IMPORTED_WEAPON_OFFSET = {
	Spinfusor = CFrame.new(0.28, -0.6, 0.15),
	Chaingun = CFrame.new(0.3, -0.58, 0.12),
}
local IMPORTED_WEAPON_MUZZLE = {
	Spinfusor = CFrame.new(0.28, -0.58, -1.3),
	Chaingun = CFrame.new(0.3, -0.52, -1.72),
}

local IMPORTED_ASSET_NAMES = {
	Pathfinder = { Spinfusor = "Pathfinder_LightSpinfusor", Chaingun = "Pathfinder_LightAssaultRifle" },
	Sentinel = { Spinfusor = "Sentinel_NovaBlaster", Chaingun = "Sentinel_BXT1Rifle" },
	Infiltrator = { Spinfusor = "Infiltrator_StealthSpinfusor", Chaingun = "Infiltrator_RhinoSMG" },
	Soldier = { Spinfusor = "Soldier_Spinfusor", Chaingun = "Soldier_AssaultRifle" },
	Technician = { Spinfusor = "Technician_Thumper", Chaingun = "Technician_TCN4SMG" },
	Raider = { Spinfusor = "Raider_ARXBuster", Chaingun = "Raider_NJ5SMG" },
	Juggernaut = { Spinfusor = "Juggernaut_HeavySpinfusor", Chaingun = "Juggernaut_X1LMG" },
	Brute = { Spinfusor = "Brute_BruteSpinfusor", Chaingun = "Brute_AutoShotgun" },
	Doombringer = { Spinfusor = "Doombringer_SaberLauncher", Chaingun = "Doombringer_Chaingun" },
}

type WeaponTheme = {
	armor: Color3,
	polymer: Color3,
	metal: Color3,
	trim: Color3,
	grip: Color3,
}

local DEFAULT_THEME: WeaponTheme = {
	armor = Color3.fromRGB(54, 66, 82),
	polymer = Color3.fromRGB(24, 29, 36),
	metal = Color3.fromRGB(135, 148, 162),
	trim = Color3.fromRGB(190, 201, 211),
	grip = Color3.fromRGB(17, 20, 24),
}

-- Jede Klasse bekommt eine eigene, gedeckte Materialpalette. Die hellen
-- Projektilfarben bleiben nur an Energiezellen und kleinen Statusstreifen.
local CLASS_THEMES: { [string]: WeaponTheme } = {
	Pathfinder = {
		armor = Color3.fromRGB(43, 75, 102),
		polymer = Color3.fromRGB(19, 31, 42),
		metal = Color3.fromRGB(139, 169, 190),
		trim = Color3.fromRGB(194, 222, 235),
		grip = Color3.fromRGB(16, 23, 29),
	},
	Sentinel = {
		armor = Color3.fromRGB(50, 61, 78),
		polymer = Color3.fromRGB(18, 22, 30),
		metal = Color3.fromRGB(124, 146, 170),
		trim = Color3.fromRGB(185, 209, 225),
		grip = Color3.fromRGB(14, 17, 23),
	},
	Infiltrator = {
		armor = Color3.fromRGB(48, 37, 63),
		polymer = Color3.fromRGB(18, 15, 24),
		metal = Color3.fromRGB(103, 93, 119),
		trim = Color3.fromRGB(146, 118, 180),
		grip = Color3.fromRGB(13, 11, 17),
	},
	Soldier = {
		armor = Color3.fromRGB(62, 74, 82),
		polymer = Color3.fromRGB(25, 30, 33),
		metal = Color3.fromRGB(139, 151, 157),
		trim = Color3.fromRGB(192, 202, 205),
		grip = Color3.fromRGB(18, 22, 23),
	},
	Technician = {
		armor = Color3.fromRGB(39, 75, 69),
		polymer = Color3.fromRGB(17, 30, 29),
		metal = Color3.fromRGB(116, 159, 150),
		trim = Color3.fromRGB(174, 210, 196),
		grip = Color3.fromRGB(13, 22, 21),
	},
	Raider = {
		armor = Color3.fromRGB(91, 76, 47),
		polymer = Color3.fromRGB(35, 29, 20),
		metal = Color3.fromRGB(164, 142, 96),
		trim = Color3.fromRGB(218, 192, 127),
		grip = Color3.fromRGB(25, 21, 16),
	},
	Juggernaut = {
		armor = Color3.fromRGB(86, 60, 43),
		polymer = Color3.fromRGB(35, 25, 20),
		metal = Color3.fromRGB(146, 116, 90),
		trim = Color3.fromRGB(206, 155, 105),
		grip = Color3.fromRGB(25, 18, 15),
	},
	Brute = {
		armor = Color3.fromRGB(83, 43, 43),
		polymer = Color3.fromRGB(34, 18, 19),
		metal = Color3.fromRGB(139, 91, 87),
		trim = Color3.fromRGB(202, 124, 112),
		grip = Color3.fromRGB(24, 13, 14),
	},
	Doombringer = {
		armor = Color3.fromRGB(70, 65, 38),
		polymer = Color3.fromRGB(29, 27, 17),
		metal = Color3.fromRGB(151, 142, 83),
		trim = Color3.fromRGB(211, 198, 108),
		grip = Color3.fromRGB(21, 20, 13),
	},
}

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

local function markFinish(part: BasePart, finishRole: string): BasePart
	part:SetAttribute("FinishRole", finishRole)
	return part
end

local function addSurfaceMarking(part: BasePart, face: Enum.NormalId, lineOne: string, lineTwo: string)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "WeaponMarking"
	surface.Face = face
	surface.AlwaysOnTop = false
	surface.LightInfluence = 0.35
	surface.PixelsPerStud = 90
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.Parent = part

	local stripe = Instance.new("Frame")
	stripe.Name = "AccentStripe"
	stripe.BackgroundColor3 = Color3.new(1, 1, 1)
	stripe.BorderSizePixel = 0
	stripe.Position = UDim2.fromScale(0.06, 0.08)
	stripe.Size = UDim2.fromScale(0.035, 0.84)
	stripe.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = lineOne
	title.TextColor3 = Color3.fromRGB(224, 232, 237)
	title.TextScaled = true
	title.TextStrokeTransparency = 0.72
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromScale(0.14, 0.14)
	title.Size = UDim2.fromScale(0.78, 0.38)
	title.Parent = surface

	local serial = Instance.new("TextLabel")
	serial.Name = "Serial"
	serial.BackgroundTransparency = 1
	serial.Font = Enum.Font.RobotoMono
	serial.Text = lineTwo
	serial.TextColor3 = Color3.fromRGB(154, 166, 174)
	serial.TextScaled = true
	serial.TextXAlignment = Enum.TextXAlignment.Left
	serial.Position = UDim2.fromScale(0.14, 0.57)
	serial.Size = UDim2.fromScale(0.7, 0.2)
	serial.Parent = surface
end

local function addFastener(model: Model, root: BasePart, position: Vector3)
	local fastener = makePart(
		model,
		root,
		"Fastener",
		Vector3.new(0.1, 0.1, 0.055),
		Color3.fromRGB(168, 178, 185),
		Enum.Material.Metal,
		CFrame.new(position),
		Enum.PartType.Ball
	)
	markFinish(fastener, "Metal")
	return fastener
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

local function createImportedWeapon(slotName: string): ViewModel?
	local weaponAssets = ReplicatedStorage:FindFirstChild("WeaponAssets")
	if not weaponAssets then
		return nil
	end

	local loadout = tostring(player:GetAttribute("Loadout") or "Pathfinder")
	local classAssets = IMPORTED_ASSET_NAMES[loadout]
	local assetName = classAssets and classAssets[slotName]
	local template = assetName and weaponAssets:FindFirstChild(assetName, true)
	-- Abwärtskompatibel zum bereits manuell importierten Spinfusor.
	if not template and slotName == "Spinfusor" then
		template = weaponAssets:FindFirstChild("Spinfusor")
	end
	if not template or (not template:IsA("Model") and not template:IsA("BasePart")) then
		return nil
	end

	local model, root = createRoot(slotName .. "Viewmodel")
	model:SetAttribute("UsesImportedMesh", true)
	local imported = template:Clone()
	imported.Name = "Imported_" .. (assetName or "Spinfusor")
	imported.Parent = model
	local bounds = if imported:IsA("Model") then imported:GetExtentsSize() else imported.Size
	local longestAxis = math.max(bounds.X, bounds.Y, bounds.Z)
	if longestAxis <= 0 then
		model:Destroy()
		return nil
	end
	local scale = IMPORTED_WEAPON_LENGTH[slotName] / longestAxis
	if imported:IsA("Model") then
		imported:ScaleTo(scale)
		imported:PivotTo(root.CFrame * IMPORTED_WEAPON_OFFSET[slotName])
	else
		imported.Size *= scale
		imported.CFrame = root.CFrame * IMPORTED_WEAPON_OFFSET[slotName]
	end

	local parts = {}
	local function configureImportedPart(part: BasePart)
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		part:SetAttribute("FinishRole", "ImportedMesh")
		table.insert(parts, part)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	if imported:IsA("BasePart") then
		configureImportedPart(imported)
	end
	for _, descendant in imported:GetDescendants() do
		if descendant:IsA("BasePart") then
			configureImportedPart(descendant)
		end
	end

	if #parts == 0 then
		model:Destroy()
		return nil
	end

	local muzzle = makePart(
		model,
		root,
		"MuzzleFlash",
		Vector3.new(0.4, 0.4, 0.4),
		Color3.fromRGB(75, 205, 255),
		Enum.Material.Neon,
		IMPORTED_WEAPON_MUZZLE[slotName],
		Enum.PartType.Ball
	)
	muzzle.Size = Vector3.new(0.26, 0.26, 0.26)
	muzzle.LocalTransparencyModifier = 1
	print(string.format("[WeaponViewmodel] Imported %s asset loaded for %s: %s", slotName, loadout, template:GetFullName()))
	return { model = model, root = root, parts = parts, muzzle = muzzle }
end

local function createSpinfusor(): ViewModel
	local imported = createImportedWeapon("Spinfusor")
	if imported then
		return imported
	end

	local model, root = createRoot("SpinfusorViewmodel")
	local parts = {}
	local function add(part: BasePart, finishRole: string): BasePart
		markFinish(part, finishRole)
		table.insert(parts, part)
		return part
	end

	local body = add(makePart(model, root, "Body", Vector3.new(1.05, 0.72, 2.35), DEFAULT_THEME.armor, Enum.Material.SmoothPlastic, CFrame.new(0, 0.02, 0.08)), "Armor")
	addSurfaceMarking(body, Enum.NormalId.Left, "SPINFUSOR", "DISC // MAG-01")
	addSurfaceMarking(body, Enum.NormalId.Right, "SPINFUSOR", "DISC // MAG-01")
	add(makePart(model, root, "LowerReceiver", Vector3.new(0.88, 0.34, 1.72), DEFAULT_THEME.polymer, Enum.Material.SmoothPlastic, CFrame.new(0, -0.43, 0.27)), "Polymer")
	add(makePart(model, root, "LeftArmorPanel", Vector3.new(0.09, 0.51, 1.52), DEFAULT_THEME.trim, Enum.Material.Metal, CFrame.new(-0.56, 0.08, 0.23)), "Trim")
	add(makePart(model, root, "RightArmorPanel", Vector3.new(0.09, 0.51, 1.52), DEFAULT_THEME.trim, Enum.Material.Metal, CFrame.new(0.56, 0.08, 0.23)), "Trim")
	add(makePart(model, root, "TopRail", Vector3.new(0.34, 0.22, 1.72), DEFAULT_THEME.metal, Enum.Material.DiamondPlate, CFrame.new(0, 0.48, 0.17)), "Metal")
	add(makePart(model, root, "RearCap", Vector3.new(0.88, 0.66, 0.26), DEFAULT_THEME.metal, Enum.Material.Metal, CFrame.new(0, 0.02, 1.35)), "Metal")

	local chamber = add(makePart(model, root, "EnergyChamber", Vector3.new(0.65, 0.65, 0.65), Color3.fromRGB(75, 205, 255), Enum.Material.Neon, CFrame.new(0, 0.12, -1.02), Enum.PartType.Ball), "Energy")
	chamber:SetAttribute("EnergyCore", true)
	local chamberLight = Instance.new("PointLight")
	chamberLight.Name = "EnergyGlow"
	chamberLight.Color = chamber.Color
	chamberLight.Brightness = 0.75
	chamberLight.Range = 4
	chamberLight.Shadows = false
	chamberLight.Parent = chamber
	add(makePart(model, root, "ChamberBandRear", Vector3.new(0.79, 0.79, 0.12), DEFAULT_THEME.metal, Enum.Material.Metal, CFrame.new(0, 0.12, -0.78) * CFrame.Angles(0, math.rad(90), 0), Enum.PartType.Cylinder), "Metal")
	add(makePart(model, root, "ChamberBandFront", Vector3.new(0.79, 0.79, 0.12), DEFAULT_THEME.metal, Enum.Material.Metal, CFrame.new(0, 0.12, -1.25) * CFrame.Angles(0, math.rad(90), 0), Enum.PartType.Cylinder), "Metal")
	add(makePart(model, root, "LeftEnergyStrip", Vector3.new(0.055, 0.1, 1.12), Color3.fromRGB(75, 205, 255), Enum.Material.Neon, CFrame.new(-0.61, -0.13, 0.16)), "Energy")
	add(makePart(model, root, "RightEnergyStrip", Vector3.new(0.055, 0.1, 1.12), Color3.fromRGB(75, 205, 255), Enum.Material.Neon, CFrame.new(0.61, -0.13, 0.16)), "Energy")

	add(makePart(model, root, "Grip", Vector3.new(0.48, 1.05, 0.65), DEFAULT_THEME.grip, Enum.Material.SmoothPlastic, CFrame.new(0, -0.75, 0.55) * CFrame.Angles(math.rad(-12), 0, 0)), "Grip")
	for ribIndex = 0, 4 do
		add(makePart(
			model,
			root,
			"GripRib" .. ribIndex,
			Vector3.new(0.52, 0.065, 0.7),
			DEFAULT_THEME.metal,
			Enum.Material.Metal,
			CFrame.new(0, -0.49 - ribIndex * 0.17, 0.51) * CFrame.Angles(math.rad(-12), 0, 0)
		), "Metal")
	end

	add(makePart(model, root, "MuzzleCollar", Vector3.new(0.92, 0.92, 0.28), DEFAULT_THEME.polymer, Enum.Material.SmoothPlastic, CFrame.new(0, 0.02, -1.37) * CFrame.Angles(0, math.rad(90), 0), Enum.PartType.Cylinder), "Polymer")
	add(makePart(model, root, "MuzzleRing", Vector3.new(0.78, 0.78, 0.34), DEFAULT_THEME.metal, Enum.Material.Metal, CFrame.new(0, 0.02, -1.51) * CFrame.Angles(0, math.rad(90), 0), Enum.PartType.Cylinder), "Metal")
	add(makePart(model, root, "MuzzleBore", Vector3.new(0.46, 0.46, 0.37), Color3.fromRGB(10, 12, 15), Enum.Material.SmoothPlastic, CFrame.new(0, 0.02, -1.7) * CFrame.Angles(0, math.rad(90), 0), Enum.PartType.Cylinder), "Grip")

	for _, position in {
		Vector3.new(-0.57, 0.27, 0.82),
		Vector3.new(-0.57, -0.12, 0.82),
		Vector3.new(-0.57, 0.27, -0.31),
		Vector3.new(0.57, 0.27, 0.82),
		Vector3.new(0.57, -0.12, 0.82),
		Vector3.new(0.57, 0.27, -0.31),
	} do
		table.insert(parts, addFastener(model, root, position))
	end

	local muzzle = makePart(model, root, "MuzzleFlash", Vector3.new(0.4, 0.4, 0.4), Color3.fromRGB(75, 205, 255), Enum.Material.Neon, CFrame.new(0, 0.02, -1.95), Enum.PartType.Ball)
	muzzle.LocalTransparencyModifier = 1

	return { model = model, root = root, parts = parts, muzzle = muzzle }
end

local function createChaingun(): ViewModel
	local imported = createImportedWeapon("Chaingun")
	if imported then
		return imported
	end

	local model, root = createRoot("ChaingunViewmodel")
	local parts = {}
	local function add(part: BasePart, finishRole: string): BasePart
		markFinish(part, finishRole)
		table.insert(parts, part)
		return part
	end

	local body = add(makePart(model, root, "Body", Vector3.new(1.03, 0.82, 2.05), DEFAULT_THEME.armor, Enum.Material.SmoothPlastic, CFrame.new(0, 0.02, 0.22)), "Armor")
	addSurfaceMarking(body, Enum.NormalId.Left, "AUTOCANNON", "KINETIC // FEED")
	addSurfaceMarking(body, Enum.NormalId.Right, "AUTOCANNON", "KINETIC // FEED")
	add(makePart(model, root, "UpperReceiver", Vector3.new(0.72, 0.24, 1.68), DEFAULT_THEME.metal, Enum.Material.DiamondPlate, CFrame.new(0, 0.52, 0.08)), "Metal")
	add(makePart(model, root, "LowerReceiver", Vector3.new(0.8, 0.28, 1.42), DEFAULT_THEME.polymer, Enum.Material.SmoothPlastic, CFrame.new(0, -0.48, 0.3)), "Polymer")
	add(makePart(model, root, "LeftReceiverPlate", Vector3.new(0.08, 0.52, 1.35), DEFAULT_THEME.trim, Enum.Material.Metal, CFrame.new(-0.56, 0.08, 0.19)), "Trim")
	add(makePart(model, root, "RightReceiverPlate", Vector3.new(0.08, 0.52, 1.35), DEFAULT_THEME.trim, Enum.Material.Metal, CFrame.new(0.56, 0.08, 0.19)), "Trim")

	add(makePart(model, root, "AmmoBox", Vector3.new(0.7, 0.92, 0.78), DEFAULT_THEME.metal, Enum.Material.DiamondPlate, CFrame.new(0.69, -0.2, 0.47)), "Metal")
	add(makePart(model, root, "AmmoBoxLatch", Vector3.new(0.12, 0.3, 0.48), DEFAULT_THEME.trim, Enum.Material.Metal, CFrame.new(1.07, -0.03, 0.47)), "Trim")
	add(makePart(model, root, "AmmoStatus", Vector3.new(0.055, 0.12, 0.48), Color3.fromRGB(255, 180, 65), Enum.Material.Neon, CFrame.new(1.075, 0.27, 0.47)), "Energy")

	add(makePart(model, root, "Grip", Vector3.new(0.45, 1.0, 0.6), DEFAULT_THEME.grip, Enum.Material.SmoothPlastic, CFrame.new(0, -0.75, 0.55) * CFrame.Angles(math.rad(-10), 0, 0)), "Grip")
	for ribIndex = 0, 4 do
		add(makePart(
			model,
			root,
			"GripRib" .. ribIndex,
			Vector3.new(0.49, 0.06, 0.65),
			DEFAULT_THEME.metal,
			Enum.Material.Metal,
			CFrame.new(0, -0.49 - ribIndex * 0.16, 0.52) * CFrame.Angles(math.rad(-10), 0, 0)
		), "Metal")
	end

	add(makePart(model, root, "BarrelMount", Vector3.new(0.82, 0.7, 0.34), DEFAULT_THEME.polymer, Enum.Material.SmoothPlastic, CFrame.new(0, 0.15, -0.92)), "Polymer")
	for index, offset in { -0.28, 0, 0.28 } do
		add(makePart(model, root, "Barrel" .. index, Vector3.new(0.16, 0.16, 1.9), DEFAULT_THEME.metal, Enum.Material.Metal, CFrame.new(offset, 0.18, -1.55)), "Metal")
		add(makePart(model, root, "BarrelHeat" .. index, Vector3.new(0.07, 0.07, 0.88), Color3.fromRGB(255, 180, 65), Enum.Material.Neon, CFrame.new(offset, 0.26, -1.42)), "Energy")
	end
	for braceIndex, zPosition in { -1.2, -1.78 } do
		add(makePart(model, root, "BarrelBrace" .. braceIndex, Vector3.new(0.82, 0.14, 0.18), DEFAULT_THEME.trim, Enum.Material.Metal, CFrame.new(0, 0.18, zPosition)), "Trim")
	end
	add(makePart(model, root, "MuzzleShroud", Vector3.new(0.88, 0.5, 0.3), DEFAULT_THEME.polymer, Enum.Material.SmoothPlastic, CFrame.new(0, 0.18, -2.45)), "Polymer")

	for _, position in {
		Vector3.new(-0.57, 0.27, 0.65),
		Vector3.new(-0.57, -0.16, 0.65),
		Vector3.new(-0.57, 0.27, -0.42),
		Vector3.new(0.57, 0.27, -0.42),
	} do
		table.insert(parts, addFastener(model, root, position))
	end

	local muzzle = makePart(model, root, "MuzzleFlash", Vector3.new(0.34, 0.34, 0.34), Color3.fromRGB(255, 180, 65), Enum.Material.Neon, CFrame.new(0, 0.18, -2.72), Enum.PartType.Ball)
	muzzle.LocalTransparencyModifier = 1

	return { model = model, root = root, parts = parts, muzzle = muzzle }
end

local spinfusor = createSpinfusor()
local chaingun = createChaingun()
local viewmodels = {
	Spinfusor = spinfusor,
	Chaingun = chaingun,
}

local function addMuzzleLight(viewmodel: ViewModel)
	if viewmodel.muzzle:FindFirstChild("MuzzleLight") then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "MuzzleLight"
	light.Color = viewmodel.muzzle.Color
	light.Brightness = 2.8
	light.Range = 9
	light.Shadows = false
	light.Enabled = false
	light.Parent = viewmodel.muzzle
end

for _, viewmodel in viewmodels do
	addMuzzleLight(viewmodel)
end

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
		DEFAULT_THEME.trim,
		Enum.Material.Metal,
		localCFrame,
		shape
	)
	part:SetAttribute("ClassOnly", className)
	markFinish(part, "Trim")
	table.insert(viewmodel.parts, part)

	-- Ein kleiner beleuchteter Diagnosepunkt macht den Aufsatz lesbar, ohne
	-- das komplette Bauteil wie eine Neonröhre aussehen zu lassen.
	local indicator = makePart(
		viewmodel.model,
		viewmodel.root,
		name .. "Indicator",
		Vector3.new(0.13, 0.13, 0.13),
		Color3.new(1, 1, 1),
		Enum.Material.Neon,
		localCFrame * CFrame.new(0, size.Y * 0.48 + 0.09, 0),
		Enum.PartType.Ball
	)
	indicator:SetAttribute("ClassOnly", className)
	indicator:SetAttribute("Accent", true)
	markFinish(indicator, "Energy")
	table.insert(viewmodel.parts, indicator)
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

local function addProceduralClassAccessories()
	if not spinfusor.model:GetAttribute("UsesImportedMesh") then
		for className, definition in discAccessories do
			addClassAccessory(spinfusor, className, definition[1], definition[2], definition[3], definition[4])
		end
	end
	if not chaingun.model:GetAttribute("UsesImportedMesh") then
		for className, definition in automaticAccessories do
			addClassAccessory(chaingun, className, definition[1], definition[2], definition[3], definition[4])
		end
	end
end

addProceduralClassAccessories()

local recoil = 0
local meleeSwing = 0
local switchDrop = 1
local flashUntil = 0
local elapsed = 0
local VIEWMODEL_FOV = 85
local smoothedSway = Vector2.zero
local cameraKickPitch = 0
local cameraKickYaw = 0

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
		local partVisible = visible and matchesClass
		part.LocalTransparencyModifier = partVisible and 0 or 1
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceGui") then
				child.Enabled = partVisible
			elseif child:IsA("PointLight") and child.Name == "EnergyGlow" then
				child.Enabled = partVisible
			end
		end
	end
	viewmodel.muzzle.LocalTransparencyModifier = visible and flashVisible and 0 or 1
	local light = viewmodel.muzzle:FindFirstChild("MuzzleLight")
	if light and light:IsA("PointLight") then
		light.Enabled = visible and flashVisible
		light.Color = viewmodel.muzzle.Color
	end
end

local function applyFinish(part: BasePart, theme: WeaponTheme, energyColor: Color3)
	local finishRole = part:GetAttribute("FinishRole")
	if finishRole == "Armor" then
		part.Color = theme.armor
		part.Material = Enum.Material.SmoothPlastic
		part.Reflectance = 0.07
	elseif finishRole == "Polymer" then
		part.Color = theme.polymer
		part.Material = Enum.Material.SmoothPlastic
		part.Reflectance = 0.015
	elseif finishRole == "Metal" then
		part.Color = theme.metal
		if part.Material ~= Enum.Material.DiamondPlate then
			part.Material = Enum.Material.Metal
		end
		part.Reflectance = 0.17
	elseif finishRole == "Trim" then
		part.Color = theme.trim
		part.Material = Enum.Material.Metal
		part.Reflectance = 0.22
	elseif finishRole == "Grip" then
		part.Color = theme.grip
		part.Material = Enum.Material.SmoothPlastic
		part.Reflectance = 0
	elseif finishRole == "Energy" then
		part.Color = energyColor
		part.Material = Enum.Material.Neon
		part.Reflectance = 0
	end

	local glow = part:FindFirstChild("EnergyGlow")
	if glow and glow:IsA("PointLight") then
		glow.Color = energyColor
	end
end

local function updateMarkings(viewmodel: ViewModel, weaponName: string, systemName: string, accentColor: Color3)
	for _, descendant in viewmodel.model:GetDescendants() do
		if descendant:IsA("SurfaceGui") and descendant.Name == "WeaponMarking" then
			local title = descendant:FindFirstChild("Title")
			local serial = descendant:FindFirstChild("Serial")
			local stripe = descendant:FindFirstChild("AccentStripe")
			if title and title:IsA("TextLabel") then
				title.Text = string.upper(weaponName)
			end
			if serial and serial:IsA("TextLabel") then
				serial.Text = systemName
			end
			if stripe and stripe:IsA("Frame") then
				stripe.BackgroundColor3 = accentColor
			end
		end
	end
end

local function applyKitColors()
	local loadout = player:GetAttribute("Loadout")
	local kit = ClassKitConstants.Get(loadout)
	local theme = CLASS_THEMES[loadout] or DEFAULT_THEME
	for _, part in spinfusor.parts do
		applyFinish(part, theme, kit.disc.projectileColor)
	end
	spinfusor.muzzle.Color = kit.disc.projectileColor
	for _, part in chaingun.parts do
		applyFinish(part, theme, kit.automatic.tracerColor)
	end
	chaingun.muzzle.Color = kit.automatic.tracerColor
	updateMarkings(spinfusor, kit.disc.name, string.upper(tostring(loadout)) .. " // DISC", kit.disc.projectileColor)
	updateMarkings(chaingun, kit.automatic.name, string.upper(tostring(loadout)) .. " // KINETIC", kit.automatic.tracerColor)
end

local function rebuildViewmodels()
	local oldSpinfusor = spinfusor
	local oldChaingun = chaingun

	spinfusor = createSpinfusor()
	chaingun = createChaingun()
	viewmodels.Spinfusor = spinfusor
	viewmodels.Chaingun = chaingun
	addMuzzleLight(spinfusor)
	addMuzzleLight(chaingun)
	addProceduralClassAccessories()
	applyKitColors()
	parentToCamera()

	oldSpinfusor.model:Destroy()
	oldChaingun.model:Destroy()
end

WeaponState.Changed:Connect(function()
	switchDrop = 1
end)
player:GetAttributeChangedSignal("Loadout"):Connect(rebuildViewmodels)

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
	cameraKickPitch = math.min(2.8, cameraKickPitch + recoilKick * 1.55)
	cameraKickYaw += (math.random() - 0.5) * recoilKick * 0.7
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
	cameraKickPitch *= math.exp(-16 * dt)
	cameraKickYaw *= math.exp(-18 * dt)

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
	camera.CFrame *= CFrame.Angles(math.rad(-cameraKickPitch), math.rad(cameraKickYaw), 0)

	local cooldownStarted, cooldownDuration = WeaponFeedback.GetCooldown(WeaponState.Get())
	local cooldownProgress = if cooldownDuration > 0
		then math.clamp((os.clock() - cooldownStarted) / cooldownDuration, 0, 1)
		else 1
	local reloadMotion = if cooldownProgress < 1 then math.sin(cooldownProgress * math.pi) else 0

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
			-1.05 - bobY - switchDrop * 0.28 - reloadMotion * 0.11 + smoothedSway.Y * 0.002,
			-3.65 + recoil * 0.13 + reloadMotion * 0.08
		)
		* CFrame.Angles(
			math.rad(recoil * 6 + meleeSwing * 12 - smoothedSway.Y * 0.07),
			math.rad(-2 - meleeSwing * 18 - smoothedSway.X * 0.08 + reloadMotion * 5),
			math.rad(bobX * 20 - meleeSwing * 28 + reloadMotion * 9) + roll
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
