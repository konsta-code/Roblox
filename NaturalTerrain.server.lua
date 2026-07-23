-- Smooth alpine terrain pass for the procedural Titan CTF layout.
-- MapBuilder remains responsible for objectives and bases; this script turns
-- its segmented route profiles into one continuous, skiable snow landscape.

local Workspace = game:GetService("Workspace")

-- Superseded by TribesWorld.server.lua (large open world). Skip unless explicitly
-- switched back to the old symmetric terrain.
if Workspace:GetAttribute("UseTribesWorld") ~= false then return end

local map = Workspace:WaitForChild("TribesMapLive", 20)
if not map then return end

local resolutionDeadline = os.clock() + 4
while Workspace:GetAttribute("TitanImportedArtResolved") == nil and os.clock() < resolutionDeadline do
	task.wait(0.05)
end
if Workspace:GetAttribute("TitanImportedArtReady") == true then
	print("[NaturalTerrain] imported Blender landscape active; terrain fallback skipped")
	return
end

local terrain = Workspace:FindFirstChildOfClass("Terrain")
if not terrain then return end

terrain:Clear()
terrain.Decoration = true
terrain.WaterColor = Color3.fromRGB(96, 128, 120)
terrain.WaterReflectance = 0.18
terrain.WaterTransparency = 0.34
-- Tribes sunset palette: saturated rolling grass with pale, worn-down spines and
-- warm grey rock where the hills break through. Sunset lighting warms all of this.
-- Strongly saturated greens so they survive the warm sunset light instead of
-- washing out to desert sand.
terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(82, 152, 40))
terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(62, 122, 36))
terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(150, 148, 116))
terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(102, 104, 92))
terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(84, 86, 78))

local mainProfile = {
	{ -535, 24 }, { -450, -4 }, { -345, 25 }, { -235, -12 }, { -120, 38 },
	{ 0, -8 }, { 120, 38 }, { 235, -12 }, { 345, 25 }, { 450, -4 }, { 535, 24 },
}
local sideProfile = {
	{ -535, 24 }, { -420, 6 }, { -320, 28 }, { -210, -14 }, { -100, 22 },
	{ 0, 46 }, { 100, 22 }, { 210, -14 }, { 320, 28 }, { 420, 6 }, { 535, 24 },
}
local rimProfile = {
	{ -535, 24 }, { -420, 46 }, { -300, 8 }, { -170, 58 }, { 0, 20 },
	{ 170, 58 }, { 300, 8 }, { 420, 46 }, { 535, 24 },
}

local function smoothstep(value: number): number
	local x = math.clamp(value, 0, 1)
	return x * x * (3 - 2 * x)
end

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

