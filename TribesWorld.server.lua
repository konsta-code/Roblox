-- TribesWorld.server.lua
-- Large open Tribes-style world as real Roblox Terrain (smooth + collidable +
-- water lakes). Ports the approved Blender design height field to voxels. No FBX
-- import needed. Replaces the old symmetric NaturalTerrain when NEW_WORLD is on.
--
-- MapBuilder still owns the bases/flags/spawns/stations (moved onto this world),
-- but this terrain is now the collision surface for the ground.

local Workspace = game:GetService("Workspace")

if Workspace:GetAttribute("UseTribesWorld") == false then
	return
end

-- Shared design constants (keep in sync with MapBuilder base placement).
local TribesWorldConfig = {
	BlueBase = Vector3.new(-90, 60, 780),
	RedBase = Vector3.new(40, 60, -800),
	WaterLevel = 6,
}
Workspace:SetAttribute("TribesWorldReady", false)
_G.TribesWorldConfig = TribesWorldConfig

-- Bounds MUST be multiples of RES (4) so Region3:ExpandToGrid does not resize the
-- chunk and desync the voxel arrays.
local X_MIN, X_MAX = -760, 760
local Z_MIN, Z_MAX = -952, 952
local WATER = TribesWorldConfig.WaterLevel

-- ============================================================
-- HEIGHT FIELD  (mirrors build_tribes_world.py terrain_height)
-- ============================================================
local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function clamp(v, a, b)
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

local function hill(x, z, cx, cz, radius, height): number
	local d = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2) / radius
	return height * smoothstep(1 - clamp(d, 0, 1))
end

local LAKES = { { -150, 300, 120 }, { 250, 560, 130 } }
local PLATEAUS = {
	{ -90, 780, 160, 60 }, -- Blue base mesa
	{ 40, -800, 160, 60 }, -- Red base mesa
	{ -430, 380, 130, 116 }, -- Blue outpost
	{ -340, -440, 130, 128 }, -- Red outpost
	{ 360, 430, 150, 4 }, -- Lower valley
}

local function terrainHeight(x: number, z: number): number
	local h = 20 + fbm(x, z, 0.0016, 4) * 24
	local edge = math.max(math.abs(x) / X_MAX, math.abs(z) / Z_MAX)
	h += smoothstep((edge - 0.58) / 0.42) * (150 + fbm(x, z, 0.004, 4) * 95)
	h += hill(x, z, 0, -560, 520, 95)
	h += hill(x, z, -300, -140, 360, 60)
	h += hill(x, z, 360, 120, 420, 55)
	h += hill(x, z, 0, -40, 165, 58)
	h += hill(x, z, 30, 260, 140, 44)
	for _, lake in LAKES do
		local d = math.sqrt((x - lake[1]) ^ 2 + (z - lake[2]) ^ 2) / lake[3]
		local w = smoothstep(1 - clamp(d, 0, 1))
		h = h * (1 - w) + (-12) * w
	end
	for _, p in PLATEAUS do
		local d = math.sqrt((x - p[1]) ^ 2 + (z - p[2]) ^ 2) / p[3]
		local w = smoothstep(1 - clamp((d - 0.5) / 0.5, 0, 1))
		h = h * (1 - w) + p[4] * w
	end
	local corridor = smoothstep(1 - clamp(math.abs(x + math.sin(z * 0.0042) * 150) / 300, 0, 1))
	h -= corridor * 20
	return clamp(h, -30, 235)
end

_G.TribesWorldHeight = terrainHeight

-- ============================================================
-- MATERIAL BY HEIGHT / SLOPE
-- ============================================================
local function surfaceMaterial(x, z, h): Enum.Material
	if h > 155 then
		return Enum.Material.Snow
	end
	-- Approximate slope from a small finite difference. Rock only shows on the
	-- genuinely steep mountain faces / high ground so the map reads as green grass.
	local dh = math.abs(terrainHeight(x + 8, z) - terrainHeight(x - 8, z))
		+ math.abs(terrainHeight(x, z + 8) - terrainHeight(x, z - 8))
	if dh > 60 or h > 128 then
		return Enum.Material.Rock
	end
	if h < WATER + 2 then
		return Enum.Material.Ground
	end
	return Enum.Material.Grass
end

-- ============================================================
-- BUILD
-- ============================================================
local terrain = Workspace:FindFirstChildOfClass("Terrain")
if not terrain then
	return
end

terrain:Clear()
terrain.WaterColor = Color3.fromRGB(28, 84, 96)
terrain.WaterReflectance = 0.25
terrain.WaterTransparency = 0.35
terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(82, 130, 44))
terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(150, 142, 108))
terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(96, 92, 84))
terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(232, 238, 244))

