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
-- 4. BASEN (Red -262, Blue +262)
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
	slab("GeneratorRoom", Vector3.new(22, 12, 28), CFrame.new(baseX - facing * 14, 30, 0), COL_DARK, Enum.Material.DiamondPlate, base, true).Transparency =
		0.3

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

print("[MapBuilder] TribesMapLive gebaut - Gravity=0, durchgehende Ski-Fläche, 2 Sprungschanzen, Grab-Routen")