local function sampleProfile(profile, x: number): number
	if x <= profile[1][1] then return profile[1][2] end
	if x >= profile[#profile][1] then return profile[#profile][2] end
	for index = 1, #profile - 1 do
		local a, b = profile[index], profile[index + 1]
		if x >= a[1] and x <= b[1] then
			return lerp(a[2], b[2], (x - a[1]) / (b[1] - a[1]))
		end
	end
	return 0
end

local function landscapeHeight(x: number, z: number): number
	local clampedX = math.clamp(x, -535, 535)
	local mainHeight = sampleProfile(mainProfile, clampedX)
	local sideHeight = sampleProfile(sideProfile, clampedX)
	local rimHeight = sampleProfile(rimProfile, clampedX)
	local absZ = math.abs(z)
	local height: number

	if absZ <= 140 then
		height = mainHeight
	elseif absZ <= 250 then
		height = lerp(mainHeight, sideHeight, smoothstep((absZ - 140) / 110))
	elseif absZ <= 325 then
		height = sideHeight
	elseif absZ <= 395 then
		height = lerp(sideHeight, rimHeight, smoothstep((absZ - 325) / 70))
	else
		height = rimHeight
		local outer = smoothstep((absZ - 395) / 145)
		height += outer * (62 + math.noise(x * 0.004, z * 0.004, 11) * 18)
	end

	local absX = math.abs(x)
	if absX > 535 then
		if absX <= 620 then
			height = lerp(height, 18, smoothstep((absX - 535) / 85))
		else
			local backfield = smoothstep((absX - 620) / 180)
			height = lerp(18, 78 + math.noise(x * 0.004, z * 0.003, 23) * 13, backfield)
		end
	end

	-- Broad erosion adds natural variation without putting speed-killing bumps
	-- into the core route. The small term prevents a perfectly synthetic plane.
	local routeWeight = math.clamp(1 - math.max(math.abs(x) - 600, absZ - 430) / 160, 0, 1)
	local broadNoise = math.noise(x * 0.0023, z * 0.0027, 47) * lerp(8, 1.6, routeWeight)
	local snowRipple = math.noise(x * 0.011, z * 0.009, 91) * lerp(2.8, 0.55, routeWeight)
	height += broadNoise + snowRipple

	-- Bases sit on deliberate metal pads. Keep the snow bowl beneath them low
	-- and blend back into the routes instead of burying doors and flag stands.
	for _, baseX in { -570, 570 } do
		local dx = math.abs(x - baseX)
		if dx < 72 and absZ < 92 then
			local baseBlend = smoothstep(1 - math.max(dx / 72, absZ / 92))
			height = lerp(height, 18, baseBlend)
		end
	end

	return math.clamp(height, -20, 155)
end

local function surfaceMaterial(x: number, z: number, height: number): Enum.Material
	-- Pale, wind-worn streaks run down the steep hill spines (the signature
	-- lighter erosion lines in the Tribes screenshots). Kept rarer so the map
	-- reads as green grass, not sand.
	local streak = math.noise(x * 0.006, z * 0.02, 133)
	if streak > 0.42 and height > 24 then
		return Enum.Material.Ground
	end
	-- Exposed rock only on the far highland rim.
	if math.abs(z) > 480 and height < 48 then
		return Enum.Material.Rock
	end
	-- Lusher, darker grass pools in the valley floors.
	if height < 6 then
		return Enum.Material.LeafyGrass
	end
	return Enum.Material.Grass
end

local RESOLUTION = 4
local MIN_X, MAX_X = -800, 800
local MIN_Y, MAX_Y = -112, 192
local MIN_Z, MAX_Z = -544, 544
local CHUNK_STUDS = 192

for x0 = MIN_X, MAX_X - RESOLUTION, CHUNK_STUDS do
	local x1 = math.min(x0 + CHUNK_STUDS, MAX_X)
	for z0 = MIN_Z, MAX_Z - RESOLUTION, CHUNK_STUDS do
		local z1 = math.min(z0 + CHUNK_STUDS, MAX_Z)
		local sizeX = math.floor((x1 - x0) / RESOLUTION)
		local sizeY = math.floor((MAX_Y - MIN_Y) / RESOLUTION)
		local sizeZ = math.floor((z1 - z0) / RESOLUTION)
		local heights = table.create(sizeX)
		local surfaceMaterials = table.create(sizeX)

		for xi = 1, sizeX do
			heights[xi] = table.create(sizeZ)
			surfaceMaterials[xi] = table.create(sizeZ)
			local x = x0 + (xi - 0.5) * RESOLUTION
			for zi = 1, sizeZ do
				local z = z0 + (zi - 0.5) * RESOLUTION
				local height = landscapeHeight(x, z)
				heights[xi][zi] = height
				surfaceMaterials[xi][zi] = surfaceMaterial(x, z, height)
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
				local yCenter = MIN_Y + (yi - 0.5) * RESOLUTION
				for zi = 1, sizeZ do
					local height = heights[xi][zi]
					local amount = math.clamp((height - (yCenter - RESOLUTION * 0.5)) / RESOLUTION, 0, 1)
					occupancy[xi][yi][zi] = amount
					if amount <= 0 then
						materials[xi][yi][zi] = Enum.Material.Air
					elseif yCenter >= height - 10 then
						materials[xi][yi][zi] = surfaceMaterials[xi][zi]
					else
						materials[xi][yi][zi] = Enum.Material.Rock
					end
				end
			end
		end

		local region = Region3.new(
			Vector3.new(x0, MIN_Y, z0),
			Vector3.new(x1, MAX_Y, z1)
		):ExpandToGrid(RESOLUTION)
		terrain:WriteVoxels(region, RESOLUTION, materials, occupancy)
		task.wait()
	end
end

local terrainVisuals = Instance.new("Folder")
terrainVisuals.Name = "NaturalTerrainVisuals"
terrainVisuals.Parent = map

local function addRoundedKicker(source: BasePart)
	local visual = Instance.new("Part")
	visual.Name = source.Name .. "GrassDrift"
	visual.Size = Vector3.one
	visual.CFrame = source.CFrame * CFrame.new(0, source.Size.Y * 0.5 - 2.5, 0)
	visual.Color = Color3.fromRGB(96, 132, 54)
	visual.Material = Enum.Material.Grass
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanTouch = false
	visual.CanQuery = false
	visual.CastShadow = true
	visual.Parent = terrainVisuals
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(source.Size.X + 8, 8, source.Size.Z + 12)
	mesh.Parent = visual
end

local collisionFolders = { "Terrain", "SideRoutes", "HighlandRimRoutes", "CrossRoutes", "Backfield" }
for _, folderName in collisionFolders do
	local folder = map:FindFirstChild(folderName)
	if folder then
		for _, descendant in folder:GetDescendants() do
			if descendant:IsA("BasePart") then
				local isKicker = string.find(descendant.Name, "Kicker", 1, true) ~= nil
				descendant.Transparency = 1
				descendant.CastShadow = false
				descendant.CanCollide = isKicker
				descendant.CanQuery = isKicker
				if isKicker then addRoundedKicker(descendant) end
			end
		end
	end
end

local kickerFolder = map:FindFirstChild("Kickers")
if kickerFolder then
	for _, descendant in kickerFolder:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CastShadow = false
			addRoundedKicker(descendant)
		end
	end
end

local ground = map:FindFirstChild("Ground")
if ground and ground:IsA("BasePart") then
	ground.Transparency = 1
	ground.CanCollide = false
	ground.CanQuery = false
	ground.CastShadow = false
end

local scenery = map:FindFirstChild("CanyonScenery")
if scenery then
	for _, descendant in scenery:GetChildren() do
		if descendant:IsA("BasePart") and (string.find(descendant.Name, "CanyonSpire", 1, true)
			or string.find(descendant.Name, "SnowCap", 1, true)) then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CastShadow = false
		end
	end
end

Workspace:SetAttribute("NaturalTerrainReady", true)
print("[NaturalTerrain] continuous rolling grass terrain generated")
