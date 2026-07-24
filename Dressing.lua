-- Dressing.lua
-- Ablageort: ServerScriptService (ModuleScript, von MapDirector benutzt)
--
-- Rein kosmetischer Schluss-Pass je Theme. Aus TribesSunset.server.lua
-- verallgemeinert: streut Theme-Flora (Akazie / Kiefer / Kaktus) per Raycast,
-- reskinnt optional die kalte Basis-Palette, haengt Himmelskoerper (Mond/Sonne)
-- + ferne Silhouetten in den Dunst und setzt warmes Gluehen an die Basen.
--
-- Alles liegt unter map.MapDressing und wird idempotent neu gebaut. Team-Farben
-- (Rot/Blau) werden beim Re-Skin geschuetzt. Deko wirft KEINE Schatten und ist
-- nicht kollidierbar/abfragbar (Performance).

local Workspace = game:GetService("Workspace")

local rgb = Color3.fromRGB

local Dressing = {}

-- ============================================================
-- KLEINE HELFER
-- ============================================================
local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function cyl(part: BasePart)
	local m = Instance.new("CylinderMesh")
	m.Parent = part
end

-- ============================================================
-- FLORA
-- ============================================================
local BARK = rgb(74, 52, 34)
local MOSS = rgb(70, 98, 44)
local MOSS_DARK = rgb(56, 82, 38)

