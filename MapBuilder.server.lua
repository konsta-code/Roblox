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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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
	p.CanTouch = false
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

-- Ramp along Z, used to connect the longitudinal ski corridors.
local function skiRampZ(name, z0, y0, z1, y1, width, xCenter, color, material, parent, thickness)
	local run = z1 - z0
	local rise = y1 - y0
	local length = math.sqrt(run * run + rise * rise)
	local theta = math.atan2(rise, run)
	thickness = thickness or 55
	local midZ = (z0 + z1) / 2
	local midY = (y0 + y1) / 2
	local cz = midZ + (thickness / 2) * math.sin(theta)
	local cy = midY - (thickness / 2) * math.cos(theta)
	return slab(
		name,
		Vector3.new(width, thickness, length),
		CFrame.new(xCenter, cy, cz) * CFrame.Angles(-theta, 0, 0),
		color,
		material,
		parent,
		true
	)
end

-- ============================================================
-- 1. BODEN (Fangfläche, verhindert Endlos-Fall am Start)
-- ============================================================
slab("Ground", Vector3.new(1500, 70, 1000), CFrame.new(0, -70, 0), COL_ROCK, Enum.Material.Rock, map, true)

-- ============================================================
-- 2. HAUPT-TERRAIN (durchgehende Ski-Fläche, Breite 240)
-- ============================================================
local terrain = Instance.new("Folder")
terrain.Name = "Terrain"
terrain.Parent = map

local W = 300
local mainProfile = {
	{ -535, 24 },
	{ -450, -4 },
	{ -345, 25 },
	{ -235, -12 },
	{ -120, 38 },
	{ 0, -8 },
	{ 120, 38 },
	{ 235, -12 },
	{ 345, 25 },
	{ 450, -4 },
	{ 535, 24 },
}
for index = 1, #mainProfile - 1 do
	local a = mainProfile[index]
	local b = mainProfile[index + 1]
	skiRamp(
		"MainRoute_" .. index,
		a[1], a[2], b[1], b[2], W, 0,
		if index % 3 == 0 then COL_SNOW else COL_ICE,
		if index % 3 == 0 then Enum.Material.Snow else Enum.Material.Ice,
		terrain
	)
end

slab("RedRouteHub", Vector3.new(30, 8, 880), CFrame.new(-535, 20, 0), COL_SNOW, Enum.Material.Snow, terrain, true)
slab("BlueRouteHub", Vector3.new(30, 8, 880), CFrame.new(535, 20, 0), COL_SNOW, Enum.Material.Snow, terrain, true)

-- ============================================================
-- 3. SPRUNGSCHANZEN (in den Tälern, schmaler -> optional anfahrbar)
-- Kurze steile Rampen auf dem Talboden: mit Ski-Speed drauf = Absprung nach
-- oben Richtung Mitte, ideal um Jetpack-/Disc-Jump-Höhe mitzunehmen.
-- ============================================================
local kickers = Instance.new("Folder")
kickers.Name = "Kickers"
kickers.Parent = map

local mainKickers = {
	{ "WestOuter", -462, -3, -442, 13 },
	{ "WestInner", -247, -10, -225, 14 },
	{ "EastInner", 247, -10, 225, 14 },
	{ "EastOuter", 462, -3, 442, 13 },
}
for _, kicker in mainKickers do
	skiRamp(kicker[1], kicker[2], kicker[3], kicker[4], kicker[5], 78, 0, COL_SNOW, Enum.Material.Glacier, kickers, 14)
end

-- ============================================================
-- 3b. SEITEN-ROUTEN (Nord z=-190 / Süd z=+190, Breite 140)
-- Zweite Ski-Linie pro Seite mit eigenem Rhythmus: welliger als die
-- Hauptbahn (Basis -> Welle -> tiefe Senke -> Welle -> Basis), dockt bei
-- z=±120 nahtlos an die Kante der Hauptbahn an (kein Spalt). Einstieg an
-- beiden Enden auf Basis-Höhe 24 - vom Basis-Plateau seitlich reindriften.
-- Flanken-Routen sind schwerer zu verteidigen -> klassische Capper-Wahl.
-- ============================================================
local sideRoutes = Instance.new("Folder")
sideRoutes.Name = "SideRoutes"
sideRoutes.Parent = map

