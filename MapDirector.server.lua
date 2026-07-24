-- MapDirector.server.lua
-- Ablageort: ServerScriptService
--
-- Orchestriert den Map-Aufbau UND den Live-Wechsel:
--   * baut beim Serverstart die Standard-Map (immer eine Welt da -> normales
--     Spawnen, kein Eingriff in Charakter-Laden/Loadout/Jetpack)
--   * MatchManager triggert den Wechsel am Rundenende (nach dem Voting) ueber
--     _G.RequestMapSwitch: Spieler kurz sicher hochgehalten -> Terrain neu gebaut
--     -> Spieler an die neuen Spawns gesetzt
--
-- WICHTIG: Dieses Script fasst den Spawn-/Loadout-Fluss NICHT an. Es bewegt nur
-- Spieler (Teleport/Anchor). So kann ein Map-Wechsel Modell/Jetpack nie brechen.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- Weiche: erlaubt Rueckfall auf die alte NaturalTerrain-Map.
if Workspace:GetAttribute("UseTribesWorld") == false then
	return
end

local MapPool = require(ReplicatedStorage.Modules.MapPoolConstants)
local WorldGen = require(ServerScriptService:WaitForChild("WorldGen"))
local WorldEnvironment = require(ServerScriptService:WaitForChild("WorldEnvironment"))
local Dressing = require(ServerScriptService:WaitForChild("Dressing"))

local DEFAULT_MAP = "grass_ridgeline"
local SPAWN_TAG = "PlayerSpawn"
local BASE_OLD_X = { Red = -570, Blue = 570 } -- Baupositionen aus MapBuilder

-- Pristine (MapBuilder-)CFrames aller Basis-Teile, EINMALIG gesichert. So setzt
-- das Re-Seating bei jedem Map-Wechsel immer aus der Ursprungslage neu, statt
-- Transforme aufeinander zu stapeln.
local originalCFrames: { [BasePart]: CFrame } = {}
local baseOriginCaptured = false

