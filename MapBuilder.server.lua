-- MapBuilder.server.lua
-- Ablageort: ServerScriptService (via Rojo)
--
-- ITERATIONS-HELFER: baut die Tribes-Map beim Server-Start automatisch, damit
-- wir beim Testen nicht jedes Mal von Hand über die Befehlsleiste bauen müssen.
-- Setzt außerdem workspace.Gravity = 0 (der Movement-Controller bringt seine
-- eigene Gravitation mit).
--
-- Sobald das Map-Design final ist: Map einmal in Studio "backen" (Befehlsleiste
-- im Edit-Mode) und dieses Script entfernen - dann liegt die Geometrie fest im
-- Place, statt bei jedem Start neu erzeugt zu werden.
--
-- Layout (spiegelsymmetrisch, X = Basis-zu-Basis-Achse):
--   Basis(24) -> Abfahrt -> Tal(0) + Sprungschanze -> Zentralkamm(28) ->
--   Tal(0) + Sprungschanze -> Abfahrt -> Basis(24)
-- Das Haupt-Terrain ist EINE bündig verbundene Fläche (keine Momentum-Nähte).

local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")

workspace.Gravity = 0

-- Alte/überlappende Geometrie wegräumen (Default-Baseplate + frühere Builds)
for _, name in { "Baseplate", "TestArena", "TribesMap", "TribesMapV2", "TribesMapLive" } do
	local old = workspace:FindFirstChild(name)
	if old then old:Destroy() end
end

local map = Instance.new("Folder")
map.Name = "TribesMapLive"
map.Parent = workspace

-- ============================================================
-- FARBEN
-- ============================================================
local COL_ROCK = Color3.fromRGB(96, 102, 108)
local COL_ICE = Color3.fromRGB(168, 196, 220)
local COL_SNOW = Color3.fromRGB(224, 230, 236)
local COL_METAL = Color3.fromRGB(88, 94, 102)
local COL_DARK = Color3.fromRGB(42, 46, 54)
local COL_RED = Color3.fromRGB(170, 52, 52)
local COL_BLUE = Color3.fromRGB(52, 88, 172)
local COL_STEEL = Color3.fromRGB(28, 36, 49)
local COL_WARM_ROCK = Color3.fromRGB(113, 101, 94)