for _, zc in { -250, 250 } do
	local suffix = if zc < 0 then "N" else "S"
	local SW = 200
	local sideProfile = {
		{ -535, 24 }, { -420, 6 }, { -320, 28 }, { -210, -14 }, { -100, 22 },
		{ 0, 46 }, { 100, 22 }, { 210, -14 }, { 320, 28 }, { 420, 6 }, { 535, 24 },
	}
	for index = 1, #sideProfile - 1 do
		local a = sideProfile[index]
		local b = sideProfile[index + 1]
		skiRamp(
			string.format("SideRoute_%s_%d", suffix, index),
			a[1], a[2], b[1], b[2], SW, zc,
			if index % 2 == 0 then COL_SNOW else COL_ICE,
			if index % 2 == 0 then Enum.Material.Snow else Enum.Material.Ice,
			sideRoutes
		)
	end
	skiRamp("SideKickerA_" .. suffix, -220, -12, -198, 13, 62, zc, COL_SNOW, Enum.Material.Glacier, sideRoutes, 12)
	skiRamp("SideKickerB_" .. suffix, 220, -12, 198, 13, 62, zc, COL_SNOW, Enum.Material.Glacier, sideRoutes, 12)
end

local rimRoutes = Instance.new("Folder")
rimRoutes.Name = "HighlandRimRoutes"
rimRoutes.Parent = map
for _, zc in { -395, 395 } do
	local suffix = if zc < 0 then "N" else "S"
	local rimProfile = {
		{ -535, 24 }, { -420, 46 }, { -300, 8 }, { -170, 58 }, { 0, 20 },
		{ 170, 58 }, { 300, 8 }, { 420, 46 }, { 535, 24 },
	}
	for index = 1, #rimProfile - 1 do
		local a = rimProfile[index]
		local b = rimProfile[index + 1]
		skiRamp(
			string.format("Highland_%s_%d", suffix, index),
			a[1], a[2], b[1], b[2], 90, zc,
			COL_SNOW, Enum.Material.Glacier, rimRoutes, 70
		)
	end
end

local crossRoutes = Instance.new("Folder")
crossRoutes.Name = "CrossRoutes"
crossRoutes.Parent = map
local crossDefinitions = {
	{ -450, -4, 14, 46 },
	{ -235, -12, -5, 28 },
	{ 0, -8, 46, 20 },
	{ 235, -12, -5, 28 },
	{ 450, -4, 14, 46 },
}
for index, cross in crossDefinitions do
	local x, mainY, sideY, rimY = cross[1], cross[2], cross[3], cross[4]
	for _, direction in { -1, 1 } do
		local suffix = if direction < 0 then "N" else "S"
		skiRampZ(
			string.format("MainToSide_%s_%d", suffix, index),
			direction * 130, mainY, direction * 175, sideY, 74, x,
			COL_ICE, Enum.Material.Ice, crossRoutes, 34
		)
		skiRampZ(
			string.format("SideToRim_%s_%d", suffix, index),
			direction * 330, sideY, direction * 360, rimY, 74, x,
			COL_SNOW, Enum.Material.Glacier, crossRoutes, 30
		)
	end
end

-- ============================================================
-- 3c. HINTERLAND (hinter beiden Basen)
-- Volle Breite ansteigende Schüssel hinter jeder Basis: Verteidiger skien
-- aus dem Hinterland zurück zur Front, Capper nutzen sie als Flucht-Bogen
-- über die Basis hinweg. Zwischen Basis-Rückwand und Anstieg liegt ein
-- flacher Hof (y=0) als Landezone.
-- ============================================================
local backfield = Instance.new("Folder")
backfield.Name = "Backfield"
backfield.Parent = map

skiRamp("RedBackfield", -740, 62, -605, 0, 880, 0, COL_SNOW, Enum.Material.Snow, backfield)
skiRamp("BlueBackfield", 605, 0, 740, 62, 880, 0, COL_SNOW, Enum.Material.Snow, backfield)

-- ============================================================
-- 4. CANYON-SILHOUETTE UND ROUTENLICHTER
-- Die Felsen stehen ausserhalb der Ski-Flaeche. Die kleineren Leuchten sind
-- nicht kollidierbar, damit sie bei hoher Geschwindigkeit keine Route stoppen.
-- ============================================================
local scenery = Instance.new("Folder")
scenery.Name = "CanyonScenery"
scenery.Parent = map

