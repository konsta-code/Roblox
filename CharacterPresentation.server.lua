-- Server-replicated class armor and third-person weapon silhouettes.
-- Blender FBX files are the production source; these lightweight parts make
-- every class visually distinct immediately, before mesh assets are uploaded.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local LoadoutConstants = require(ReplicatedStorage.Modules.LoadoutConstants)

local COSMETIC_NAME = "CTFCharacterPresentation"

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

local function buildPresentation(player: Player, character: Model)
	local old = character:FindFirstChild(COSMETIC_NAME)
	if old then old:Destroy() end
	if player.Character ~= character or not character.Parent then return end

	local loadoutId = player:GetAttribute("Loadout")
	local definition = LoadoutConstants.LOADOUTS[loadoutId] or LoadoutConstants.LOADOUTS[LoadoutConstants.DEFAULT_LOADOUT]
	local kit = ClassKitConstants.Get(loadoutId)
	local accent = kit.disc.projectileColor
	local secondary = kit.automatic.tracerColor
	local graphite = Color3.fromRGB(19, 27, 38)
	local steel = Color3.fromRGB(72, 84, 98)
	local heavy = definition.armor == "HEAVY"
	local medium = definition.armor == "MEDIUM"
	local scale = if heavy then 1.18 elseif medium then 1.04 else 0.9

	local model = Instance.new("Model")
	model.Name = COSMETIC_NAME
	model:SetAttribute("Loadout", tostring(loadoutId))
	model:SetAttribute("ArmorClass", definition.armor)
	model.Parent = character

	local head = findBodyPart(character, { "Head" })
	local torso = findBodyPart(character, { "UpperTorso", "Torso" })
	local lowerTorso = findBodyPart(character, { "LowerTorso", "Torso" })
	local leftArm = findBodyPart(character, { "LeftUpperArm", "Left Arm" })
	local rightArm = findBodyPart(character, { "RightUpperArm", "Right Arm" })
	local leftLowerArm = findBodyPart(character, { "LeftLowerArm", "Left Arm" })
	local rightLowerArm = findBodyPart(character, { "RightLowerArm", "Right Arm" })
	local leftLeg = findBodyPart(character, { "LeftLowerLeg", "Left Leg" })
	local rightLeg = findBodyPart(character, { "RightLowerLeg", "Right Leg" })
	local rightHand = findBodyPart(character, { "RightHand", "Right Arm" })

	addPiece(model, head, "HelmetShell", Vector3.new(1.72, 1.08, 1.58) * scale, CFrame.new(0, 0.12, 0.04), graphite, Enum.Material.Metal, Enum.PartType.Ball)
	local visor = addPiece(model, head, "Visor", Vector3.new(1.40, 0.38, 0.18) * scale, CFrame.new(0, 0.05, -0.62 * scale), accent, Enum.Material.Neon)
	addGlow(visor, accent)
	addPiece(model, head, "HelmetCrest", Vector3.new(0.34, 0.22, 0.78) * scale, CFrame.new(0, 0.68 * scale, 0.08), secondary, Enum.Material.Metal)

	addPiece(model, torso, "ChestPlate", Vector3.new(2.15, 1.45, 0.28) * scale, CFrame.new(0, 0, -0.62 * scale), accent, Enum.Material.Metal)
	addPiece(model, torso, "BackPlate", Vector3.new(1.84, 1.35, 0.32) * scale, CFrame.new(0, 0, 0.62 * scale), graphite, Enum.Material.Metal)
	local core = addPiece(model, torso, "ChestCore", Vector3.new(0.42, 0.56, 0.14) * scale, CFrame.new(0, 0, -0.80 * scale), secondary, Enum.Material.Neon)
	addGlow(core, secondary)
	addPiece(model, lowerTorso, "AbdomenPlate", Vector3.new(1.35, 0.70, 0.28) * scale, CFrame.new(0, 0.05, -0.55 * scale), steel, Enum.Material.Metal)

	for _, entry in { { -1, leftArm }, { 1, rightArm } } do
		local side, arm = entry[1], entry[2]
		addPiece(model, arm, if side < 0 then "LeftPauldron" else "RightPauldron", Vector3.new(0.78, 0.64, 0.82) * scale, CFrame.new(0, 0.32, 0), accent, Enum.Material.Metal, Enum.PartType.Ball)
	end
	for _, entry in { { -1, leftLowerArm }, { 1, rightLowerArm } } do
		local side, arm = entry[1], entry[2]
		addPiece(model, arm, if side < 0 then "LeftGauntlet" else "RightGauntlet", Vector3.new(0.62, 0.82, 0.58) * scale, CFrame.new(), graphite, Enum.Material.Metal)
	end
	for _, entry in { { -1, leftLeg }, { 1, rightLeg } } do
		local side, leg = entry[1], entry[2]
		addPiece(model, leg, if side < 0 then "LeftShin" else "RightShin", Vector3.new(0.66, 1.05, 0.42) * scale, CFrame.new(0, 0, -0.30 * scale), accent, Enum.Material.Metal)
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
	local weaponBody = addPiece(model, rightHand, "WorldWeapon", if automatic then Vector3.new(0.56, 0.62, 2.45) else Vector3.new(0.78, 0.72, 2.15), CFrame.new(0, -0.10, -0.92), graphite, Enum.Material.Metal)
	if weaponBody then weaponBody:SetAttribute("WeaponName", weaponName) end
	addPiece(model, rightHand, "WorldWeaponAccent", Vector3.new(0.16, 0.22, 1.35), CFrame.new(0.34, 0.10, -0.98), weaponColor, Enum.Material.Neon)
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
