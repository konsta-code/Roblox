-- TribesSunset.server.lua
-- Final visual pass that turns the cold alpine arena into the warm Starsiege:
-- Tribes evening look. Runs LAST (after MapBuilder / MapArt / NaturalTerrain) and
-- is purely cosmetic + additive, so it never touches gameplay geometry, spawns,
-- flags or collisions.
--
--   1. Re-skins the cold snow/ice/metal palette to warm stone / moss / bronze.
--   2. Scatters flat-topped acacia trees onto the grass by ray-casting the terrain.
--   3. Hangs a big hazy moon low over the ridgeline.
--   4. Drops a few distant base silhouettes into the haze for depth.
--   5. Adds a soft warm glow at each team base.
--
-- Everything lives under workspace.TribesMapLive.TribesSunsetDressing and is
-- rebuilt idempotently, so re-running the server just refreshes it.

local Workspace = game:GetService("Workspace")

-- ============================================================
-- TUNABLES  (safe to tweak after seeing it in Studio)
-- ============================================================
local TREE_COUNT = 42
local TREE_SEED = 91237

local MOON_POSITION = Vector3.new(-1250, 780, 1650)
local MOON_SIZE = 900
local MOON_COLOR = Color3.fromRGB(248, 232, 214)

local MOSS = Color3.fromRGB(70, 98, 44)
local MOSS_DARK = Color3.fromRGB(56, 82, 38)
local BARK = Color3.fromRGB(74, 52, 34)

-- ============================================================
-- WAIT FOR THE MAP / TERRAIN
-- ============================================================
local map = Workspace:WaitForChild("TribesMapLive", 20)
if not map then return end

local terrain = Workspace:FindFirstChildOfClass("Terrain")

-- Give NaturalTerrain a moment to finish writing voxels so tree ray-casts land.
local deadline = os.clock() + 12
while Workspace:GetAttribute("NaturalTerrainReady") ~= true and os.clock() < deadline do
	task.wait(0.1)
end

local old = map:FindFirstChild("TribesSunsetDressing")
if old then old:Destroy() end

local dressing = Instance.new("Folder")
dressing.Name = "TribesSunsetDressing"
dressing.Parent = map

-- ============================================================
-- 1) WARM PALETTE RE-SKIN
-- ============================================================
-- Nearest-match remap: only parts whose colour is close to a known cold palette
-- entry get swapped, so team red/blue and Neon glow accents are left alone.
local COLD_TO_WARM = {
	{ from = Color3.fromRGB(218, 228, 237), to = Color3.fromRGB(206, 194, 168) }, -- snow      -> sandstone
	{ from = Color3.fromRGB(178, 197, 214), to = Color3.fromRGB(180, 166, 140) }, -- snow shade-> stone
	{ from = Color3.fromRGB(128, 173, 207), to = Color3.fromRGB(126, 138, 98) },  -- ice       -> moss stone
	{ from = Color3.fromRGB(175, 210, 231), to = Color3.fromRGB(150, 150, 120) }, -- ice light -> pale moss
	{ from = Color3.fromRGB(96, 102, 108),  to = Color3.fromRGB(96, 92, 80) },    -- rock grey -> warm stone
	{ from = Color3.fromRGB(55, 64, 74),    to = Color3.fromRGB(64, 58, 50) },    -- dark rock -> dark stone
	{ from = Color3.fromRGB(73, 67, 64),    to = Color3.fromRGB(78, 68, 56) },    -- warm rock -> keep warm
	{ from = Color3.fromRGB(36, 46, 59),    to = Color3.fromRGB(48, 40, 32) },    -- metal     -> dark bronze
	{ from = Color3.fromRGB(84, 100, 117),  to = Color3.fromRGB(120, 104, 78) },  -- light metal-> bronze
}
local THRESHOLD_SQ = 74 * 74

-- Team identity colours must never be re-skinned, even when a cold-palette entry
-- happens to sit nearby (Blue is close to the light-metal grey).
local PROTECTED = {
	Color3.fromRGB(170, 52, 52),  -- Red team
	Color3.fromRGB(52, 88, 172),  -- Blue team
}
local PROTECT_SQ = 52 * 52

local function colorDistSq(a: Color3, b: Color3): number
	local dr = (a.R - b.R) * 255
	local dg = (a.G - b.G) * 255
	local db = (a.B - b.B) * 255
	return dr * dr + dg * dg + db * db
end

local function isProtected(color: Color3): boolean
	for _, guard in PROTECTED do
		if colorDistSq(color, guard) < PROTECT_SQ then
			return true
		end
	end
	return false
end

local reskinned = 0
for _, inst in map:GetDescendants() do
	if inst:IsA("BasePart") and inst.Material ~= Enum.Material.Neon and not isProtected(inst.Color) then
		local best, bestDist = nil, THRESHOLD_SQ
		for _, pair in COLD_TO_WARM do
			local d = colorDistSq(inst.Color, pair.from)
			if d < bestDist then
				best, bestDist = pair.to, d
			end
		end
		if best then
			inst.Color = best
			reskinned += 1
		end
	end
end

