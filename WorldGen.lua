-- WorldGen.lua
-- Ablageort: ServerScriptService (ModuleScript, von MapDirector benutzt)
--
-- Parametrischer Terrain-Generator. Baut aus einer Map-Def (siehe
-- MapPoolConstants) reales Roblox-Terrain als Voxel. Ersetzt die fest
-- verdrahtete Generierung aus dem alten TribesWorld-Script.
--
-- Optimierungen ggue. TribesWorld:
--   * dynamischer Y-Bereich pro Chunk (nur bis knapp ueber die hoechste Spalte
--     bzw. Wasserlinie) -> flaches Kernland braucht ~1/3 der Voxel-Ebenen
--   * Oberflaechen-Material + Slope werden pro Spalte EINMAL vorberechnet
--     (kein 4x terrainHeight je Zelle mehr)
--   * groessere Chunks (192) -> weniger WriteVoxels-Overhead

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapPool = require(ReplicatedStorage.Modules.MapPoolConstants)

local WorldGen = {}

-- ============================================================
-- MATHE-HELFER
-- ============================================================
local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function clampn(v: number, a: number, b: number): number
	return math.max(a, math.min(b, v))
end

local function fbm(x: number, z: number, scale: number, octaves: number): number
	local total, amp, freq, norm = 0, 1, scale, 0
	for i = 1, octaves do
		total += amp * math.noise(x * freq, z * freq, i * 3.17)
		norm += amp
		amp *= 0.5
		freq *= 2
	end
	return total / norm
end

local function hill(x: number, z: number, cx: number, cz: number, r: number, h: number): number
	local d = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2) / r
	return h * smoothstep(1 - clampn(d, 0, 1))
end

-- ============================================================
-- HOEHENFELD  (rein aus mapDef.layout parametrisiert)
-- Reihenfolge: base+fbm -> edge -> hills(+) -> lakes(carve) -> corridor(carve)
--              -> plateaus(override zuletzt, damit Basen/Outposts flach liegen)
-- ============================================================
function WorldGen.makeHeightFn(mapDef)
	local L = mapDef.layout
	local B = MapPool.Bounds
	local off = (mapDef.seed or 0) * 2.7 + 40 -- Seed verschiebt das Rauschen

	return function(x: number, z: number): number
		local h = L.baseHeight + fbm(x + off, z + off, L.baseFreq, 4) * L.baseAmp

		local edge = math.max(math.abs(x) / B.xMax, math.abs(z) / B.zMax)
		local e = L.edge
		h += smoothstep((edge - e.start) / e.span) * (e.height + fbm(x + off, z + off, e.noiseFreq, 4) * e.noiseAmp)

		for _, hl in L.hills do
			h += hill(x, z, hl[1], hl[2], hl[3], hl[4])
		end

		for _, lk in L.lakes do
			local d = math.sqrt((x - lk[1]) ^ 2 + (z - lk[2]) ^ 2) / lk[3]
			local w = smoothstep(1 - clampn(d, 0, 1))
			h = h * (1 - w) + lk[4] * w
		end

		if L.corridor then
			local c = L.corridor
			local carve = smoothstep(1 - clampn(math.abs(x + math.sin(z * c.freq) * c.amp) / c.width, 0, 1))
			h -= carve * c.depth
		end

		for _, p in L.plateaus do
			local d = math.sqrt((x - p[1]) ^ 2 + (z - p[2]) ^ 2) / p[3]
			local w = smoothstep(1 - clampn((d - 0.5) / 0.5, 0, 1))
			h = h * (1 - w) + p[4] * w
		end

		return clampn(h, L.clampMin, L.clampMax)
	end
end

-- ============================================================
-- MATERIAL nach Hoehe / Steigung / Theme
-- ============================================================
local function surfaceMaterial(theme, h: number, slope: number, waterLevel: number): Enum.Material
	local b = theme.bands
	local m = theme.materials
	if h > b.peakHeight then
		return m.peak
	end
	if slope > b.rockSlope or h > b.rockHeight then
		return m.rock
	end
	if h < waterLevel + 2 then
		return m.shore
	end
	return m.base
end