-- ============================================================
-- HELFER
-- ============================================================
local function slab(name, size, cframe, color, material, parent, canCollide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = if canCollide == nil then true else canCollide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Rampe/Fläche, deren OBERKANTE exakt von (x0,y0) nach (x1,y1) läuft (entlang
-- X, Breite in Z). Aneinandergereiht mit geteilten Endpunkten docken die
-- Oberflächen lücken- und stufenlos an.
local function skiRamp(name, x0, y0, x1, y1, width, zCenter, color, material, parent, thickness)
	local run = x1 - x0
	local rise = y1 - y0
	local length = math.sqrt(run * run + rise * rise)
	local theta = math.atan2(rise, run)
	thickness = thickness or 90

	local midX = (x0 + x1) / 2
	local midY = (y0 + y1) / 2
	local cx = midX + (thickness / 2) * math.sin(theta)
	local cy = midY - (thickness / 2) * math.cos(theta)

	return slab(
		name,
		Vector3.new(length, thickness, width),
		CFrame.new(cx, cy, zCenter) * CFrame.Angles(0, 0, theta),
		color,
		material,
		parent,
		true
	)
end

-- ============================================================
-- 1. BODEN (Fangfläche, verhindert Endlos-Fall am Start)
-- ============================================================
slab("Ground", Vector3.new(820, 60, 320), CFrame.new(0, -30, 0), COL_ROCK, Enum.Material.Rock, map, true)

-- ============================================================
-- 2. HAUPT-TERRAIN (durchgehende Ski-Fläche, Breite 240)
-- ============================================================
local terrain = Instance.new("Folder")
terrain.Name = "Terrain"
terrain.Parent = map

local W = 240
skiRamp("L1_BaseDescent", -230, 24, -150, 2, W, 0, COL_ICE, Enum.Material.Ice, terrain)
skiRamp("L2_Valley", -150, 2, -80, 0, W, 0, COL_SNOW, Enum.Material.Snow, terrain)
skiRamp("L3_RidgeClimb", -80, 0, 0, 28, W, 0, COL_ICE, Enum.Material.Ice, terrain)
skiRamp("R3_RidgeDrop", 0, 28, 80, 0, W, 0, COL_ICE, Enum.Material.Ice, terrain)
skiRamp("R2_Valley", 80, 0, 150, 2, W, 0, COL_SNOW, Enum.Material.Snow, terrain)
skiRamp("R1_BaseAscent", 150, 2, 230, 24, W, 0, COL_ICE, Enum.Material.Ice, terrain)

-- ============================================================
-- 3. SPRUNGSCHANZEN (in den Tälern, schmaler -> optional anfahrbar)
-- Kurze steile Rampen auf dem Talboden: mit Ski-Speed drauf = Absprung nach
-- oben Richtung Mitte, ideal um Jetpack-/Disc-Jump-Höhe mitzunehmen.
-- ============================================================
local kickers = Instance.new("Folder")
kickers.Name = "Kickers"
kickers.Parent = map

skiRamp("LeftKicker", -135, 1.5, -120, 10, 70, 0, COL_SNOW, Enum.Material.Glacier, kickers, 14)
skiRamp("RightKicker", 135, 1.5, 120, 10, 70, 0, COL_SNOW, Enum.Material.Glacier, kickers, 14)

-- ============================================================
-- 4. CANYON-SILHOUETTE UND ROUTENLICHTER
-- Die Felsen stehen ausserhalb der Ski-Flaeche. Die kleineren Leuchten sind
-- nicht kollidierbar, damit sie bei hoher Geschwindigkeit keine Route stoppen.
-- ============================================================
local scenery = Instance.new("Folder")
scenery.Name = "CanyonScenery"
scenery.Parent = map

local spires = {
	{ -215, -146, 38, -12 },
	{ -174, 145, 54, 9 },
	{ -126, -147, 42, 15 },
	{ -72, 146, 62, -7 },
	{ -18, -145, 48, 11 },
	{ 38, 146, 58, -13 },
	{ 91, -146, 46, 7 },
	{ 146, 145, 66, -10 },
	{ 204, -147, 51, 12 },
}

for index, definition in spires do
	local x, z, height, lean = definition[1], definition[2], definition[3], definition[4]
	local spire = slab(
		"CanyonSpire" .. index,
		Vector3.new(22, height, 27),
		CFrame.new(x, height / 2, z) * CFrame.Angles(0, math.rad(index * 23), math.rad(lean)),
		if index % 2 == 0 then COL_WARM_ROCK else COL_ROCK,
		Enum.Material.Rock,
		scenery,
		true
	)
	spire.CastShadow = true

	slab(
		"SnowCap" .. index,
		Vector3.new(16, 4, 21),
		spire.CFrame * CFrame.new(0, height / 2 - 1, 0),
		COL_SNOW,
		Enum.Material.Snow,
		scenery,
		false
	)
end

local routeLights = Instance.new("Folder")
routeLights.Name = "RouteLights"
routeLights.Parent = scenery

for x = -200, 200, 40 do
	for _, z in { -112, 112 } do
		local teamColor = if x < 0 then COL_RED elseif x > 0 then COL_BLUE else Color3.fromRGB(105, 232, 255)
		local post = slab(
			string.format("RouteLight_%d_%d", x, z),
			Vector3.new(1, 5, 1),
			CFrame.new(x, 9 + math.abs(x) * 0.045, z),
			COL_STEEL,
			Enum.Material.Metal,
			routeLights,
			false
		)
		post.CanQuery = false

		local beacon = slab(
			"Beacon",
			Vector3.new(1.4, 1.4, 1.4),
			post.CFrame * CFrame.new(0, 3, 0),
			teamColor,
			Enum.Material.Neon,
			routeLights,
			false
		)
		beacon.Shape = Enum.PartType.Ball
		beacon.CanQuery = false

		local light = Instance.new("PointLight")
		light.Color = teamColor
		light.Brightness = 1.35
		light.Range = 14
		light.Shadows = false
		light.Parent = beacon
	end
end

for _, z in { -103, 103 } do
	local monument = slab(
		"MidfieldMonument",
		Vector3.new(7, 24, 7),
		CFrame.new(0, 30, z) * CFrame.Angles(0, math.rad(45), math.rad(if z < 0 then -7 else 7)),
		COL_STEEL,
		Enum.Material.Metal,
		scenery,
		false
	)
	monument.CanQuery = false
	local core = slab(
		"MidfieldCore",
		Vector3.new(2.2, 15, 2.2),
		monument.CFrame,
		Color3.fromRGB(100, 223, 255),
		Enum.Material.Neon,
		scenery,
		false
	)
	core.CanQuery = false
end

-- ============================================================
-- 5. BASEN (Red -262, Blue +262)
-- ============================================================
local baseSetups = {
	{ teamName = "Red", brick = BrickColor.new("Bright red"), sign = -1, col = COL_RED },
	{ teamName = "Blue", brick = BrickColor.new("Bright blue"), sign = 1, col = COL_BLUE },
}

for _, setup in baseSetups do
	local team = Teams:FindFirstChild(setup.teamName)
	if not team then
		warn("MapBuilder: Team \"" .. setup.teamName .. "\" fehlt - in Teams-Service anlegen")
		continue
	end
	team.TeamColor = setup.brick
	team.AutoAssignable = true

	local base = Instance.new("Folder")
	base.Name = setup.teamName .. "Base"
	base.Parent = map

	local s = setup.sign
	local baseX = 262 * s
	local facing = -s -- Richtung Mitte

	slab("Platform", Vector3.new(70, 8, 96), CFrame.new(baseX, 20, 0), setup.col, Enum.Material.Metal, base, true)
	slab("BackWall", Vector3.new(4, 26, 96), CFrame.new(baseX - facing * 33, 37, 0), COL_DARK, Enum.Material.Metal, base, true)
	slab("SideWallA", Vector3.new(70, 16, 4), CFrame.new(baseX, 32, -46), COL_DARK, Enum.Material.Metal, base, true)
	slab("SideWallB", Vector3.new(70, 16, 4), CFrame.new(baseX, 32, 46), COL_DARK, Enum.Material.Metal, base, true)
	slab("Roof", Vector3.new(48, 2, 64), CFrame.new(baseX - facing * 8, 45, 0), COL_METAL, Enum.Material.Metal, base, true)
	local generatorRoom = slab(
		"GeneratorRoom",
		Vector3.new(22, 12, 28),
		CFrame.new(baseX - facing * 14, 30, 0),
		COL_DARK,
		Enum.Material.Glass,
		base,
		false
	)
	generatorRoom.Transparency = 0.72
	generatorRoom.CanQuery = false

	local generator = slab(
		"PowerGenerator",
		Vector3.new(7, 7, 7),
		CFrame.new(baseX - facing * 14, 29, 0),
		setup.col,
		Enum.Material.Neon,
		base,
		true
	)
	generator.Shape = Enum.PartType.Ball
	generator:SetAttribute("Team", setup.teamName)
	CollectionService:AddTag(generator, "PowerGenerator")
	local generatorLight = Instance.new("PointLight")
	generatorLight.Color = setup.col
	generatorLight.Brightness = 2.4
	generatorLight.Range = 28
	generatorLight.Shadows = true
	generatorLight.Parent = generator

	local inventoryStation = slab(
		"InventoryStation",
		Vector3.new(5, 6, 3),
		CFrame.new(baseX - facing * 7, 27, 27),
		setup.col,
		Enum.Material.Neon,
		base,
		true
	)
	inventoryStation:SetAttribute("Team", setup.teamName)
	CollectionService:AddTag(inventoryStation, "InventoryStation")

	local turret = slab(
		"BaseTurret",
		Vector3.new(2.4, 2.4, 6),
		CFrame.new(baseX + facing * 4, 49, 0),
		setup.col,
		Enum.Material.Metal,
		base,
		false
	)
	turret:SetAttribute("Team", setup.teamName)
	CollectionService:AddTag(turret, "BaseTurret")

	for _, railZ in { -38, 38 } do
		local rail = slab(
			"EnergyRail",
			Vector3.new(42, 0.55, 0.55),
			CFrame.new(baseX + facing * 9, 25.1, railZ),
			setup.col,
			Enum.Material.Neon,
			base,
			false
		)
		rail.CanQuery = false
	end

	local identityPanel = slab(
		"TeamIdentityPanel",
		Vector3.new(0.5, 9, 34),
		CFrame.new(baseX - facing * 30.7, 37, 0),
		setup.col,
		Enum.Material.Neon,
		base,
		false
	)
	identityPanel.CanQuery = false
	local identity = Instance.new("BillboardGui")
	identity.Name = "TeamIdentity"
	identity.Size = UDim2.fromOffset(260, 64)
	identity.StudsOffset = Vector3.new(facing * 1.5, 0, 0)
	identity.AlwaysOnTop = false
	identity.MaxDistance = 220
	identity.Parent = identityPanel
	local identityText = Instance.new("TextLabel")
	identityText.BackgroundTransparency = 1
	identityText.Size = UDim2.fromScale(1, 1)
	identityText.Font = Enum.Font.GothamBlack
	identityText.Text = string.upper(setup.teamName .. " // TRIBAL BASE")
	identityText.TextColor3 = Color3.fromRGB(240, 247, 255)
	identityText.TextScaled = true
	identityText.TextStrokeTransparency = 0.35
	identityText.Parent = identity

	-- Flaggen-Stand: vorne am Plattformrand zur Mitte, direkt über dem Kopf der
	-- Grab-Rampe -> schneller Capper fährt sie hoch und grabbt im Vorbeiflug
	local flagX = baseX + facing * 28
	local flagStand =
		slab("FlagStand", Vector3.new(5, 1.5, 5), CFrame.new(flagX, 24.75, 0), Color3.fromRGB(240, 240, 240), Enum.Material.Neon, base, true)
	flagStand:SetAttribute("Team", setup.teamName)
	CollectionService:AddTag(flagStand, "FlagStand")
	slab("FlagPole", Vector3.new(0.6, 14, 0.6), CFrame.new(flagX, 31, 0), Color3.fromRGB(180, 180, 180), Enum.Material.Metal, base, false)

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = setup.teamName .. "SpawnLocation"
	spawnLocation.Size = Vector3.new(16, 1, 16)
	spawnLocation.CFrame = CFrame.new(baseX - facing * 6, 24.5, -26)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = false
	spawnLocation.TeamColor = setup.brick
	spawnLocation.Transparency = 0.5
	spawnLocation.Color = setup.col
	spawnLocation.Material = Enum.Material.Metal
	spawnLocation.Parent = base

	for i = 1, 4 do
		local sx = baseX - facing * 6 + (i - 2.5) * 9
		local spawnTag = Instance.new("Part")
		spawnTag.Name = setup.teamName .. "PlayerSpawn" .. i
		spawnTag.Size = Vector3.new(4, 1, 4)
		spawnTag.CFrame = CFrame.new(sx, 24.5, -26)
		spawnTag.Anchored = true
		spawnTag.CanCollide = false
		spawnTag.Transparency = 1
		spawnTag:SetAttribute("Team", setup.teamName)
		spawnTag.Parent = base
		CollectionService:AddTag(spawnTag, "PlayerSpawn")
	end
end

-- ============================================================
-- 6. DEZENTER HOEHENSCHNEE
-- Ein einzelner Emitter ist deutlich guenstiger als viele lokale Systeme.
-- ============================================================
local snowVolume = slab(
	"SnowVolume",
	Vector3.new(650, 1, 250),
	CFrame.new(0, 112, 0),
	Color3.new(1, 1, 1),
	Enum.Material.SmoothPlastic,
	map,
	false
)
snowVolume.Transparency = 1
snowVolume.CanQuery = false
snowVolume.CastShadow = false

local snow = Instance.new("ParticleEmitter")
snow.Name = "AlpineSnow"
snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
snow.Rate = 55
snow.Lifetime = NumberRange.new(7, 10)
snow.Speed = NumberRange.new(1, 3)
snow.Acceleration = Vector3.new(2, -4.5, 0)
snow.Drag = 0.35
snow.EmissionDirection = Enum.NormalId.Bottom
snow.SpreadAngle = Vector2.new(180, 180)
snow.Rotation = NumberRange.new(0, 360)
snow.RotSpeed = NumberRange.new(-35, 35)
snow.LightEmission = 0.42
snow.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.09),
	NumberSequenceKeypoint.new(0.5, 0.16),
	NumberSequenceKeypoint.new(1, 0.04),
})
snow.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.35),
	NumberSequenceKeypoint.new(0.8, 0.5),
	NumberSequenceKeypoint.new(1, 1),
})
snow.Parent = snowVolume

print("[MapBuilder] TribesMapLive gebaut - Gravity=0, durchgehende Ski-Fläche, 2 Sprungschanzen, Grab-Routen")
