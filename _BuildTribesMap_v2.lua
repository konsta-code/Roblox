-- _BuildTribesMap_v2.lua
-- Einmal-Befehl fuer Studio Command Bar (Ansicht > Befehlsleiste)
--
-- Verbesserte Ski-CTF-Map. Kernidee gegenueber v1: das gesamte Haupt-Terrain
-- ist EINE durchgehende, bündig verbundene Ski-Flaeche. Jede Rampe wird per
-- Winkel-Mathematik so gesetzt, dass ihre Oberkante exakt am naechsten
-- Segment andockt - keine senkrechten Stufen/Nahtstellen mehr, die beim
-- Skiing das Momentum brechen (das Hauptproblem von v1).
--
-- Hoehenprofil entlang X (Red -260  <->  Blue +260), spiegelsymmetrisch:
--   Basis(24) -> Abfahrt -> Tal(0) -> Zentralkamm(28) -> Tal(0) -> Basis(24)
-- Also zwei echte Abfahrten pro Seitenwechsel = Tribes-typischer Speed.
--
-- Aenderungen ggü. v1:
--  1. Fliessende Rampen statt Kasten+Wedge-Naehte (Momentum bleibt erhalten)
--  2. Steilere Abfahrt direkt an der Basis, lange Ausläufe
--  3. Basis-Rampe IST die Grab-Route: schneller Skifahrer faehrt sie hoch
--     direkt zur exponierten Flagge
--  4. Materialien (Ice/Snow/Rock/Metal) statt nur Farbe - Terrain lesbar
--
-- Idempotent: entfernt vorher TestArena / TribesMap / TribesMapV2.

local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")

-- Controller bringt eigene Gravitation mit - hier sicherheitshalber setzen,
-- da Rojo workspace.Gravity beim Live-Sync nicht zuverlaessig überträgt.
workspace.Gravity = 0

for _, name in { "TestArena", "TribesMap", "TribesMapV2" } do
	local old = workspace:FindFirstChild(name)
	if old then old:Destroy() end
end

local map = Instance.new("Folder")
map.Name = "TribesMapV2"
map.Parent = workspace

-- ============================================================
-- FARBEN & MATERIALIEN
-- ============================================================
local COL_ROCK = Color3.fromRGB(96, 102, 108)
local COL_ICE = Color3.fromRGB(168, 196, 220)
local COL_SNOW = Color3.fromRGB(224, 230, 236)
local COL_METAL = Color3.fromRGB(88, 94, 102)
local COL_DARK = Color3.fromRGB(42, 46, 54)
local COL_RED = Color3.fromRGB(170, 52, 52)
local COL_BLUE = Color3.fromRGB(52, 88, 172)

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

-- Rampe, deren OBERKANTE exakt von (x0,y0) nach (x1,y1) laeuft (entlang X,
-- volle Breite in Z). Dick (T) und tief eingegraben, damit unten keine
-- Überhaenge auf Spielhoehe entstehen. Aneinandergereiht mit geteilten
-- Endpunkten docken die Oberflaechen luecken- und stufenlos an.
local function skiRamp(name, x0, y0, x1, y1, width, zCenter, color, material, parent)
	local run = x1 - x0
	local rise = y1 - y0
	local length = math.sqrt(run * run + rise * rise)
	local theta = math.atan2(rise, run)
	local thickness = 90

	local midX = (x0 + x1) / 2
	local midY = (y0 + y1) / 2
	-- Part-Mittelpunkt um thickness/2 entlang der Oberflaechen-Normalen
	-- (-sin, cos) nach unten versetzen, damit die +Y-Flaeche durch (mid) geht.
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
-- 1. BODEN (Fangflaeche unter dem Terrain)
-- ============================================================
slab("Ground", Vector3.new(820, 60, 320), CFrame.new(0, -30, 0), COL_ROCK, Enum.Material.Rock, map, true)

-- ============================================================
-- 2. HAUPT-TERRAIN (durchgehende Ski-Flaeche, Breite 240)
-- ============================================================
local terrain = Instance.new("Folder")
terrain.Name = "Terrain"
terrain.Parent = map

