-- MapPoolConstants.lua
-- Ablageort: ReplicatedStorage/Modules/MapPoolConstants
--
-- Datengetriebener Map-Pool. Reine DATEN, kein Verhalten:
--   * Themes  = Optik (Terrain-Material/Farbe, Wasser, Licht/Atmosphaere, Deko)
--   * Pool    = Layout je Map (Hoehenfeld-Parameter, Basenlage, Seed, Theme)
--
-- Gelesen von WorldGen (Terrain) und MapDirector (Auswahl/Licht/Deko). Ein
-- Theme kann von mehreren Maps benutzt werden; jede Map hat ihr eigenes Layout
-- + Seed, damit Maps desselben Themes sich klar unterscheiden.

local rgb = Color3.fromRGB
local Mat = Enum.Material

local MapPool = {}

-- Globale Grenzen (Vielfache von 4 wegen Region3:ExpandToGrid im Generator).
MapPool.Bounds = { xMax = 760, zMax = 952 }

-- ============================================================
-- THEMES
-- ============================================================
-- materials : welche Roblox-Terrain-Materialien welches Hoehenband bekommen
-- bands     : Schwellen fuer Peak / Rock (Hoehe) und Rock (Steigung)
-- colors    : SetMaterialColor-Liste
-- water     : Look der Wasserflaechen
-- env       : Lighting/Atmosphere/Clouds
-- dressing  : Flora-Typ+Anzahl, Himmelskoerper, optionales Re-Skin, Basis-Glow
MapPool.Themes = {

	grass = {
		materials = { base = Mat.Grass, shore = Mat.Ground, rock = Mat.Rock, peak = Mat.Snow },
		bands = { peakHeight = 155, rockHeight = 128, rockSlope = 60 },
		colors = {
			{ Mat.Grass, rgb(82, 130, 44) },
			{ Mat.Ground, rgb(150, 142, 108) },
			{ Mat.Rock, rgb(96, 92, 84) },
			{ Mat.Snow, rgb(232, 238, 244) },
		},
		water = { color = rgb(28, 84, 96), reflectance = 0.25, transparency = 0.35 },
		env = {
			clockTime = 17.55,
			brightness = 2.85,
			ambient = rgb(78, 78, 70),
			outdoorAmbient = rgb(140, 146, 120),
			colorTop = rgb(255, 176, 112),
			colorBottom = rgb(80, 44, 30),
			geoLatitude = 24,
			fog = { color = rgb(232, 156, 108), start = 1500, finish = 9000 },
			atmosphere = { density = 0.14, offset = 0.5, color = rgb(240, 168, 120), decay = rgb(158, 82, 58), glare = 0.28, haze = 0.9 },
			bloom = { intensity = 0.4, size = 40, threshold = 1.15 },
			grade = { brightness = 0.01, contrast = 0.12, saturation = 0.2, tint = rgb(250, 243, 231) },
			sunRays = { intensity = 0.12, spread = 1.0 },
			clouds = { cover = 0.62, density = 0.34, color = rgb(255, 206, 168) },
		},
		dressing = {
			flora = "acacia",
			floraCount = 42,
			baseGlow = rgb(255, 188, 120),
			sky = { kind = "moon", position = Vector3.new(-1250, 780, 1650), size = 900, color = rgb(248, 232, 214) },
			-- warmes Re-Skin der kalten Basis-Palette (Sunset-Look)
			reskin = {
				{ from = rgb(218, 228, 237), to = rgb(206, 194, 168) },
				{ from = rgb(178, 197, 214), to = rgb(180, 166, 140) },
				{ from = rgb(128, 173, 207), to = rgb(126, 138, 98) },
				{ from = rgb(96, 102, 108), to = rgb(96, 92, 80) },
				{ from = rgb(84, 100, 117), to = rgb(120, 104, 78) },
			},
		},
	},

	snow = {
		materials = { base = Mat.Snow, shore = Mat.Glacier, rock = Mat.Rock, peak = Mat.Glacier },
		bands = { peakHeight = 150, rockHeight = 120, rockSlope = 55 },
		colors = {
			{ Mat.Snow, rgb(236, 240, 248) },
			{ Mat.Glacier, rgb(198, 220, 230) },
			{ Mat.Rock, rgb(120, 124, 132) },
		},
		water = { color = rgb(150, 200, 214), reflectance = 0.42, transparency = 0.22 },
		env = {
			clockTime = 8.4,
			brightness = 2.5,
			ambient = rgb(120, 128, 140),
			outdoorAmbient = rgb(150, 164, 182),
			colorTop = rgb(182, 206, 236),
			colorBottom = rgb(120, 140, 165),
			geoLatitude = 62,
			fog = { color = rgb(205, 220, 235), start = 1100, finish = 7500 },
			atmosphere = { density = 0.22, offset = 0.4, color = rgb(210, 224, 238), decay = rgb(120, 150, 180), glare = 0.1, haze = 1.3 },
			bloom = { intensity = 0.5, size = 44, threshold = 1.05 },
			grade = { brightness = 0.015, contrast = 0.08, saturation = -0.06, tint = rgb(232, 240, 250) },
			sunRays = { intensity = 0.06, spread = 1.0 },
			clouds = { cover = 0.85, density = 0.5, color = rgb(226, 233, 242) },
		},
		dressing = {
			flora = "pine",
			floraCount = 34,
			baseGlow = rgb(150, 200, 255),
			snowfall = true,
			sky = { kind = "sun", position = Vector3.new(1500, 620, 1400), size = 640, color = rgb(232, 242, 252) },
			reskin = nil, -- kalte Basis-Palette passt bereits zum Schnee
		},
	},

	desert = {
		materials = { base = Mat.Sand, shore = Mat.Sandstone, rock = Mat.Rock, peak = Mat.Sandstone },
		bands = { peakHeight = 240, rockHeight = 118, rockSlope = 58 },
		colors = {
			{ Mat.Sand, rgb(224, 196, 140) },
			{ Mat.Sandstone, rgb(190, 150, 100) },
			{ Mat.Rock, rgb(150, 120, 86) },
		},
		water = { color = rgb(46, 120, 120), reflectance = 0.2, transparency = 0.3 },
		env = {
			clockTime = 16.4,
			brightness = 3.1,
			ambient = rgb(120, 104, 78),
			outdoorAmbient = rgb(190, 168, 120),
			colorTop = rgb(255, 208, 150),
			colorBottom = rgb(150, 110, 60),
			geoLatitude = 12,
			fog = { color = rgb(226, 196, 150), start = 1800, finish = 9500 },
			atmosphere = { density = 0.16, offset = 0.45, color = rgb(238, 206, 158), decay = rgb(180, 130, 80), glare = 0.4, haze = 1.0 },
			bloom = { intensity = 0.45, size = 42, threshold = 1.1 },
			grade = { brightness = 0.01, contrast = 0.14, saturation = 0.12, tint = rgb(252, 244, 228) },
			sunRays = { intensity = 0.18, spread = 1.0 },
			clouds = { cover = 0.25, density = 0.2, color = rgb(250, 232, 200) },
		},
		dressing = {
			flora = "cactus",
			floraCount = 26,
			baseGlow = rgb(255, 200, 130),
			sky = { kind = "sun", position = Vector3.new(1400, 700, -1500), size = 1000, color = rgb(255, 236, 190) },
			reskin = {
				{ from = rgb(218, 228, 237), to = rgb(214, 190, 150) },
				{ from = rgb(178, 197, 214), to = rgb(196, 168, 124) },
				{ from = rgb(128, 173, 207), to = rgb(170, 138, 96) },
				{ from = rgb(96, 102, 108), to = rgb(120, 100, 74) },
				{ from = rgb(84, 100, 117), to = rgb(150, 120, 82) },
			},
		},
	},
}

