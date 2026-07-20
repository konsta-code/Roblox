-- _BuildTribesMap.lua
-- Einmal-Befehl fuer Studio Command Bar (View > Command Bar)
-- Baut eine spielbare Tribes-Style CTF-Map mit Ski-Routen
--
-- Layout inspiriert von klassischen Tribes-Maps (Katabatic-artig):
-- Zwei erhoehte Basen gegenueber, Mittelhügel und Abfahrten dazwischen

local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")

-- Alte Arena entfernen
for _, name in { "TestArena", "TribesMap" } do
	local old = workspace:FindFirstChild(name)
	if old then old:Destroy() end
end

local map = Instance.new("Folder")
map.Name = "TribesMap"
map.Parent = workspace

local function part(name, size, cframe, color, parent, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.CanCollide = if opts.canCollide == nil then true else opts.canCollide
	p.Transparency = opts.transparency or 0
	p.Parent = parent
	return p
end

local function wedge(name, size, cframe, color, parent)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- ============================================================
-- FARBEN
-- ============================================================
local COL_GROUND = Color3.fromRGB(75, 95, 70)
local COL_ROCK = Color3.fromRGB(110, 115, 120)
local COL_ICE = Color3.fromRGB(160, 185, 210)
local COL_SNOW = Color3.fromRGB(220, 225, 230)
local COL_RED = Color3.fromRGB(180, 50, 50)
local COL_BLUE = Color3.fromRGB(50, 90, 180)
local COL_METAL = Color3.fromRGB(90, 95, 100)
local COL_DARK = Color3.fromRGB(45, 48, 55)

-- ============================================================
-- 1. GROSSER BODEN
-- ============================================================
part("Ground", Vector3.new(700, 6, 500), CFrame.new(0, -3, 0), COL_GROUND, map)

-- ============================================================
-- 2. MITTELHUEGEL (Haupt-Ski-Terrain)
-- ============================================================
local hills = Instance.new("Folder")
hills.Name = "Hills"
hills.Parent = map

-- Zentraler grosser Huegel
part("CentralHill", Vector3.new(180, 40, 140), CFrame.new(0, 17, 0), COL_ROCK, hills)

-- Abfahrt Richtung Red (links) - steil nach unten
wedge("SlopeToRed", Vector3.new(140, 35, 100),
	CFrame.new(-140, 14.5, 0) * CFrame.Angles(0, math.rad(90), 0),
	COL_ICE, hills)

-- Abfahrt Richtung Blue (rechts)
wedge("SlopeToBlue", Vector3.new(140, 35, 100),
	CFrame.new(140, 14.5, 0) * CFrame.Angles(0, math.rad(-90), 0),
	COL_ICE, hills)

-- Seitenhuegel vorne (gute Cap-Route)
part("FrontHill", Vector3.new(100, 22, 60), CFrame.new(0, 8, -120), COL_ROCK, hills)
wedge("FrontSlopeL", Vector3.new(80, 20, 50),
	CFrame.new(-80, 7, -120) * CFrame.Angles(0, math.rad(90), 0),
	COL_ICE, hills)
wedge("FrontSlopeR", Vector3.new(80, 20, 50),
	CFrame.new(80, 7, -120) * CFrame.Angles(0, math.rad(-90), 0),
	COL_ICE, hills)

-- Seitenhuegel hinten
part("BackHill", Vector3.new(100, 22, 60), CFrame.new(0, 8, 120), COL_ROCK, hills)
wedge("BackSlopeL", Vector3.new(80, 20, 50),
	CFrame.new(-80, 7, 120) * CFrame.Angles(0, math.rad(90), 0),
	COL_ICE, hills)
wedge("BackSlopeR", Vector3.new(80, 20, 50),
	CFrame.new(80, 7, 120) * CFrame.Angles(0, math.rad(-90), 0),
	COL_ICE, hills)

-- Kleine Midfield-Rampen fuer Speed
for i, z in { -60, 60 } do
	wedge("MidRamp" .. i, Vector3.new(40, 12, 30),
		CFrame.new(0, 3, z) * CFrame.Angles(math.rad(-18), 0, 0),
		COL_SNOW, hills)
end

-- ============================================================
-- 3. BASEN (Red links, Blue rechts)
-- ============================================================
local baseSetups = {
	{ teamName = "Red", color = BrickColor.new("Bright red"), x = -260, col = COL_RED },
	{ teamName = "Blue", color = BrickColor.new("Bright blue"), x = 260, col = COL_BLUE },
}

for _, setup in baseSetups do
	local team = Teams:FindFirstChild(setup.teamName)
	if not team then
		warn("_BuildTribesMap: Team \"" .. setup.teamName .. "\" fehlt")
		continue
	end
	team.TeamColor = setup.color
	team.AutoAssignable = true

	local base = Instance.new("Folder")
	base.Name = setup.teamName .. "Base"
	base.Parent = map

	local x = setup.x
	local facing = if x < 0 then 1 else -1 -- Richtung Mitte

	-- Erhoehte Basis-Plattform
	part("Platform", Vector3.new(70, 4, 70), CFrame.new(x, 12, 0), setup.col, base)

	-- Basis-Rampe zur Plattform (von aussen)
	wedge("ApproachRamp", Vector3.new(50, 14, 40),
		CFrame.new(x + facing * 50, 5, 0) * CFrame.Angles(0, if facing > 0 then math.rad(90) else math.rad(-90), 0),
		COL_METAL, base)

	-- Rueckwand
	part("BackWall", Vector3.new(4, 20, 70), CFrame.new(x - facing * 33, 22, 0), COL_DARK, base)

	-- Seitenwaende
	part("SideWallA", Vector3.new(70, 16, 4), CFrame.new(x, 20, -33), COL_DARK, base)
	part("SideWallB", Vector3.new(70, 16, 4), CFrame.new(x, 20, 33), COL_DARK, base)

	-- Dach / Ueberdachung (teilweise)
	part("Roof", Vector3.new(40, 2, 40), CFrame.new(x - facing * 10, 32, 0), COL_METAL, base)

	-- Generator-Raum (visuell)
	local genRoom = part("GeneratorRoom", Vector3.new(20, 12, 20), CFrame.new(x - facing * 15, 20, 0), COL_DARK, base)
	genRoom.Transparency = 0.3

	-- Flaggen-Stand (etwas vorne auf der Plattform, exponiert)
	local flagStand = part("FlagStand", Vector3.new(5, 1.5, 5),
		CFrame.new(x + facing * 20, 14.75, 0),
		Color3.fromRGB(240, 240, 240), base)
	flagStand:SetAttribute("Team", setup.teamName)
	CollectionService:AddTag(flagStand, "FlagStand")

	-- Flaggen-Mast (visuell)
	part("FlagPole", Vector3.new(0.6, 14, 0.6),
		CFrame.new(x + facing * 20, 22, 0),
		Color3.fromRGB(180, 180, 180), base)

	-- SpawnLocation
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = setup.teamName .. "SpawnLocation"
	spawnLocation.Size = Vector3.new(14, 1, 14)
	spawnLocation.CFrame = CFrame.new(x - facing * 10, 14.5, -20)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = false
	spawnLocation.TeamColor = setup.color
	spawnLocation.Transparency = 0.5
	spawnLocation.Color = setup.col
	spawnLocation.Parent = base

	-- Zusaetzliche PlayerSpawns
	for i = 1, 4 do
		local sx = x - facing * 10 + (i - 2.5) * 8
		local spawnTag = Instance.new("Part")
		spawnTag.Name = setup.teamName .. "PlayerSpawn" .. i
		spawnTag.Size = Vector3.new(4, 1, 4)
		spawnTag.CFrame = CFrame.new(sx, 14.5, -20)
		spawnTag.Anchored = true
		spawnTag.CanCollide = false
		spawnTag.Transparency = 1
		spawnTag:SetAttribute("Team", setup.teamName)
		spawnTag.Parent = base
		CollectionService:AddTag(spawnTag, "PlayerSpawn")
	end

	-- Kleine Verteidigungs-Huegel vor der Basis
	part("DefenseHill", Vector3.new(40, 10, 30),
		CFrame.new(x + facing * 70, 2, 0),
		COL_ROCK, base)
end

-- ============================================================
-- 4. ZUSAETZLICHE SKI-ROUTEN (Aussen)
-- ============================================================
local routes = Instance.new("Folder")
routes.Name = "SkiRoutes"
routes.Parent = map

-- Lange Aussen-Abfahrt vorne
for i, side in { -1, 1 } do
	wedge("OuterFront" .. i, Vector3.new(120, 18, 40),
		CFrame.new(side * 180, 6, -90) * CFrame.Angles(math.rad(-12), 0, 0),
		COL_ICE, routes)
end

-- Lange Aussen-Abfahrt hinten
for i, side in { -1, 1 } do
	wedge("OuterBack" .. i, Vector3.new(120, 18, 40),
		CFrame.new(side * 180, 6, 90) * CFrame.Angles(math.rad(12), 0, 0),
		COL_ICE, routes)
end

print("_BuildTribesMap: fertig!")
print("  - Grosser Boden 700x500")
print("  - Zentralhuegel + Abfahrten")
print("  - RedBase (-260) und BlueBase (+260)")
print("  - Flaggenstaende getaggt")
print("  - Spawns gesetzt")
print("  - Mehrere Ski-Routen")
print("")
print("Anwendung: Command Bar oeffnen, Script einfuegen, Enter.")