-- ============================================================
-- 2) ACACIA TREES
-- ============================================================
local function buildAcacia(scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Acacia"

	local trunkH = 13 * scale
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(1.5 * scale, trunkH, 1.5 * scale)
	trunk.CFrame = CFrame.new(0, trunkH * 0.5, 0)
	trunk.Color = BARK
	trunk.Material = Enum.Material.Wood
	trunk.Anchored = true
	trunk.CanCollide = false
	trunk.CanQuery = false
	trunk.CastShadow = true
	local trunkMesh = Instance.new("CylinderMesh")
	trunkMesh.Parent = trunk
	trunk.Parent = model
	model.PrimaryPart = trunk

	local function disc(name, dia, thick, y, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(dia * scale, thick * scale, dia * scale)
		p.CFrame = CFrame.new(0, y * scale, 0)
		p.Color = color
		p.Material = Enum.Material.Grass
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = true
		local mesh = Instance.new("CylinderMesh")
		mesh.Parent = p
		p.Parent = model
	end

	-- Flat, wide umbrella crown — the acacia silhouette.
	disc("CanopyLow", 21, 2.4, 13, MOSS)
	disc("CanopyTop", 14, 2.8, 15.4, MOSS_DARK)

	return model
end

if terrain then
	local rng = Random.new(TREE_SEED)
	local castParams = RaycastParams.new()
	castParams.FilterType = Enum.RaycastFilterType.Include
	castParams.FilterDescendantsInstances = { terrain }

	local treeFolder = Instance.new("Folder")
	treeFolder.Name = "Acacias"
	treeFolder.Parent = dressing

	local placed, attempts = 0, 0
	while placed < TREE_COUNT and attempts < TREE_COUNT * 12 do
		attempts += 1
		local x = rng:NextNumber(-780, 780)
		local z = rng:NextNumber(-520, 520)

		-- Keep the central ski lane and the base pads clear.
		if math.abs(z) < 130 and math.abs(x) < 560 then continue end
		if math.abs(x) > 540 and math.abs(z) < 110 then continue end

		local result = Workspace:Raycast(Vector3.new(x, 260, z), Vector3.new(0, -520, 0), castParams)
		if result and result.Normal.Y > 0.86 and result.Position.Y > 10 then
			local scale = rng:NextNumber(0.85, 1.5)
			local tree = buildAcacia(scale)
			tree:PivotTo(
				CFrame.new(result.Position - Vector3.new(0, 1.2, 0))
					* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			)
			tree.Parent = treeFolder
			placed += 1
		end
	end
	print(("[TribesSunset] placed %d acacia trees"):format(placed))
end

-- ============================================================
-- 3) BIG HAZY MOON
-- ============================================================
local moon = Instance.new("Part")
moon.Name = "SunsetMoon"
moon.Shape = Enum.PartType.Ball
moon.Size = Vector3.new(MOON_SIZE, MOON_SIZE, MOON_SIZE)
moon.Position = MOON_POSITION
moon.Color = MOON_COLOR
moon.Material = Enum.Material.Neon        -- stays visible through the horizon haze
moon.Anchored = true
moon.CanCollide = false
moon.CanQuery = false
moon.CastShadow = false
moon.Locked = true
moon.Parent = dressing

-- ============================================================
-- 4) DISTANT BASE SILHOUETTES (depth in the haze)
-- ============================================================
local silFolder = Instance.new("Folder")
silFolder.Name = "HorizonSilhouettes"
silFolder.Parent = dressing

local SIL_SPOTS = {
	{ pos = Vector3.new(-1350, 96, -1150), rot = 0.5,  size = Vector3.new(74, 46, 52) },
	{ pos = Vector3.new(1450, 104, 1250),  rot = -0.7, size = Vector3.new(64, 56, 46) },
	{ pos = Vector3.new(1250, 88, -1450),  rot = 2.1,  size = Vector3.new(58, 40, 58) },
}
for i, spot in SIL_SPOTS do
	local sil = Instance.new("Part")
	sil.Name = "DistantBase" .. i
	sil.Size = spot.size
	sil.CFrame = CFrame.new(spot.pos) * CFrame.Angles(0, spot.rot, 0)
	sil.Color = Color3.fromRGB(46, 42, 38)
	sil.Material = Enum.Material.Slate
	sil.Anchored = true
	sil.CanCollide = false
	sil.CanQuery = false
	sil.CastShadow = false
	sil.Parent = silFolder
end

-- ============================================================
-- 5) WARM GLOW AT EACH BASE
-- ============================================================
for _, teamName in { "Red", "Blue" } do
	local base = map:FindFirstChild(teamName .. "Base")
	if base then
		local anchor = base:IsA("BasePart") and base or base:FindFirstChildWhichIsA("BasePart", true)
		if anchor then
			local glow = Instance.new("Part")
			glow.Name = teamName .. "BaseGlow"
			glow.Size = Vector3.new(2, 2, 2)
			glow.CFrame = anchor.CFrame + Vector3.new(0, 10, 0)
			glow.Transparency = 1
			glow.Anchored = true
			glow.CanCollide = false
			glow.CanQuery = false
			glow.CastShadow = false
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 188, 120)
			light.Brightness = 2.2
			light.Range = 42
			light.Parent = glow
			glow.Parent = dressing
		end
	end
end

Workspace:SetAttribute("TribesSunsetReady", true)
print(("[TribesSunset] warm sunset dressing applied (%d parts re-skinned)"):format(reskinned))