local function buildAcacia(scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Acacia"
	local trunkH = 13 * scale
	local trunk = newPart("Trunk", Vector3.new(1.5 * scale, trunkH, 1.5 * scale), CFrame.new(0, trunkH * 0.5, 0), BARK, Enum.Material.Wood, model)
	cyl(trunk)
	model.PrimaryPart = trunk
	local low = newPart("CanopyLow", Vector3.new(21 * scale, 2.4 * scale, 21 * scale), CFrame.new(0, 13 * scale, 0), MOSS, Enum.Material.Grass, model)
	cyl(low)
	local top = newPart("CanopyTop", Vector3.new(14 * scale, 2.8 * scale, 14 * scale), CFrame.new(0, 15.4 * scale, 0), MOSS_DARK, Enum.Material.Grass, model)
	cyl(top)
	return model
end

local function buildPine(scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Pine"
	local trunkH = 6 * scale
	local trunk = newPart("Trunk", Vector3.new(1.1 * scale, trunkH, 1.1 * scale), CFrame.new(0, trunkH * 0.5, 0), rgb(74, 54, 38), Enum.Material.Wood, model)
	cyl(trunk)
	model.PrimaryPart = trunk
	local needle = rgb(46, 74, 52)
	for _, t in { { 14, 6, 7 }, { 10, 5, 11 }, { 6, 4.5, 14.5 } } do
		local tier = newPart("Tier", Vector3.new(t[1] * scale, t[2] * scale, t[1] * scale), CFrame.new(0, t[3] * scale, 0), needle, Enum.Material.Grass, model)
		cyl(tier)
	end
	local cap = newPart("SnowCap", Vector3.new(4.5 * scale, 2 * scale, 4.5 * scale), CFrame.new(0, 16.4 * scale, 0), rgb(236, 240, 248), Enum.Material.Snow, model)
	cyl(cap)
	return model
end

local function buildCactus(scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Cactus"
	local green = rgb(74, 108, 62)
	local trunkH = 10 * scale
	local trunk = newPart("Trunk", Vector3.new(2.2 * scale, trunkH, 2.2 * scale), CFrame.new(0, trunkH * 0.5, 0), green, Enum.Material.Grass, model)
	cyl(trunk)
	model.PrimaryPart = trunk
	for _, side in { 1, -1 } do
		local ay = trunkH * 0.55
		local horiz = newPart("ArmH", Vector3.new(0.9 * scale, 3.4 * scale, 0.9 * scale), CFrame.new(side * 1.7 * scale, ay, 0) * CFrame.Angles(0, 0, math.rad(90)), green, Enum.Material.Grass, model)
		cyl(horiz)
		local vert = newPart("ArmV", Vector3.new(1.4 * scale, 4.6 * scale, 1.4 * scale), CFrame.new(side * 3.0 * scale, ay + 2.1 * scale, 0), green, Enum.Material.Grass, model)
		cyl(vert)
	end
	return model
end

local function buildFlora(kind: string, scale: number): Model
	if kind == "pine" then
		return buildPine(scale)
	elseif kind == "cactus" then
		return buildCactus(scale)
	end
	return buildAcacia(scale)
end

-- ============================================================
-- RE-SKIN  (kalte Basis-Palette -> Theme-Palette; Teamfarben geschuetzt)
-- ============================================================
local PROTECTED = { rgb(170, 52, 52), rgb(52, 88, 172) } -- Rot / Blau
local PROTECT_SQ = 52 * 52
local THRESHOLD_SQ = 74 * 74

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

local function reskin(map: Instance, pairs)
	if not pairs then
		return 0
	end
	local count = 0
	for _, inst in map:GetDescendants() do
		if inst:IsA("BasePart") and inst.Material ~= Enum.Material.Neon and not isProtected(inst.Color) then
			local best, bestDist = nil, THRESHOLD_SQ
			for _, pair in pairs do
				local d = colorDistSq(inst.Color, pair.from)
				if d < bestDist then
					best, bestDist = pair.to, d
				end
			end
			if best then
				inst.Color = best
				count += 1
			end
		end
	end
	return count
end

-- ============================================================
-- HAUPTEINSTIEG
-- ============================================================
-- dressing = theme.dressing ; context = { waterLevel = number }
function Dressing.apply(dressing, terrain: Terrain?, map: Instance, context)
	local old = map:FindFirstChild("MapDressing")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "MapDressing"
	folder.Parent = map

	-- 1) Re-Skin zuerst (bevor Deko dazukommt, damit Deko nicht umgefaerbt wird)
	local reskinned = reskin(map, dressing.reskin)

	-- 2) Flora per Raycast auf das Terrain streuen
	local waterLevel = (context and context.waterLevel) or 6
	if terrain and dressing.flora and dressing.flora ~= "none" then
		local rng = Random.new(1337)
		local castParams = RaycastParams.new()
		castParams.FilterType = Enum.RaycastFilterType.Include
		castParams.FilterDescendantsInstances = { terrain }

		local avoid = {}
		for _, teamName in { "Red", "Blue" } do
			local base = map:FindFirstChild(teamName .. "Base")
			if base then
				local anchor = base:IsA("BasePart") and base or base:FindFirstChildWhichIsA("BasePart", true)
				if anchor then
					table.insert(avoid, anchor.Position)
				end
			end
		end

		local floraFolder = Instance.new("Folder")
		floraFolder.Name = "Flora"
		floraFolder.Parent = folder

		local placed, attempts = 0, 0
		while placed < dressing.floraCount and attempts < dressing.floraCount * 16 do
			attempts += 1
			local x = rng:NextNumber(-740, 740)
			local z = rng:NextNumber(-920, 920)

			local skip = false
			for _, ap in avoid do
				local dx, dz = x - ap.X, z - ap.Z
				if dx * dx + dz * dz < 100 * 100 then
					skip = true
					break
				end
			end
			if skip then
				continue
			end

			local result = Workspace:Raycast(Vector3.new(x, 320, z), Vector3.new(0, -520, 0), castParams)
			if result and result.Normal.Y > 0.9 and result.Position.Y > waterLevel + 1 then
				local scale = rng:NextNumber(0.85, 1.5)
				local tree = buildFlora(dressing.flora, scale)
				tree:PivotTo(CFrame.new(result.Position - Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				tree.Parent = floraFolder
				placed += 1
			end
		end
	end

	-- 3) Himmelskoerper (Mond / Sonne) tief ueber dem Horizont
	local sky = dressing.sky
	if sky and sky.kind ~= "none" then
		local body = Instance.new("Part")
		body.Name = "SkyBody"
		body.Shape = Enum.PartType.Ball
		body.Size = Vector3.new(sky.size, sky.size, sky.size)
		body.Position = sky.position
		body.Color = sky.color
		body.Material = Enum.Material.Neon
		body.Anchored = true
		body.CanCollide = false
		body.CanQuery = false
		body.CastShadow = false
		body.Locked = true
		body.Parent = folder
	end

	-- 4) Ferne Basis-Silhouetten (Tiefe im Dunst)
	local silhouettes = {
		{ pos = Vector3.new(-1350, 96, -1150), rot = 0.5, size = Vector3.new(74, 46, 52) },
		{ pos = Vector3.new(1450, 104, 1250), rot = -0.7, size = Vector3.new(64, 56, 46) },
		{ pos = Vector3.new(1250, 88, -1450), rot = 2.1, size = Vector3.new(58, 40, 58) },
	}
	for i, spot in silhouettes do
		local sil = Instance.new("Part")
		sil.Name = "Horizon" .. i
		sil.Size = spot.size
		sil.CFrame = CFrame.new(spot.pos) * CFrame.Angles(0, spot.rot, 0)
		sil.Color = rgb(46, 42, 38)
		sil.Material = Enum.Material.Slate
		sil.Anchored = true
		sil.CanCollide = false
		sil.CanQuery = false
		sil.CastShadow = false
		sil.Parent = folder
	end

	-- 5) Warmes/kaltes Gluehen an jeder Basis
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
				light.Color = dressing.baseGlow
				light.Brightness = 2.2
				light.Range = 42
				light.Parent = glow
				glow.Parent = folder
			end
		end
	end

	-- 6) Schneefall (nur wenn das Theme es will) -- ein einzelner Emitter ueber
	-- der ganzen Karte ist deutlich guenstiger als viele lokale Systeme.
	if dressing.snowfall then
		local volume = Instance.new("Part")
		volume.Name = "SnowVolume"
		volume.Size = Vector3.new(1450, 1, 950)
		volume.CFrame = CFrame.new(0, 150, 0)
		volume.Transparency = 1
		volume.Anchored = true
		volume.CanCollide = false
		volume.CanQuery = false
		volume.CanTouch = false
		volume.CastShadow = false
		volume.Parent = folder

		local snow = Instance.new("ParticleEmitter")
		snow.Name = "Snowfall"
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
		snow.Parent = volume
	end

	return reskinned
end

return Dressing