-- z=±272: hinter den Seiten-Routen (enden bei ±260), vor dem Weltrand (±280)
local spires = {
	{ -620, -472, 66, -12 },
	{ -545, 470, 92, 9 },
	{ -450, -474, 74, 15 },
	{ -350, 472, 108, -7 },
	{ -245, -470, 82, 11 },
	{ -130, 473, 98, -13 },
	{ -20, -472, 78, 7 },
	{ 95, 470, 112, -10 },
	{ 210, -474, 86, 12 },
	{ 330, 472, 104, -8 },
	{ 445, -470, 76, 10 },
	{ 560, 473, 96, -11 },
	{ 650, -472, 70, 8 },
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

for x = -500, 500, 100 do
	for _, z in { -145, 145, -345, 345, -445, 445 } do
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

local routeLandmarks = {
	{ "CORE BOWL", Vector3.new(0, 18, 0), Color3.fromRGB(105, 232, 255) },
	{ "NORTH FLANK", Vector3.new(0, 63, -250), Color3.fromRGB(145, 220, 255) },
	{ "SOUTH FLANK", Vector3.new(0, 63, 250), Color3.fromRGB(145, 220, 255) },
	{ "NORTH RIDGE", Vector3.new(0, 38, -395), Color3.fromRGB(225, 238, 250) },
	{ "SOUTH RIDGE", Vector3.new(0, 38, 395), Color3.fromRGB(225, 238, 250) },
}
for index, landmark in routeLandmarks do
	local marker = slab(
		"RouteLandmark" .. index,
		Vector3.new(1.5, 18, 1.5),
		CFrame.new(landmark[2]),
		landmark[3],
		Enum.Material.Neon,
		scenery,
		false
	)
	marker.CanQuery = false
	local label = Instance.new("BillboardGui")
	label.Name = "RouteName"
	label.Size = UDim2.fromOffset(230, 36)
	label.StudsOffset = Vector3.new(0, 12, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 900
	label.Parent = marker
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundColor3 = Color3.fromRGB(8, 13, 20)
	textLabel.BackgroundTransparency = 0.28
	textLabel.BorderSizePixel = 0
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.Text = landmark[1]
	textLabel.TextColor3 = landmark[3]
	textLabel.TextSize = 14
	textLabel.TextStrokeTransparency = 0.4
	textLabel.Parent = label
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = textLabel
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
	local baseX = 570 * s
	local facing = -s -- Richtung Mitte

	slab("Platform", Vector3.new(90, 8, 126), CFrame.new(baseX, 20, 0), setup.col, Enum.Material.Metal, base, true)
	slab("BackWall", Vector3.new(4, 30, 126), CFrame.new(baseX - facing * 43, 39, 0), COL_DARK, Enum.Material.Metal, base, true)
	slab("SideWallA", Vector3.new(90, 18, 4), CFrame.new(baseX, 33, -61), COL_DARK, Enum.Material.Metal, base, true)
	slab("SideWallB", Vector3.new(90, 18, 4), CFrame.new(baseX, 33, 61), COL_DARK, Enum.Material.Metal, base, true)
	slab("Roof", Vector3.new(60, 2, 82), CFrame.new(baseX - facing * 10, 48, 0), COL_METAL, Enum.Material.Metal, base, true)
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

	for _, railZ in { -51, 51 } do
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
		CFrame.new(baseX - facing * 40.7, 39, 0),
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

	-- Hoher Energie-Beacon: macht die Basis auch bei maximalem Ski-Tempo
	-- aus dem Hochland und dem gegnerischen Hinterland sofort lesbar.
	local beaconX = baseX - facing * 41
	local baseBeacon = slab(
		"BaseEnergyBeacon",
		Vector3.new(2.4, 118, 2.4),
		CFrame.new(beaconX, 105, 0),
		setup.col,
		Enum.Material.Neon,
		base,
		false
	)
	baseBeacon.Transparency = 0.42
	baseBeacon.CanQuery = false
	baseBeacon.CastShadow = false

	for ringIndex = 1, 3 do
		local ring = slab(
			"BeaconPulseRing" .. ringIndex,
			Vector3.new(1.2, 10 + ringIndex * 5, 10 + ringIndex * 5),
			CFrame.new(beaconX, 58 + ringIndex * 28, 0) * CFrame.Angles(0, 0, math.rad(90)),
			setup.col,
			Enum.Material.Neon,
			base,
			false
		)
		ring.Shape = Enum.PartType.Cylinder
		ring.Transparency = 0.3 + ringIndex * 0.1
		ring.CanQuery = false
		ring.CastShadow = false
	end

	local beaconCrown = slab(
		"BeaconCrown",
		Vector3.new(8, 8, 8),
		CFrame.new(beaconX, 166, 0),
		setup.col,
		Enum.Material.Neon,
		base,
		false
	)
	beaconCrown.Shape = Enum.PartType.Ball
	beaconCrown.CanQuery = false
	beaconCrown.CastShadow = false
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = setup.col
	beaconLight.Brightness = 3.5
	beaconLight.Range = 70
	beaconLight.Shadows = false
	beaconLight.Parent = beaconCrown

	-- Flaggen-Stand: vorne am Plattformrand zur Mitte, direkt über dem Kopf der
	-- Grab-Rampe -> schneller Capper fährt sie hoch und grabbt im Vorbeiflug
	local flagX = baseX + facing * 38
	local flagStand =
		slab("FlagStand", Vector3.new(5, 1.5, 5), CFrame.new(flagX, 24.75, 0), Color3.fromRGB(240, 240, 240), Enum.Material.Neon, base, true)
	flagStand:SetAttribute("Team", setup.teamName)
	CollectionService:AddTag(flagStand, "FlagStand")
	slab("FlagPole", Vector3.new(0.6, 14, 0.6), CFrame.new(flagX, 31, 0), Color3.fromRGB(180, 180, 180), Enum.Material.Metal, base, false)

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = setup.teamName .. "SpawnLocation"
	spawnLocation.Size = Vector3.new(16, 1, 16)
	spawnLocation.CFrame = CFrame.new(baseX - facing * 8, 24.5, -38)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = false
	spawnLocation.TeamColor = setup.brick
	spawnLocation.Duration = 0
	spawnLocation.Transparency = 0.5
	spawnLocation.Color = setup.col
	spawnLocation.Material = Enum.Material.Metal
	spawnLocation.Parent = base

	for i = 1, 4 do
		local sx = baseX - facing * 8 + (i - 2.5) * 10
		local spawnTag = Instance.new("Part")
		spawnTag.Name = setup.teamName .. "PlayerSpawn" .. i
		spawnTag.Size = Vector3.new(4, 1, 4)
		spawnTag.CFrame = CFrame.new(sx, 24.5, -38)
		spawnTag.Anchored = true
		spawnTag.CanCollide = false
		spawnTag.CanTouch = false
		spawnTag.CanQuery = false
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
	Vector3.new(1450, 1, 950),
	CFrame.new(0, 140, 0),
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
snow.Rate = 90
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

print(
	"[MapBuilder] TribesMapLive TITAN gebaut - 1.500x1.000, Core, Flanken, Hochland und Hinterland, "
		.. "8 Kicker, 10 Querwechsel, Grab-Routen, Gravity=0"
)

-- ============================================================
-- 7. SPIELBARE KARTENGRENZE
-- Keine unsichtbare Wand: Wer die Arena verlaesst, hat sechs Sekunden, um
-- mit Jetpack/Ski zurueckzukehren. Der Zustand repliziert als Player-Attribut
-- und wird vom HUD als deutlicher Countdown dargestellt.
-- ============================================================
local ARENA_MAX_X = 770
local ARENA_MAX_Z = 520
local ARENA_MIN_Y = -145
local ARENA_RETURN_TIME = 6
local BOUNDARY_UPDATE_INTERVAL = 0.2
local arenaOutsideTime: { [Player]: number } = {}
local boundaryAccumulator = 0

local function clearBoundaryWarning(player: Player)
	arenaOutsideTime[player] = nil
	if player:GetAttribute("OutOfBounds") ~= false then
		player:SetAttribute("OutOfBounds", false)
		player:SetAttribute("OutOfBoundsTime", ARENA_RETURN_TIME)
	end
end

local function isOutsideArena(position: Vector3): boolean
	return math.abs(position.X) > ARENA_MAX_X
		or math.abs(position.Z) > ARENA_MAX_Z
		or position.Y < ARENA_MIN_Y
end

local function setupBoundaryPlayer(player: Player)
	player:SetAttribute("OutOfBounds", false)
	player:SetAttribute("OutOfBoundsTime", ARENA_RETURN_TIME)
end

Players.PlayerAdded:Connect(setupBoundaryPlayer)
Players.PlayerRemoving:Connect(function(player)
	arenaOutsideTime[player] = nil
end)
for _, player in Players:GetPlayers() do
	setupBoundaryPlayer(player)
end

RunService.Heartbeat:Connect(function(dt)
	boundaryAccumulator += dt
	if boundaryAccumulator < BOUNDARY_UPDATE_INTERVAL then
		return
	end
	local step = boundaryAccumulator
	boundaryAccumulator = 0

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			clearBoundaryWarning(player)
			continue
		end

		if isOutsideArena(root.Position) then
			local elapsed = (arenaOutsideTime[player] or 0) + step
			arenaOutsideTime[player] = elapsed
			player:SetAttribute("OutOfBounds", true)
			player:SetAttribute("OutOfBoundsTime", math.max(0, ARENA_RETURN_TIME - elapsed))
			if elapsed >= ARENA_RETURN_TIME then
				humanoid.Health = 0
				clearBoundaryWarning(player)
			end
		else
			clearBoundaryWarning(player)
		end
	end
end)

print("[MapBuilder] Titan combat boundary active")
