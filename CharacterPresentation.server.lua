-- Server-replicated class armor and third-person weapon silhouettes.
-- Blender FBX files are the production source; these lightweight parts make
-- every class visually distinct immediately, before mesh assets are uploaded.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local LoadoutConstants = require(ReplicatedStorage.Modules.LoadoutConstants)

local COSMETIC_NAME = "CTFCharacterPresentation"

local IMPORTED_WEAPONS = {
	Pathfinder = { disc = "Pathfinder_LightSpinfusor", automatic = "Pathfinder_LightAssaultRifle" },
	Sentinel = { disc = "Sentinel_NovaBlaster", automatic = "Sentinel_BXT1Rifle" },
	Infiltrator = { disc = "Infiltrator_StealthSpinfusor", automatic = "Infiltrator_RhinoSMG" },
	Soldier = { disc = "Soldier_Spinfusor", automatic = "Soldier_AssaultRifle" },
	Technician = { disc = "Technician_Thumper", automatic = "Technician_TCN4SMG" },
	Raider = { disc = "Raider_ARXBuster", automatic = "Raider_NJ5SMG" },
	Juggernaut = { disc = "Juggernaut_HeavySpinfusor", automatic = "Juggernaut_X1LMG" },
	Brute = { disc = "Brute_BruteSpinfusor", automatic = "Brute_AutoShotgun" },
	Doombringer = { disc = "Doombringer_SaberLauncher", automatic = "Doombringer_Chaingun" },
}

local function findBodyPart(character: Model, names: { string }): BasePart?
	for _, name in names do
		local instance = character:FindFirstChild(name)
		if instance and instance:IsA("BasePart") then
			return instance
		end
	end
	return nil
end

local function addPiece(
	model: Model,
	body: BasePart?,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): BasePart?
	if not body then return nil end
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Shape = shape or Enum.PartType.Block
	part.Color = color
	part.Material = material
	part.Reflectance = if material == Enum.Material.Metal then 0.14 else 0
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.CFrame = body.CFrame * localCFrame
	part:SetAttribute("CTFCosmetic", true)
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function addRoundedPiece(
	model: Model,
	body: BasePart?,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	material: Enum.Material
): BasePart?
	local part = addPiece(model, body, name, Vector3.one, localCFrame, color, material)
	if not part then return nil end
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size
	mesh.Parent = part
	return part
end

local function addGlow(part: BasePart?, color: Color3)
	if not part then return end
	local light = Instance.new("PointLight")
	light.Name = "ArmorGlow"
	light.Color = color
	light.Brightness = 0.45
	light.Range = 5
	light.Shadows = false
	light.Parent = part
end

local function addImportedWorldWeapon(model: Model, hand: BasePart?, loadoutId: string, automatic: boolean): boolean
	if not hand then return false end
	local weaponAssets = ReplicatedStorage:FindFirstChild("WeaponAssets")
	local names = IMPORTED_WEAPONS[loadoutId]
	local assetName = names and names[if automatic then "automatic" else "disc"]
	local template = weaponAssets and assetName and weaponAssets:FindFirstChild(assetName, true)
	if not template and not automatic and weaponAssets then template = weaponAssets:FindFirstChild("Spinfusor") end
	if not template or (not template:IsA("Model") and not template:IsA("BasePart")) then return false end

	local visual = template:Clone()
	visual.Name = "ImportedWorldWeapon"
	visual.Parent = model
	local bounds = if visual:IsA("Model") then visual:GetExtentsSize() else visual.Size
	local longest = math.max(bounds.X, bounds.Y, bounds.Z)
	if longest <= 0 then visual:Destroy(); return false end
	local scale = (if automatic then 2.6 else 2.35) / longest
	local target = hand.CFrame * CFrame.new(0, -0.1, -0.9)
	if visual:IsA("Model") then
		visual:ScaleTo(scale)
		visual:PivotTo(target)
	else
		visual.Size *= scale
		visual.CFrame = target
	end

	local partCount = 0
	local function bindPart(part: BasePart)
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = part
		weld.Parent = part
		partCount += 1
	end
	if visual:IsA("BasePart") then bindPart(visual) end
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then bindPart(descendant) end
	end
	if partCount == 0 then visual:Destroy(); return false end
	return true
end