-- ============================================================
-- SPAWN-HELFER (liest die getaggten Spawns, wie SpawnManager -- ohne dessen
-- Spawn-Fluss anzufassen)
-- ============================================================
local function teleportToSpawn(player: Player)
	local team = player.Team
	local character = player.Character
	if not team or not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local spawns = {}
	for _, s in CollectionService:GetTagged(SPAWN_TAG) do
		if s:IsA("BasePart") and s:GetAttribute("Team") == team.Name then
			table.insert(spawns, s)
		end
	end
	if #spawns == 0 then
		return
	end
	local chosen = spawns[math.random(1, #spawns)]
	character:PivotTo(chosen.CFrame + Vector3.new(0, 4, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

-- ============================================================
-- MAP BAUEN (Terrain + Basen-Seating + Optik)
-- ============================================================
local function buildMap(mapDef): boolean
	Workspace:SetAttribute("TribesWorldReady", false)
	Workspace:SetAttribute("CurrentMapId", mapDef.id)
	Workspace:SetAttribute("CurrentMapName", mapDef.name)
	Workspace:SetAttribute("CurrentMapTheme", mapDef.theme)

	local t0 = os.clock()
	local ok, result = pcall(WorldGen.build, mapDef)
	if not ok then
		warn("[MapDirector] WorldGen.build FEHLER bei '" .. mapDef.id .. "': " .. tostring(result))
		Workspace:SetAttribute("TribesWorldReady", true)
		return false
	end
	if not result then
		warn("[MapDirector] kein Terrain vorhanden - Build abgebrochen")
		Workspace:SetAttribute("TribesWorldReady", true)
		return false
	end
	print(("[MapDirector] map '%s' (%s) -- terrain built in %.1fs"):format(mapDef.id, mapDef.theme, os.clock() - t0))

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	local heightFn = result.heightFn
	local map = Workspace:WaitForChild("TribesMapLive", 20)

	if map then
		-- obsolete MapBuilder-Ground ausblenden (idempotent)
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

		-- pristine Basis-CFrames einmalig sichern
		if not baseOriginCaptured then
			for _, teamName in { "Red", "Blue" } do
				local base = map:FindFirstChild(teamName .. "Base")
				if base then
					for _, part in base:GetDescendants() do
						if part:IsA("BasePart") then
							originalCFrames[part] = part.CFrame
						end
					end
				end
			end
			baseOriginCaptured = true
		end

		-- Basen auf die Plateaus setzen: Raycast auf die ECHTE Oberflaeche, immer
		-- aus der pristine Lage -> idempotent ueber beliebig viele Map-Wechsel.
		local seatParams = RaycastParams.new()
		seatParams.FilterType = Enum.RaycastFilterType.Include
		seatParams.FilterDescendantsInstances = { terrain }
		local function surfaceY(x: number, z: number): number
			local hit = Workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -700, 0), seatParams)
			return hit and hit.Position.Y or heightFn(x, z)
		end

		for _, teamName in { "Red", "Blue" } do
			local base = map:FindFirstChild(teamName .. "Base")
			local target = mapDef.layout.baseTargets[teamName]
			if base and target then
				local cx, cz = target.X, target.Z
				local seat = surfaceY(cx, cz)
				for _, o in { { 60, 0 }, { -60, 0 }, { 0, 40 }, { 0, -40 } } do
					seat = math.max(seat, surfaceY(cx + o[1], cz + o[2]))
				end
				local newAnchorY = seat + 4.5
				local oldAnchor = CFrame.new(BASE_OLD_X[teamName], 20, 0)
				local newAnchor = CFrame.new(cx, newAnchorY, cz) * CFrame.Angles(0, math.rad(-90), 0)
				local delta = newAnchor * oldAnchor:Inverse()
				for _, part in base:GetDescendants() do
					if part:IsA("BasePart") and originalCFrames[part] then
						part.CFrame = delta * originalCFrames[part]
					end
				end
				print(("[MapDirector] %s base seated at Y=%.1f (surface %.1f)"):format(teamName, newAnchorY, seat))
			end
		end
	end

	WorldEnvironment.apply(result.theme.env)
	if map then
		Dressing.apply(result.theme.dressing, terrain, map, { waterLevel = mapDef.layout.waterLevel })
	end

	Workspace:SetAttribute("TribesWorldReady", true)
	print(("[MapDirector] map ready: %s (%s)"):format(mapDef.name, mapDef.theme))
	return true
end

-- ============================================================
-- LIVE-WECHSEL
-- ============================================================
local switching = false
local function switchMap(mapId: string)
	if switching then
		return
	end
	local def = MapPool.get(mapId)
	if not def then
		return
	end
	switching = true
	Workspace:SetAttribute("SelectedMapId", mapId)

	-- Spieler sicher hoch + festhalten, damit sie waehrend des Rebuilds (Terrain
	-- wird kurz geleert) nicht ins Leere fallen.
	local held = {}
	local i = 0
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			i += 1
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(CFrame.new(i * 8, 500, 0))
			root.Anchored = true
			table.insert(held, root)
		end
	end

	buildMap(def)

	for _, root in held do
		if root.Parent then
			root.Anchored = false
		end
	end
	task.wait(0.15)
	for _, p in Players:GetPlayers() do
		teleportToSpawn(p)
	end
	switching = false
end

-- ============================================================
-- START + REMOTE
-- ============================================================
local pick = Workspace:GetAttribute("SelectedMapId") or Workspace:GetAttribute("ForceMapId")
local startDef = (typeof(pick) == "string" and MapPool.get(pick)) or MapPool.get(DEFAULT_MAP)
buildMap(startDef or MapPool.get(DEFAULT_MAP))

-- Der Map-Wechsel wird jetzt vom MatchManager am Rundenende (nach dem Voting)
-- ausgeloest, nicht mehr frei per Menue. switchMap wird dafuer freigegeben.
_G.RequestMapSwitch = switchMap
