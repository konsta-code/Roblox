-- MapArt.server.lua
-- Non-colliding visual dressing over the collision-safe MapBuilder geometry.
-- Smooth native meshes keep the place playable before cloud FBX imports exist.

local Lighting = game:GetService("Lighting")

local map = workspace:WaitForChild("TribesMapLive", 15)
if not map then return end

local old = map:FindFirstChild("TitanArtPass")
if old then old:Destroy() end

local art = Instance.new("Folder")
art.Name = "TitanArtPass"
art.Parent = map

local random = Random.new(7421)
local SNOW = Color3.fromRGB(218, 228, 237)
local SNOW_SHADE = Color3.fromRGB(178, 197, 214)
local ICE = Color3.fromRGB(128, 173, 207)
local ROCK = Color3.fromRGB(55, 64, 74)
local ROCK_WARM = Color3.fromRGB(73, 67, 64)
local METAL = Color3.fromRGB(36, 46, 59)
local METAL_LIGHT = Color3.fromRGB(84, 100, 117)

local function visualPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	meshType: Enum.MeshType?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = if meshType then Vector3.one else size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	if meshType then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = meshType
		mesh.Scale = size
		mesh.Parent = part
	end
	return part
end

local function smoothEllipsoid(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance)
	return visualPart(name, size, cframe, color, material, parent, Enum.MeshType.Sphere)
end

local function addRockCluster(name: string, position: Vector3, scale: number, warm: boolean)
	local cluster = Instance.new("Folder")
	cluster.Name = name
	cluster.Parent = art
	local baseColor = if warm then ROCK_WARM else ROCK
	for layer = 1, 4 do
		local height = scale * random:NextNumber(0.62, 1.12)
		local width = scale * random:NextNumber(0.42, 0.75)
		local depth = scale * random:NextNumber(0.36, 0.68)
		local offset = Vector3.new(
			random:NextNumber(-scale * 0.28, scale * 0.28),
			height * 0.35 + (layer - 1) * scale * 0.08,
			random:NextNumber(-scale * 0.22, scale * 0.22)
		)
		smoothEllipsoid(
			"WeatheredRock" .. layer,
			Vector3.new(width, height, depth),
			CFrame.new(position + offset)
				* CFrame.Angles(random:NextNumber(-0.18, 0.18), random:NextNumber(0, math.pi), random:NextNumber(-0.22, 0.22)),
			baseColor:Lerp(Color3.fromRGB(105, 112, 120), random:NextNumber(0, 0.18)),
			if layer % 2 == 0 then Enum.Material.Slate else Enum.Material.Rock,
			cluster
		)
	end
	smoothEllipsoid(
		"SnowCap",
		Vector3.new(scale * 0.58, scale * 0.12, scale * 0.48),
		CFrame.new(position + Vector3.new(0, scale * 0.89, 0)) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0),
		SNOW,
		Enum.Material.Snow,
		cluster
	)
end

-- Layered mountain silhouette outside the playable lanes.
for _, zSign in { -1, 1 } do
	for x = -700, 700, 100 do
		local scale = random:NextNumber(48, 92) + (1 - math.abs(x) / 850) * 22
		addRockCluster(
			string.format("%sRange_%d", if zSign < 0 then "North" else "South", x),
			Vector3.new(x + random:NextNumber(-24, 24), -26, zSign * random:NextNumber(470, 510)),
			scale,
			(x / 100 + zSign) % 3 == 0
		)
	end
end
for _, xSign in { -1, 1 } do
	for z = -390, 390, 130 do
		addRockCluster(
			string.format("BackRange_%d_%d", xSign, z),
			Vector3.new(xSign * random:NextNumber(690, 745), -32, z + random:NextNumber(-20, 20)),
			random:NextNumber(54, 86),
			xSign < 0
		)
	end
end

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

local function dressRouteEdges(profile, zEdges: { number }, thickness: number, prefix: string)
	for index = 1, #profile - 1 do
		local a, b = profile[index], profile[index + 1]
		local x0, y0, x1, y1 = a[1], a[2], b[1], b[2]
		local run, rise = x1 - x0, y1 - y0
		local length = math.sqrt(run * run + rise * rise)
		local angle = math.atan2(rise, run)
		for edgeIndex, z in zEdges do
			local color = if (index + edgeIndex) % 3 == 0 then SNOW_SHADE else SNOW
			smoothEllipsoid(
				string.format("%sBank_%d_%d", prefix, index, edgeIndex),
				Vector3.new(length + 14, thickness, thickness * random:NextNumber(1.3, 2)),
				CFrame.new((x0 + x1) * 0.5, (y0 + y1) * 0.5 - thickness * 0.12, z)
					* CFrame.Angles(0, 0, angle),
				color,
				Enum.Material.Snow,
				art
			)
		end
	end