local W = 240
-- Profil-Stützpunkte (x, y). Nachbarsegmente teilen sich Endpunkte -> buendig.
--   Basis(24) -> Tal(0) -> Kamm(28) -> Tal(0) -> Basis(24)
skiRamp("L1_BaseDescent", -230, 24, -150, 2, W, 0, COL_ICE, Enum.Material.Ice, terrain)
skiRamp("L2_Valley", -150, 2, -80, 0, W, 0, COL_SNOW, Enum.Material.Snow, terrain)
skiRamp("L3_RidgeClimb", -80, 0, 0, 28, W, 0, COL_ICE, Enum.Material.Ice, terrain)
skiRamp("R3_RidgeDrop", 0, 28, 80, 0, W, 0, COL_ICE, Enum.Material.Ice, terrain)
skiRamp("R2_Valley", 80, 0, 150, 2, W, 0, COL_SNOW, Enum.Material.Snow, terrain)
skiRamp("R1_BaseAscent", 150, 2, 230, 24, W, 0, COL_ICE, Enum.Material.Ice, terrain)

-- ============================================================
-- 3. BASEN (Red -262, Blue +262) - Plattform bündig am Rampenkopf (y=24)
-- ============================================================
local baseSetups = {
	{ teamName = "Red", brick = BrickColor.new("Bright red"), sign = -1, col = COL_RED },
	{ teamName = "Blue", brick = BrickColor.new("Bright blue"), sign = 1, col = COL_BLUE },
}

for _, setup in baseSetups do
	local team = Teams:FindFirstChild(setup.teamName)
	if not team then
		warn("_BuildTribesMap_v2: Team \"" .. setup.teamName .. "\" fehlt - in Teams-Service anlegen")
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

	-- Plattform (Oberkante y=24, dockt an den Basis-Rampenkopf bei x=+-230 an)
	slab("Platform", Vector3.new(70, 8, 96), CFrame.new(baseX, 20, 0), setup.col, Enum.Material.Metal, base, true)

	-- Rueckwand + Seitenwaende (Cover, offen zur Mitte fuer den Grab-Anflug)
	slab("BackWall", Vector3.new(4, 26, 96), CFrame.new(baseX - facing * 33, 37, 0), COL_DARK, Enum.Material.Metal, base, true)
	slab("SideWallA", Vector3.new(70, 16, 4), CFrame.new(baseX, 32, -46), COL_DARK, Enum.Material.Metal, base, true)
	slab("SideWallB", Vector3.new(70, 16, 4), CFrame.new(baseX, 32, 46), COL_DARK, Enum.Material.Metal, base, true)

	-- Teildach
	slab("Roof", Vector3.new(48, 2, 64), CFrame.new(baseX - facing * 8, 45, 0), COL_METAL, Enum.Material.Metal, base, true)

	-- Generator-Raum (Deko, hinten)
	slab("GeneratorRoom", Vector3.new(22, 12, 28), CFrame.new(baseX - facing * 14, 30, 0), COL_DARK, Enum.Material.DiamondPlate, base, true).Transparency = 0.3

	-- Flaggen-Stand: vorne am Plattformrand zur Mitte, exponiert direkt ueber
	-- dem Kopf der Grab-Rampe -> schneller Capper faehrt sie hoch und grabbt
	local flagX = baseX + facing * 28
	local flagStand = slab("FlagStand", Vector3.new(5, 1.5, 5), CFrame.new(flagX, 24.75, 0), Color3.fromRGB(240, 240, 240), Enum.Material.Neon, base, true)
	flagStand:SetAttribute("Team", setup.teamName)
	CollectionService:AddTag(flagStand, "FlagStand")
	slab("FlagPole", Vector3.new(0.6, 14, 0.6), CFrame.new(flagX, 31, 0), Color3.fromRGB(180, 180, 180), Enum.Material.Metal, base, false)

	-- SpawnLocation (auf der Plattform hinter der Flagge)
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

	-- Zusaetzliche getaggte PlayerSpawns (Rundenstart-Teleport, SpawnManager)
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

print("_BuildTribesMap_v2: fertig!")
print("  - Durchgehende Ski-Flaeche: Basis(24)->Tal(0)->Kamm(28)->Tal(0)->Basis(24)")
print("  - Rampen bündig verbunden (keine Momentum-Naehte)")
print("  - Basis-Rampe = Grab-Route zur exponierten Flagge")
print("  - Materialien Ice/Snow/Rock/Metal")
print("  - workspace.Gravity = 0 gesetzt")
print("")
print("Anwendung: Befehlsleiste oeffnen, Script einfuegen, Enter.")
