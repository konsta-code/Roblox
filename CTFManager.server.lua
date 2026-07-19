-- CTFManager.server.lua
-- Ablageort: ServerScriptService
--
-- Flag-System, datengetrieben über CollectionService statt hartcodierter
-- Pfade: Flaggen-Stands im Level brauchen nur den Tag "FlagStand" (Plugin
-- "Tag Editor" in Studio) + ein String-Attribut "Team", das zum Namen
-- eines Team-Objekts in der Teams-Service passt (z.B. "Red"/"Blue").
-- Level-Änderungen brauchen dann keinen Code-Change.
--
-- Manuelle Setup-Schritte:
--  1. Zwei Team-Objekte in der Teams-Service anlegen (z.B. "Red", "Blue")
--  2. RemoteEvent "CTFScoreUpdate" in ReplicatedStorage anlegen (Server -> Client)
--  3. Je einen Flaggen-Stand-Part pro Team im Level mit Tag "FlagStand" +
--     Attribut Team="Red"/"Blue" versehen
--  4. RemoteEvent "FlagCarryStatus" in ReplicatedStorage anlegen (Server -> Client,
--     informiert nur den jeweiligen Träger fürs HUD)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Modules.FlagConstants)
local CTFSignals = require(ReplicatedStorage.Modules.CTFSignals)

local scoreEvent = ReplicatedStorage:WaitForChild("CTFScoreUpdate")
local carryStatusEvent = ReplicatedStorage:WaitForChild("FlagCarryStatus")

type FlagState = "AtBase" | "Carried" | "Dropped"

type Flag = {
	team: Team,
	homeCFrame: CFrame,
	part: BasePart,
	state: FlagState,
	carrier: Player?,
	returnTimer: number?,
}

local flags: { Flag } = {}
local scores: { [Team]: number } = {}

-- === Visuals & Physik-State ===

local function createFlagVisual(homeCFrame: CFrame, team: Team): BasePart
	local part = Instance.new("Part")
	part.Name = team.Name .. "Flag"
	part.Size = Vector3.new(2, 3, 2)
	part.CFrame = homeCFrame
	part.Anchored = true
	part.CanCollide = false
	part.Color = team.TeamColor.Color
	part.Material = Enum.Material.Neon
	part.Parent = workspace
	return part
end

local function detachFlagPhysics(flag: Flag)
	local weld = flag.part:FindFirstChild("FlagWeld")
	if weld then
		weld:Destroy()
	end
	flag.part.Anchored = true
end

local function returnFlagToBase(flag: Flag)
	local previousCarrier = flag.carrier

	detachFlagPhysics(flag)
	flag.state = "AtBase"
	flag.carrier = nil
	flag.returnTimer = nil
	flag.part.CFrame = flag.homeCFrame
	flag.part.Parent = workspace

	if previousCarrier then
		carryStatusEvent:FireClient(previousCarrier, false, flag.team.Name)
	end
end

local function dropFlag(flag: Flag, atPosition: Vector3)
	local previousCarrier = flag.carrier

	detachFlagPhysics(flag)
	flag.state = "Dropped"
	flag.carrier = nil
	flag.returnTimer = Constants.RETURN_TIMER
	flag.part.CFrame = CFrame.new(atPosition)
	flag.part.Parent = workspace

	if previousCarrier then
		carryStatusEvent:FireClient(previousCarrier, false, flag.team.Name)
	end
end

local function attachFlagToCarrier(flag: Flag, player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	flag.state = "Carried"
	flag.carrier = player
	flag.returnTimer = nil

	flag.part.Anchored = false
	flag.part.CanCollide = false
	flag.part.Parent = character

	local weld = Instance.new("Weld")
	weld.Name = "FlagWeld"
	weld.Part0 = root
	weld.Part1 = flag.part
	weld.C0 = CFrame.new(0, 3, 0) -- über dem Kopf, gut sichtbar für beide Teams
	weld.Parent = flag.part

	carryStatusEvent:FireClient(player, true, flag.team.Name)
end

-- === Game-Logik ===

local function findFlagByTeam(team: Team): Flag?
	for _, flag in flags do
		if flag.team == team then
			return flag
		end
	end
	return nil
end

local function onCapture(flag: Flag, scoringPlayer: Player)
	local scoringTeam = scoringPlayer.Team :: Team?
	if not scoringTeam then return end

	scores[scoringTeam] = (scores[scoringTeam] or 0) + 1
	scoreEvent:FireAllClients(scoringTeam.Name, scores[scoringTeam], scoringPlayer.Name)
	CTFSignals.FireCaptureOccurred(scoringTeam, scores[scoringTeam])

	returnFlagToBase(flag)
end

local function checkCaptureCondition(carrierFlag: Flag, player: Player)
	local team = player.Team :: Team?
	if not team then return end

	local ownFlag = findFlagByTeam(team)
	if not ownFlag or ownFlag.state ~= "AtBase" then return end -- eigene Flagge muss daheim sein

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local distance = (root.Position - ownFlag.homeCFrame.Position).Magnitude
	if distance <= Constants.CAPTURE_RADIUS then
		onCapture(carrierFlag, player)
	end
end

local function tryPickup(flag: Flag, player: Player)
	local team = player.Team :: Team?
	if not team then return end

	if team == flag.team then
		-- Eigenes Team berührt eigene (gedroppte) Flagge -> sofortige Rückkehr
		if flag.state == "Dropped" then
			returnFlagToBase(flag)
		end
		return
	end

	if flag.state == "AtBase" or flag.state == "Dropped" then
		attachFlagToCarrier(flag, player)
	end
end

local function setupFlagTouch(flag: Flag)
	flag.part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			tryPickup(flag, player)
		end
	end)
end

local function bindDeathDrop(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			for _, flag in flags do
				if flag.state == "Carried" and flag.carrier == player then
					local root = character:FindFirstChild("HumanoidRootPart")
					dropFlag(flag, root and root.Position or flag.homeCFrame.Position)
				end
			end
		end)
	end)
end

RunService.Heartbeat:Connect(function(dt)
	for _, flag in flags do
		if flag.state == "Carried" and flag.carrier then
			checkCaptureCondition(flag, flag.carrier)
		elseif flag.state == "Dropped" and flag.returnTimer then
			flag.returnTimer -= dt
			if flag.returnTimer <= 0 then
				returnFlagToBase(flag)
			end
		end
	end
end)

CTFSignals.ResetScoresRequested:Connect(function()
	for team in pairs(scores) do
		scores[team] = 0
		scoreEvent:FireAllClients(team.Name, 0)
	end
end)

-- === Setup ===

for _, team in Teams:GetTeams() do
	scores[team] = 0
end

for _, standPart: Instance in CollectionService:GetTagged(Constants.FLAG_STAND_TAG) do
	if not standPart:IsA("BasePart") then continue end

	local teamName = standPart:GetAttribute("Team")
	local team = teamName and Teams:FindFirstChild(teamName)
	if not team then
		warn("FlagStand ohne gültiges Team-Attribut: " .. standPart:GetFullName())
		continue
	end

	local homeCFrame = standPart.CFrame
	local flagPart = createFlagVisual(homeCFrame, team)

	local flag: Flag = {
		team = team,
		homeCFrame = homeCFrame,
		part = flagPart,
		state = "AtBase",
		carrier = nil,
		returnTimer = nil,
	}
	table.insert(flags, flag)
	setupFlagTouch(flag)
end

Players.PlayerAdded:Connect(bindDeathDrop)
for _, player in Players:GetPlayers() do
	bindDeathDrop(player)
end