-- ============================================================
-- BUILD
-- ============================================================
-- Gibt { heightFn, theme, baseTargets, mapDef } zurueck (nil, falls kein Terrain).
function WorldGen.build(mapDef)
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		return nil
	end

	local L = mapDef.layout
	local B = MapPool.Bounds
	local theme = MapPool.Themes[mapDef.theme]
	local heightFn = WorldGen.makeHeightFn(mapDef)

	terrain:Clear()
	terrain.WaterColor = theme.water.color
	terrain.WaterReflectance = theme.water.reflectance
	terrain.WaterTransparency = theme.water.transparency
	for _, pair in theme.colors do
		terrain:SetMaterialColor(pair[1], pair[2])
	end

	local RES = 4
	local CHUNK = 192
	local xMin, xMax = -B.xMax, B.xMax
	local zMin, zMax = -B.zMax, B.zMax
	local waterLevel = L.waterLevel
	local rockMat = theme.materials.rock
	local waterMat = Enum.Material.Water
	local airMat = Enum.Material.Air
	local yFloor = math.floor(math.max(L.clampMin - 2, -40) / RES) * RES

	for x0 = xMin, xMax - RES, CHUNK do
		local x1 = math.min(x0 + CHUNK, xMax)
		for z0 = zMin, zMax - RES, CHUNK do
			local z1 = math.min(z0 + CHUNK, zMax)
			local sizeX = math.floor((x1 - x0) / RES)
			local sizeZ = math.floor((z1 - z0) / RES)
			if sizeX < 1 or sizeZ < 1 then
				continue
			end

			-- 1) Hoehen-Grid + hoechster Punkt (fuer dynamischen Y-Deckel)
			local col = table.create(sizeX)
			local chunkMax = -math.huge
			for xi = 1, sizeX do
				col[xi] = table.create(sizeZ)
				local x = x0 + (xi - 0.5) * RES
				for zi = 1, sizeZ do
					local z = z0 + (zi - 0.5) * RES
					local hh = heightFn(x, z)
					col[xi][zi] = hh
					if hh > chunkMax then
						chunkMax = hh
					end
				end
			end

			-- 2) Oberflaechen-Material je Spalte (Slope aus Grid-Nachbarn)
			local surf = table.create(sizeX)
			for xi = 1, sizeX do
				surf[xi] = table.create(sizeZ)
				local x = x0 + (xi - 0.5) * RES
				for zi = 1, sizeZ do
					local z = z0 + (zi - 0.5) * RES
					local hh = col[xi][zi]
					local hxp = if xi < sizeX then col[xi + 1][zi] else heightFn(x + RES, z)
					local hxm = if xi > 1 then col[xi - 1][zi] else heightFn(x - RES, z)
					local hzp = if zi < sizeZ then col[xi][zi + 1] else heightFn(x, z + RES)
					local hzm = if zi > 1 then col[xi][zi - 1] else heightFn(x, z - RES)
					local slope = math.abs(hxp - hxm) + math.abs(hzp - hzm)
					surf[xi][zi] = surfaceMaterial(theme, hh, slope, waterLevel)
				end
			end

			-- 3) dynamischer Y-Bereich fuer diesen Chunk
			local yTop = math.ceil((math.max(chunkMax, waterLevel) + RES) / RES) * RES
			local yBottom = yFloor
			local sizeY = math.floor((yTop - yBottom) / RES)
			if sizeY < 1 then
				continue
			end

			-- 4) Voxel schreiben
			local materials = table.create(sizeX)
			local occupancy = table.create(sizeX)
			for xi = 1, sizeX do
				materials[xi] = table.create(sizeY)
				occupancy[xi] = table.create(sizeY)
				local colXi = col[xi]
				local surfXi = surf[xi]
				for yi = 1, sizeY do
					local mrow = table.create(sizeZ)
					local orow = table.create(sizeZ)
					materials[xi][yi] = mrow
					occupancy[xi][yi] = orow
					local yCenter = yBottom + (yi - 0.5) * RES
					for zi = 1, sizeZ do
						local hh = colXi[zi]
						local amount = clampn((hh - (yCenter - RES * 0.5)) / RES, 0, 1)
						if amount > 0 then
							orow[zi] = amount
							if yCenter >= hh - 8 then
								mrow[zi] = surfXi[zi]
							else
								mrow[zi] = rockMat
							end
						elseif hh < waterLevel and yCenter <= waterLevel then
							orow[zi] = 1
							mrow[zi] = waterMat
						else
							orow[zi] = 0
							mrow[zi] = airMat
						end
					end
				end
			end

			local region = Region3.new(Vector3.new(x0, yBottom, z0), Vector3.new(x1, yTop, z1)):ExpandToGrid(RES)
			terrain:WriteVoxels(region, RES, materials, occupancy)
			task.wait()
		end
	end

	return { heightFn = heightFn, theme = theme, baseTargets = L.baseTargets, mapDef = mapDef }
end

return WorldGen