local RES = 4
local Y_MIN, Y_MAX = -40, 244
local CHUNK = 128

for x0 = X_MIN, X_MAX - RES, CHUNK do
	local x1 = math.min(x0 + CHUNK, X_MAX)
	for z0 = Z_MIN, Z_MAX - RES, CHUNK do
		local z1 = math.min(z0 + CHUNK, Z_MAX)
		local sizeX = math.floor((x1 - x0) / RES)
		local sizeY = math.floor((Y_MAX - Y_MIN) / RES)
		local sizeZ = math.floor((z1 - z0) / RES)
		if sizeX < 1 or sizeZ < 1 then
			continue
		end

		local col = table.create(sizeX)
		local colMat = table.create(sizeX)
		for xi = 1, sizeX do
			col[xi] = table.create(sizeZ)
			colMat[xi] = table.create(sizeZ)
			local x = x0 + (xi - 0.5) * RES
			for zi = 1, sizeZ do
				local z = z0 + (zi - 0.5) * RES
				local h = terrainHeight(x, z)
				col[xi][zi] = h
				colMat[xi][zi] = surfaceMaterial(x, z, h)
			end
		end

		local materials = table.create(sizeX)
		local occupancy = table.create(sizeX)
		for xi = 1, sizeX do
			materials[xi] = table.create(sizeY)
			occupancy[xi] = table.create(sizeY)
			for yi = 1, sizeY do
				materials[xi][yi] = table.create(sizeZ)
				occupancy[xi][yi] = table.create(sizeZ)
				local yCenter = Y_MIN + (yi - 0.5) * RES
				for zi = 1, sizeZ do
					local h = col[xi][zi]
					local amount = clamp((h - (yCenter - RES * 0.5)) / RES, 0, 1)
					if amount > 0 then
						occupancy[xi][yi][zi] = amount
						if yCenter >= h - 8 then
							materials[xi][yi][zi] = colMat[xi][zi]
						else
							materials[xi][yi][zi] = Enum.Material.Rock
						end
					elseif h < WATER and yCenter <= WATER then
						-- Fill lakes: water from the carved ground up to the water line.
						occupancy[xi][yi][zi] = 1
						materials[xi][yi][zi] = Enum.Material.Water
					else
						occupancy[xi][yi][zi] = 0
						materials[xi][yi][zi] = Enum.Material.Air
					end
				end
			end
		end

		local region = Region3.new(Vector3.new(x0, Y_MIN, z0), Vector3.new(x1, Y_MAX, z1)):ExpandToGrid(RES)
		terrain:WriteVoxels(region, RES, materials, occupancy)
		task.wait()
	end
end

-- ============================================================
-- POST-PROCESS: retire the old symmetric ground + move bases here
-- ============================================================
local map = Workspace:WaitForChild("TribesMapLive", 20)
if map then
	-- The old MapBuilder ground (routes/kickers/scenery) is obsolete now that
	-- real terrain is the collision surface. Hide + de-collide it.
	local obsolete = {
		"Terrain", "Kickers", "SideRoutes", "HighlandRimRoutes",
		"CrossRoutes", "Backfield", "CanyonScenery", "RouteLights", "Ground",
	}
	for _, folderName in obsolete do
		local folder = map:FindFirstChild(folderName)
		if folder then
			if folder:IsA("BasePart") then
				folder.Transparency = 1
				folder.CanCollide = false
				folder.CanQuery = false
			else
				for _, d in folder:GetDescendants() do
					if d:IsA("BasePart") then
						d.Transparency = 1
						d.CanCollide = false
						d.CanQuery = false
						d.CastShadow = false
					end
				end
			end
		end
	end

	-- Rigidly relocate each base folder onto its new plateau (all tagged
	-- children -- generator, station, turret, flag stand, spawns -- move with it,
	-- keeping every tag + Team attribute, so gameplay wiring is untouched).
	local baseTargets = {
		Red = { pos = TribesWorldConfig.RedBase, oldX = -570 },
		Blue = { pos = TribesWorldConfig.BlueBase, oldX = 570 },
	}
	for teamName, target in baseTargets do
		local base = map:FindFirstChild(teamName .. "Base")
		if base then
			local oldAnchor = CFrame.new(target.oldX, 20, 0)
			local newAnchor = CFrame.new(target.pos.X, target.pos.Y + 2, target.pos.Z)
				* CFrame.Angles(0, math.rad(-90), 0)
			local delta = newAnchor * oldAnchor:Inverse()
			for _, part in base:GetDescendants() do
				if part:IsA("BasePart") then
					part.CFrame = delta * part.CFrame
				end
			end
		end
	end
end

Workspace:SetAttribute("TribesWorldReady", true)
print("[TribesWorld] large open terrain generated + bases relocated")