end

dressRouteEdges(mainProfile, { -151, 151 }, 12, "Core")
dressRouteEdges(sideProfile, { -352, 352 }, 14, "Flank")
dressRouteEdges(rimProfile, { -442, 442 }, 16, "Rim")

-- Ice seams break up large single-color route surfaces.
local function sampleProfileHeight(profile, x: number): number
	for index = 1, #profile - 1 do
		local a, b = profile[index], profile[index + 1]
		if x >= a[1] and x <= b[1] then
			local alpha = (x - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * alpha
		end
	end
	return 0
end

for x = -470, 470, 94 do
	for _, z in { -105, 105, -245, 245 } do
		local routeHeight = sampleProfileHeight(if math.abs(z) < 150 then mainProfile else sideProfile, x)
		smoothEllipsoid(
			"WindIce",
			Vector3.new(random:NextNumber(26, 48), random:NextNumber(0.7, 1.4), random:NextNumber(6, 13)),
			CFrame.new(x + random:NextNumber(-16, 16), routeHeight + 0.45, z)
				* CFrame.Angles(0, random:NextNumber(-0.35, 0.35), 0),
			ICE,
			Enum.Material.Glacier,
			art
		).Transparency = 0.18
	end
end

local function addBaseShell(teamName: string, sign: number, color: Color3)
	local folder = Instance.new("Folder")
	folder.Name = teamName .. "ArchitecturalShell"
	folder.Parent = art
	local facing = -sign
	local baseX = 570 * sign

	-- Rounded rear hull and roof canopy hide the rectangular blockout silhouette.
	smoothEllipsoid(
		"RearHull",
		Vector3.new(58, 42, 138),
		CFrame.new(baseX - facing * 49, 36, 0),
		METAL,
		Enum.Material.Metal,
		folder
	)
	smoothEllipsoid(
		"RoofCanopy",
		Vector3.new(78, 10, 104),
		CFrame.new(baseX - facing * 8, 49.5, 0),
		METAL_LIGHT,
		Enum.Material.Metal,
		folder
	)
	for _, z in { -53, 53 } do
		smoothEllipsoid(
			"SidePod",
			Vector3.new(42, 28, 25),
			CFrame.new(baseX - facing * 6, 32, z),
			METAL,
			Enum.Material.Metal,
			folder
		)
	end

	for z = -48, 48, 16 do
		local rib = visualPart(
			"CanopyRib",
			Vector3.new(2.2, 15, 3.2),
			CFrame.new(baseX + facing * 17, 45, z)
				* CFrame.Angles(0, 0, math.rad(facing * -18)),
			color:Lerp(Color3.new(1, 1, 1), 0.12),
			Enum.Material.Metal,
			folder
		)
		rib.Reflectance = 0.18
	end

	for _, z in { -43, 43 } do
		local pylon = visualPart(
			"EnergyPylon",
			Vector3.new(30, 4.2, 4.2),
			CFrame.new(baseX + facing * 26, 38, z) * CFrame.Angles(0, 0, math.rad(90)),
			METAL_LIGHT,
			Enum.Material.Metal,
			folder
		)
		pylon.Shape = Enum.PartType.Cylinder
		local core = visualPart(
			"PylonCore",
			Vector3.new(25, 2.4, 2.4),
			pylon.CFrame,
			color,
			Enum.Material.Neon,
			folder
		)
		core.Shape = Enum.PartType.Cylinder
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 1.2
		light.Range = 20
		light.Parent = core
	end

	for panelIndex = -2, 2 do
		local panel = visualPart(
			"FacadeGlass",
			Vector3.new(1.1, 12, 13),
			CFrame.new(baseX + facing * 42.2, 37, panelIndex * 14),
			color:Lerp(Color3.fromRGB(80, 130, 160), 0.35),
			Enum.Material.Glass,
			folder
		)
		panel.Transparency = 0.34
		panel.Reflectance = 0.12
	end
end

addBaseShell("Red", -1, Color3.fromRGB(212, 63, 57))
addBaseShell("Blue", 1, Color3.fromRGB(55, 121, 230))

-- Low-cost aerial haze planes give the distant canyon real depth.
for index = 1, 3 do
	local haze = visualPart(
		"DistanceHaze" .. index,
		Vector3.new(1500, 1, 1000),
		CFrame.new(0, 95 + index * 38, 0),
		Lighting.FogColor,
		Enum.Material.SmoothPlastic,
		art
	)
	haze.Transparency = 0.985
	haze.CastShadow = false
end

print("[MapArt] smooth alpine terrain dressing and rounded base shells active")
