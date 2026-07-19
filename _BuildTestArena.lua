-- _BuildTestArena.lua
-- NICHT Teil des Rojo-Syncs (steht nicht in default.project.json) - dieses
-- Script ist ein Einmal-Befehl fürs Studio-Command-Bar (View > Command Bar),
-- kein Spiel-Script.
--
-- Baut eine minimale Testarena: Boden, eine Ski-Rampe in der Mitte, zwei
-- Basen (Red/Blue) mit je einem getaggten Flaggen-Stand, getaggten
-- PlayerSpawn-Parts und einer klassischen SpawnLocation. Setzt außerdem
-- TeamColor auf Teams.Red/Blue, falls noch nicht gesetzt.
--
-- Idempotent: läuft man es zweimal, räumt es die vorher selbst gebaute
-- Arena (Ordner "TestArena" in workspace) zuerst weg statt zu duplizieren.
--
-- Anwendung: kompletten Inhalt kopieren, in Studio "View > Command Bar"
-- öffnen, einfügen, Enter.

local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")

local old = workspace:FindFirstChild("TestArena")
if old then old:Destroy() end

local arena = Instance.new("Folder")
arena.Name = "TestArena"
arena.Parent = workspace

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Parent = parent
	return p
end

-- === Boden ===

part("Ground", Vector3.new(300, 4, 200), CFrame.new(0, -2, 0), Color3.fromRGB(90, 110, 90), arena)

-- === Ski-Rampe (Hügel in der Mitte, für Ski-Physik-Test) ===

part(
	"SkiRamp",
	Vector3.new(80, 4, 120),
	CFrame.new(0, 8, 0) * CFrame.Angles(math.rad(22), 0, 0),
	Color3.fromRGB(140, 160, 200),
	arena
)

-- === Basen ===

local baseSetups = {
	{ teamName = "Red", color = BrickColor.new("Bright red"), x = -130 },
	{ teamName = "Blue", color = BrickColor.new("Bright blue"), x = 130 },
}

for _, setup in baseSetups do
	local team = Teams:FindFirstChild(setup.teamName)
	if not team then
		warn("_BuildTestArena: Team \"" .. setup.teamName .. "\" existiert nicht - im Teams-Service anlegen und Script erneut laufen lassen")
		continue
	end

	team.TeamColor = setup.color
	team.AutoAssignable = true

	local baseFolder = Instance.new("Folder")
	baseFolder.Name = setup.teamName .. "Base"
	baseFolder.Parent = arena

	-- Basen-Plattform, rein visuell
	part(
		"BasePlatform",
		Vector3.new(40, 2, 40),
		CFrame.new(setup.x, 1, 0),
		setup.color.Color,
		baseFolder
	)

	-- Flaggen-Stand: Position ist die "Home"-Position, auf die CTFManager
	-- referenziert (standPart.CFrame wird 1:1 als homeCFrame übernommen)
	local flagStand = part(
		"FlagStand",
		Vector3.new(4, 1, 4),
		CFrame.new(setup.x, 2.5, 0),
		Color3.fromRGB(230, 230, 230),
		baseFolder
	)
	flagStand.Anchored = true
	flagStand.CanCollide = true
	flagStand:SetAttribute("Team", setup.teamName)
	CollectionService:AddTag(flagStand, "FlagStand")

	-- Klassische SpawnLocation, deckt Robloxens eingebautes Erst-Spawn-System ab
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = setup.teamName .. "SpawnLocation"
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.new(setup.x, 0.5, -25)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = false
	spawnLocation.TeamColor = setup.color
	spawnLocation.Transparency = 0.6
	spawnLocation.Color = setup.color.Color
	spawnLocation.Parent = baseFolder

	-- Zusätzliche getaggte Spawns fürs SpawnManager-Rundenstart-Teleport
	-- (mehrere, damit nicht alle Spieler exakt übereinander landen)
	for i = 1, 3 do
		local spawnTag = Instance.new("Part")
		spawnTag.Name = setup.teamName .. "PlayerSpawn" .. i
		spawnTag.Size = Vector3.new(4, 1, 4)
		spawnTag.CFrame = CFrame.new(setup.x + (i - 2) * 10, 1, -25)
		spawnTag.Anchored = true
		spawnTag.CanCollide = false
		spawnTag.Transparency = 1
		spawnTag:SetAttribute("Team", setup.teamName)
		spawnTag.Parent = baseFolder
		CollectionService:AddTag(spawnTag, "PlayerSpawn")
	end
end

print("_BuildTestArena: fertig - Ground, SkiRamp, RedBase, BlueBase in workspace.TestArena")