-- ============================================================
-- POOL  (Layout je Map)
-- ============================================================
-- Hoehenfeld-Reihenfolge im Generator:
--   base+fbm -> edge-Berge -> hills(+) -> lakes(carve) -> corridor(carve)
--   -> plateaus(override, zuletzt => Basen/Outposts liegen flach)
-- baseTargets: X/Z der Basen-Plateaus; Y wird beim Seaten per Raycast bestimmt.
-- Jede Map hat eigenen Seed (verschiebt das fbm-Rauschen -> anderes Mikro-Terrain).
MapPool.Pool = {

	-- ---- GRAS ----------------------------------------------------------
	{
		id = "grass_ridgeline",
		name = "Ridgeline",
		theme = "grass",
		seed = 101,
		layout = {
			waterLevel = 6,
			baseHeight = 20, baseAmp = 24, baseFreq = 0.0016,
			edge = { start = 0.58, span = 0.42, height = 150, noiseAmp = 95, noiseFreq = 0.004 },
			hills = { { 0, -560, 520, 95 }, { -300, -140, 360, 60 }, { 360, 120, 420, 55 }, { 0, -40, 165, 58 }, { 30, 260, 140, 44 } },
			lakes = { { -150, 300, 120, -12 }, { 250, 560, 130, -12 } },
			corridor = { amp = 150, freq = 0.0042, width = 300, depth = 20 },
			plateaus = { { -430, 380, 130, 116 }, { -340, -440, 130, 128 }, { 360, 430, 150, 4 }, { 40, -800, 160, 58 }, { -90, 780, 160, 58 } },
			clampMin = -30, clampMax = 235,
			baseTargets = { Red = Vector3.new(40, 58, -800), Blue = Vector3.new(-90, 58, 780) },
		},
	},
	{
		id = "grass_basin",
		name = "Verdant Basin",
		theme = "grass",
		seed = 233,
		layout = {
			waterLevel = 6,
			baseHeight = 22, baseAmp = 26, baseFreq = 0.0018,
			edge = { start = 0.6, span = 0.4, height = 140, noiseAmp = 90, noiseFreq = 0.0042 },
			hills = { { 0, 0, 520, 82 }, { -250, 320, 320, 44 }, { 300, -360, 340, 46 }, { -320, -300, 260, 40 } },
			lakes = { { 0, -520, 150, -14 }, { 260, 300, 120, -12 } },
			corridor = nil,
			plateaus = { { 0, 0, 190, 74 }, { -430, 300, 130, 96 }, { 430, -300, 130, 96 }, { -560, -300, 150, 55 }, { 520, 320, 150, 55 } },
			clampMin = -30, clampMax = 230,
			baseTargets = { Red = Vector3.new(-560, 55, -300), Blue = Vector3.new(520, 55, 320) },
		},
	},

	-- ---- SCHNEE ---------------------------------------------------------
	{
		id = "snow_glacier",
		name = "Glacier Pass",
		theme = "snow",
		seed = 347,
		layout = {
			waterLevel = 4,
			baseHeight = 20, baseAmp = 24, baseFreq = 0.0016,
			edge = { start = 0.55, span = 0.42, height = 178, noiseAmp = 112, noiseFreq = 0.0042 },
			hills = { { 0, -500, 480, 100 }, { -280, 120, 340, 70 }, { 320, -160, 360, 60 }, { 0, 40, 160, 55 } },
			lakes = { { -180, 250, 140, -10 }, { 220, -300, 130, -10 } },
			corridor = { amp = 160, freq = 0.004, width = 320, depth = 24 },
			plateaus = { { -400, -300, 130, 120 }, { 380, 340, 130, 120 }, { 60, -780, 160, 58 }, { -70, 760, 160, 58 } },
			clampMin = -30, clampMax = 248,
			baseTargets = { Red = Vector3.new(60, 58, -780), Blue = Vector3.new(-70, 58, 760) },
		},
	},
	{
		id = "snow_valley",
		name = "Frozen Hollow",
		theme = "snow",
		seed = 421,
		layout = {
			waterLevel = 4,
			baseHeight = 22, baseAmp = 22, baseFreq = 0.0017,
			edge = { start = 0.58, span = 0.4, height = 165, noiseAmp = 100, noiseFreq = 0.004 },
			hills = { { 0, -560, 420, 92 }, { 0, 560, 420, 92 }, { -360, 0, 300, 62 }, { 360, 0, 300, 62 } },
			lakes = { { 0, 0, 220, -12 } },
			corridor = nil,
			plateaus = { { -430, 260, 130, 104 }, { 430, -260, 130, 104 }, { -600, 80, 150, 54 }, { 600, -80, 150, 54 } },
			clampMin = -30, clampMax = 240,
			baseTargets = { Red = Vector3.new(-600, 54, 80), Blue = Vector3.new(600, 54, -80) },
		},
	},

	-- ---- WUESTE ---------------------------------------------------------
	{
		id = "desert_dunes",
		name = "Dune Sea",
		theme = "desert",
		seed = 512,
		layout = {
			waterLevel = -50, -- kein Wasser
			baseHeight = 22, baseAmp = 30, baseFreq = 0.0018,
			edge = { start = 0.58, span = 0.42, height = 160, noiseAmp = 96, noiseFreq = 0.0044 },
			hills = { { -200, -200, 380, 55 }, { 250, 250, 400, 50 }, { 0, 0, 300, 40 }, { -350, 300, 260, 45 }, { 300, -350, 280, 48 } },
			lakes = {},
			corridor = { amp = 150, freq = 0.0038, width = 280, depth = 26 },
			plateaus = { { -420, 0, 140, 110 }, { 420, 60, 140, 110 }, { 30, -800, 160, 58 }, { -50, 790, 160, 58 } },
			clampMin = -30, clampMax = 235,
			baseTargets = { Red = Vector3.new(30, 58, -800), Blue = Vector3.new(-50, 58, 790) },
		},
	},
	{
		id = "desert_canyon",
		name = "Rift Canyon",
		theme = "desert",
		seed = 673,
		layout = {
			waterLevel = -50, -- kein Wasser (Trockenbecken)
			baseHeight = 20, baseAmp = 24, baseFreq = 0.0016,
			edge = { start = 0.6, span = 0.4, height = 168, noiseAmp = 104, noiseFreq = 0.004 },
			hills = { { 0, -500, 420, 60 }, { 0, 500, 420, 60 }, { -300, 0, 300, 50 }, { 300, 0, 300, 50 } },
			lakes = { { -150, 250, 140, -16 }, { 200, -260, 140, -16 } },
			corridor = { amp = 120, freq = 0.005, width = 240, depth = 34 },
			plateaus = { { -430, 260, 130, 112 }, { 430, -260, 130, 112 }, { -610, -40, 150, 56 }, { 610, 40, 150, 56 } },
			clampMin = -34, clampMax = 235,
			baseTargets = { Red = Vector3.new(-610, 56, -40), Blue = Vector3.new(610, 56, 40) },
		},
	},
}

-- ============================================================
-- HELFER
-- ============================================================
function MapPool.get(id: string)
	for _, def in MapPool.Pool do
		if def.id == id then
			return def
		end
	end
	return nil
end

function MapPool.pickRandom(rng: Random)
	return MapPool.Pool[rng:NextInteger(1, #MapPool.Pool)]
end

return MapPool