local function buildPresentation(player: Player, character: Model)
	local old = character:FindFirstChild(COSMETIC_NAME)
	if old then old:Destroy() end
	if player.Character ~= character or not character.Parent then return end

	local loadoutId = player:GetAttribute("Loadout")
	local definition = LoadoutConstants.LOADOUTS[loadoutId] or LoadoutConstants.LOADOUTS[LoadoutConstants.DEFAULT_LOADOUT]
	local kit = ClassKitConstants.Get(loadoutId)
	local teamName = if player.Team then string.lower(player.Team.Name) else ""
	local teamColor = if player.Team then player.Team.TeamColor.Color else Color3.fromRGB(70, 190, 255)
	local emberBrood = string.find(teamName, "red", 1, true) ~= nil or teamColor.R > teamColor.B
	local faction = if emberBrood then "EmberBrood" else "CryoRevenant"
	local factionGlow = if emberBrood then Color3.fromRGB(255, 55, 9) else Color3.fromRGB(42, 220, 255)
	local accent = factionGlow
	local secondary = kit.disc.projectileColor:Lerp(factionGlow, 0.68)
	local graphite = if emberBrood then Color3.fromRGB(17, 3, 5) else Color3.fromRGB(5, 16, 25)
	local steel = if emberBrood then Color3.fromRGB(76, 16, 13) else Color3.fromRGB(56, 86, 101)
	local heavy = definition.armor == "HEAVY"
	local medium = definition.armor == "MEDIUM"
	local scale = if heavy then 1.18 elseif medium then 1.04 else 0.9

	local model = Instance.new("Model")
	model.Name = COSMETIC_NAME
	model:SetAttribute("Loadout", tostring(loadoutId))
	model:SetAttribute("ArmorClass", definition.armor)
	model:SetAttribute("Faction", faction)
	model.Parent = character

	local head = findBodyPart(character, { "Head" })
	local torso = findBodyPart(character, { "UpperTorso", "Torso" })
	local lowerTorso = findBodyPart(character, { "LowerTorso", "Torso" })
	local leftArm = findBodyPart(character, { "LeftUpperArm", "Left Arm" })
	local rightArm = findBodyPart(character, { "RightUpperArm", "Right Arm" })
	local leftLowerArm = findBodyPart(character, { "LeftLowerArm", "Left Arm" })
	local rightLowerArm = findBodyPart(character, { "RightLowerArm", "Right Arm" })
	local leftUpperLeg = findBodyPart(character, { "LeftUpperLeg", "Left Leg" })
	local rightUpperLeg = findBodyPart(character, { "RightUpperLeg", "Right Leg" })
	local leftLeg = findBodyPart(character, { "LeftLowerLeg", "Left Leg" })
	local rightLeg = findBodyPart(character, { "RightLowerLeg", "Right Leg" })
	local rightHand = findBodyPart(character, { "RightHand", "Right Arm" })

	if emberBrood then
		addPiece(model, head, "AlienCranium", Vector3.new(1.78, 1.28, 1.56) * scale, CFrame.new(0, 0.15, 0.18), graphite, Enum.Material.Metal, Enum.PartType.Ball)
		addPiece(model, head, "CrownCarapace", Vector3.new(0.58, 0.72, 0.92) * scale, CFrame.new(0, 0.63 * scale, 0.26), steel, Enum.Material.Metal)
		for side = -1, 1, 2 do
			local eye = addPiece(model, head, "HiveEye" .. side, Vector3.new(0.25, 0.20, 0.13) * scale, CFrame.new(side * 0.29 * scale, 0.08, -0.70 * scale), accent, Enum.Material.Neon, Enum.PartType.Ball)
			addGlow(eye, accent)
			addPiece(model, head, "Mandible" .. side, Vector3.new(0.18, 0.48, 0.22) * scale, CFrame.new(side * 0.31 * scale, -0.42, -0.58 * scale) * CFrame.Angles(0, 0, math.rad(side * 22)), steel, Enum.Material.Metal)
		end
		for layer = 0, 3 do
			local width = (2.18 - layer * 0.18) * scale
			addRoundedPiece(model, torso, "ThoraxPlate" .. layer, Vector3.new(width, 0.36, 0.38) * scale, CFrame.new(0, 0.42 - layer * 0.27, -0.64 * scale), graphite:Lerp(steel, 0.42), Enum.Material.Metal)
		end
		addRoundedPiece(model, torso, "DorsalCarapace", Vector3.new(1.92, 1.48, 0.42) * scale, CFrame.new(0, 0, 0.64 * scale), graphite, Enum.Material.Metal)
		for segment = 0, 3 do
			addRoundedPiece(model, lowerTorso, "LivingAbdomen" .. segment, Vector3.new(1.20 - segment * 0.10, 0.25, 0.34) * scale, CFrame.new(0, 0.38 - segment * 0.22, -0.52 * scale), steel, Enum.Material.Metal)
		end
	else
		addPiece(model, head, "MechanicalSkull", Vector3.new(1.58, 1.02, 1.50) * scale, CFrame.new(0, 0.12, 0.02), steel, Enum.Material.Metal, Enum.PartType.Ball)
		addPiece(model, head, "Jaw", Vector3.new(0.92, 0.34, 0.34) * scale, CFrame.new(0, -0.43, -0.36 * scale), graphite, Enum.Material.Metal)
		for side = -1, 1, 2 do
			local eye = addPiece(model, head, "SoulEye" .. side, Vector3.new(0.25, 0.20, 0.12) * scale, CFrame.new(side * 0.25 * scale, 0.10, -0.62 * scale), accent, Enum.Material.Neon)
			addGlow(eye, accent)
		end
		addPiece(model, torso, "Sternum", Vector3.new(0.20, 1.26, 0.20) * scale, CFrame.new(0, 0, -0.68 * scale), accent, Enum.Material.Neon)
		for rib = 0, 4 do
			local width = (1.86 - rib * 0.13) * scale
			addRoundedPiece(model, torso, "Rib" .. rib, Vector3.new(width, 0.17, 0.20) * scale, CFrame.new(0, 0.48 - rib * 0.24, -0.62 * scale), steel, Enum.Material.Metal)
		end
		for vertebra = 0, 4 do
			addPiece(model, torso, "Spine" .. vertebra, Vector3.new(0.31, 0.20, 0.24) * scale, CFrame.new(0, 0.48 - vertebra * 0.24, 0.58 * scale), graphite, Enum.Material.Metal)
		end
		addRoundedPiece(model, lowerTorso, "BonePelvis", Vector3.new(1.46, 0.70, 0.36) * scale, CFrame.new(0, 0.05, -0.51 * scale), steel, Enum.Material.Metal)
	end
	local core = addPiece(model, torso, if emberBrood then "MoltenHeart" else "FrozenHeart", Vector3.new(0.44, 0.56, 0.16) * scale, CFrame.new(0, 0, -0.84 * scale), secondary, Enum.Material.Neon, Enum.PartType.Ball)
	addGlow(core, secondary)

	for _, entry in { { -1, leftArm }, { 1, rightArm } } do
		local side, arm = entry[1], entry[2]
		addPiece(model, arm, if side < 0 then "LeftPauldron" else "RightPauldron", Vector3.new(if emberBrood then 0.88 else 0.72, 0.64, 0.82) * scale, CFrame.new(0, 0.32, 0), if emberBrood then graphite else steel, Enum.Material.Metal, Enum.PartType.Ball)
		addRoundedPiece(model, arm, if side < 0 then "LeftBicep" else "RightBicep", Vector3.new(0.66, 1.02, 0.66) * scale, CFrame.new(0, -0.15, 0), graphite:Lerp(accent, 0.12), Enum.Material.Metal)
		if emberBrood then
			addPiece(model, arm, "ShoulderSpike" .. side, Vector3.new(0.18, 0.18, if heavy then 0.92 else 0.64) * scale, CFrame.new(side * 0.46, 0.45, 0) * CFrame.Angles(0, math.rad(side * 45), 0), steel, Enum.Material.Metal)
		end
	end
	for _, entry in { { -1, leftLowerArm }, { 1, rightLowerArm } } do
		local side, arm = entry[1], entry[2]
		addRoundedPiece(model, arm, if side < 0 then "LeftGauntlet" else "RightGauntlet", Vector3.new(0.66, 0.84, 0.62) * scale, CFrame.new(), graphite, Enum.Material.Metal)
	end
	for _, entry in { { -1, leftUpperLeg }, { 1, rightUpperLeg } } do
		local side, leg = entry[1], entry[2]
		addRoundedPiece(model, leg, if side < 0 then "LeftThigh" else "RightThigh", Vector3.new(0.82, 1.18, 0.74) * scale, CFrame.new(), steel:Lerp(accent, 0.16), Enum.Material.Metal)
	end
	for _, entry in { { -1, leftLeg }, { 1, rightLeg } } do
		local side, leg = entry[1], entry[2]
		addRoundedPiece(model, leg, if side < 0 then "LeftShin" else "RightShin", Vector3.new(0.70, 1.08, 0.48) * scale, CFrame.new(0, 0, -0.30 * scale), graphite:Lerp(accent, 0.28), Enum.Material.Metal)
		addRoundedPiece(model, leg, if side < 0 then "LeftBoot" else "RightBoot", Vector3.new(0.78, 0.62, 1.02) * scale, CFrame.new(0, -0.48, -0.18), graphite, Enum.Material.Metal)
	end

	for side = -1, 1, 2 do
		local nozzle = addPiece(model, torso, "JetNozzle" .. side, Vector3.new(0.32, 0.32, 0.82) * scale, CFrame.new(side * 0.48 * scale, -0.18, 0.88 * scale) * CFrame.Angles(math.rad(90), 0, 0), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
		local glow = addPiece(model, torso, "JetGlow" .. side, Vector3.new(0.20, 0.20, 0.10) * scale, CFrame.new(side * 0.48 * scale, -0.55, 0.94 * scale) * CFrame.Angles(math.rad(90), 0, 0), accent, Enum.Material.Neon, Enum.PartType.Cylinder)
		if nozzle then nozzle:SetAttribute("JetNozzle", true) end
		addGlow(glow, accent)
	end

	-- Class identity modules mirror the Blender production pack.
	if loadoutId == "Pathfinder" then
		for side = -1, 1, 2 do
			addPiece(model, torso, "AeroFin" .. side, Vector3.new(0.14, 1.05, 0.72), CFrame.new(side * 0.85, 0, 0.66) * CFrame.Angles(0, math.rad(side * 16), 0), accent, Enum.Material.Metal)
		end
	elseif loadoutId == "Sentinel" then
		addPiece(model, head, "Rangefinder", Vector3.new(0.30, 0.30, 0.78), CFrame.new(0.72, 0.22, -0.16) * CFrame.Angles(math.rad(90), 0, 0), secondary, Enum.Material.Neon, Enum.PartType.Cylinder)
	elseif loadoutId == "Infiltrator" then
		for index = -2, 2 do
			addPiece(model, torso, "CloakNode" .. index, Vector3.new(0.18, 0.18, 0.12), CFrame.new(index * 0.30, -0.48, -0.82), accent, Enum.Material.Neon)
		end
	elseif loadoutId == "Technician" then
		addPiece(model, torso, "RepairPack", Vector3.new(1.20, 1.15, 0.55), CFrame.new(0, 0, 0.90), accent, Enum.Material.Metal)
	elseif loadoutId == "Raider" then
		for side = -1, 1, 2 do
			addPiece(model, torso, "EMPCoil" .. side, Vector3.new(0.44, 0.44, 0.18), CFrame.new(side * 0.68, 0, -0.70) * CFrame.Angles(math.rad(90), 0, 0), accent, Enum.Material.Neon, Enum.PartType.Cylinder)
		end
	elseif loadoutId == "Juggernaut" then
		addPiece(model, torso, "SiegeReactor", Vector3.new(0.72, 0.72, 0.36), CFrame.new(0, 0, 0.86), accent, Enum.Material.Neon, Enum.PartType.Ball)
	elseif loadoutId == "Brute" then
		addPiece(model, torso, "RamPlate", Vector3.new(2.50, 0.48, 0.34), CFrame.new(0, 0.42, -0.75), accent, Enum.Material.Metal)
	elseif loadoutId == "Doombringer" then
		for side = -1, 1, 2 do
			addPiece(model, torso, "ShieldEmitter" .. side, Vector3.new(0.52, 0.52, 0.20), CFrame.new(side * 0.72, 0, -0.70) * CFrame.Angles(math.rad(90), 0, 0), secondary, Enum.Material.Neon, Enum.PartType.Cylinder)
		end
	end

	-- Compact third-person weapon; first-person still uses WeaponViewmodel.
	local automatic = player:GetAttribute("EquippedWeapon") == "Chaingun"
	local weaponColor = if automatic then kit.automatic.tracerColor else kit.disc.projectileColor
	local weaponName = if automatic then kit.automatic.name else kit.disc.name
	if not addImportedWorldWeapon(model, rightHand, tostring(loadoutId), automatic) then
		local weaponBody = addRoundedPiece(model, rightHand, "WorldWeapon", if automatic then Vector3.new(0.64, 0.68, 2.45) else Vector3.new(0.82, 0.76, 2.15), CFrame.new(0, -0.10, -0.92), graphite, Enum.Material.Metal)
		if weaponBody then weaponBody:SetAttribute("WeaponName", weaponName) end
		addPiece(model, rightHand, "WorldWeaponAccent", Vector3.new(0.16, 0.22, 1.35), CFrame.new(0.34, 0.10, -0.98), weaponColor, Enum.Material.Neon)
	end

	-- The original avatar remains the physics skeleton, but no longer defines
	-- the silhouette. This removes the blocky Roblox body while preserving all
	-- humanoid replication, hit detection and attachments.
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") then
			child.Transparency = 1
			child.CastShadow = false
		elseif child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Transparency = 1
				handle.CastShadow = false
			end
		end
	end
end

local function setupPlayer(player: Player)
	local generation = 0
	local function rebuild()
		generation += 1
		local expected = generation
		local character = player.Character
		if not character then return end
		task.defer(function()
			character:WaitForChild("Humanoid", 8)
			if expected == generation and player.Character == character then
				buildPresentation(player, character)
			end
		end)
	end
	player.CharacterAdded:Connect(rebuild)
	player:GetAttributeChangedSignal("Loadout"):Connect(rebuild)
	player:GetAttributeChangedSignal("EquippedWeapon"):Connect(rebuild)
	if player.Character then rebuild() end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end
