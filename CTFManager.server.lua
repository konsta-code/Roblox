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
local MatchSignals = require(ReplicatedStorage.Modules.MatchSignals)
local CombatService = require(script.Parent.CombatService)

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
	stand: BasePart,
}

local flags: { Flag } = {}
local scores: { [Team]: number } = {}
local flagEventSerial = 0

local function isLiveCapturePhase(): boolean
	local currentPhase = MatchSignals.GetPhase()
	return currentPhase == "InProgress" or currentPhase == "Overtime"
end

local function publishFlagEvent(kind: string, flag: Flag, actor: Player?)
	ReplicatedStorage:SetAttribute("FlagEventKind", kind)
	ReplicatedStorage:SetAttribute("FlagEventTeam", flag.team.Name)
	ReplicatedStorage:SetAttribute("FlagEventPlayer", actor and actor.Name or "")
	flagEventSerial += 1
	ReplicatedStorage:SetAttribute("FlagEventSerial", flagEventSerial)
end

local function replicateFlagState(flag: Flag)
	flag.part:SetAttribute("FlagState", flag.state)
	flag.part:SetAttribute("CarrierName", flag.carrier and flag.carrier.Name or "")
	flag.part:SetAttribute("ReturnTime", flag.returnTimer and math.max(0, math.ceil(flag.returnTimer)) or 0)
end

-- === Visuals & Physik-State ===

local function createFlagVisual(homeCFrame: CFrame, team: Team): BasePart
	local part = Instance.new("Part")
	part.Name = team.Name .. "Flag"
	part.Size = Vector3.new(2.2, 2.2, 2.2)
	part.CFrame = homeCFrame
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = true
	part.Shape = Enum.PartType.Ball
	part.Color = team.TeamColor.Color
	part.Material = Enum.Material.Neon
	-- Tag für Client-Systeme (FlagMarkers): Flaggen auffindbar machen, ohne
	-- Namens-Konventionen raten zu müssen. Überlebt Reparenting beim Tragen.
	CollectionService:AddTag(part, "CTFFlag")
	part.Parent = workspace

	local function visualPart(name: string, size: Vector3, offset: CFrame, material: Enum.Material): BasePart
		local visual = Instance.new("Part")
		visual.Name = name
		visual.Size = size
		visual.CFrame = homeCFrame * offset
		visual.Anchored = false
		visual.CanCollide = false
		visual.CanTouch = false
		visual.CanQuery = false
		visual.Massless = true
		visual.Color = team.TeamColor.Color
		visual.Material = material
		visual.Parent = part
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = visual
		weld.Parent = visual
		return visual
	end

	visualPart("FlagPole", Vector3.new(0.34, 7.5, 0.34), CFrame.new(0, 3.6, 0), Enum.Material.Metal)
	local banner = visualPart("FlagBanner", Vector3.new(4.8, 2.7, 0.32), CFrame.new(2.35, 5.55, 0), Enum.Material.Fabric)
	local stripe = visualPart("FlagStripe", Vector3.new(4.9, 0.32, 0.37), CFrame.new(2.35, 5.55, 0), Enum.Material.Neon)
	stripe.Color = team.TeamColor.Color:Lerp(Color3.new(1, 1, 1), 0.4)

	local glow = Instance.new("PointLight")
	glow.Color = team.TeamColor.Color
	glow.Brightness = 1.8
	glow.Range = 18
	glow.Shadows = false
	glow.Parent = part

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "FlagEnergy"
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Rate = 9
	particles.Lifetime = NumberRange.new(0.45, 0.8)
	particles.Speed = NumberRange.new(0.4, 1.2)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Color = ColorSequence.new(team.TeamColor.Color)
	particles.LightEmission = 0.85
	particles.Size = NumberSequence.new(0.16, 0)
	particles.Parent = part

	part:SetAttribute("FlagState", "AtBase")
	part:SetAttribute("CarrierName", "")
	part:SetAttribute("ReturnTime", 0)
	return part
end

local function detachFlagPhysics(flag: Flag)
	local weld = flag.part:FindFirstChild("FlagWeld")
	if weld then
		weld:Destroy()
	end
	flag.part.Anchored = true
end

local function returnFlagToBase(flag: Flag, announceReturn: boolean?, actor: Player?)
	local previousCarrier = flag.carrier

	detachFlagPhysics(flag)
	flag.state = "AtBase"
	flag.carrier = nil
	flag.returnTimer = nil
	flag.part.CFrame = flag.homeCFrame
	flag.part.Parent = workspace
	replicateFlagState(flag)

	if previousCarrier and previousCarrier.Parent == Players then
		carryStatusEvent:FireClient(previousCarrier, false, flag.team.Name)
	end
	if announceReturn then
		if actor then
			CombatService.AddObjective(actor, 50, "FLAG RETURN")
		end
		publishFlagEvent("Returned", flag, actor)
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
	replicateFlagState(flag)

	if previousCarrier and previousCarrier.Parent == Players then
		carryStatusEvent:FireClient(previousCarrier, false, flag.team.Name)
	end
	publishFlagEvent("Dropped", flag, previousCarrier)
end

local function attachFlagToCarrier(flag: Flag, player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local wasAtBase = flag.state == "AtBase"
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
	weld.C0 = CFrame.new(0, 1.5, 0) -- Banner ueber der Schulter, ohne die Sicht zu verdecken
	weld.Parent = flag.part

	carryStatusEvent:FireClient(player, true, flag.team.Name)
	replicateFlagState(flag)
	publishFlagEvent("Taken", flag, player)
	CombatService.AddObjective(player, if wasAtBase then 25 else 10, if wasAtBase then "FLAG GRAB" else "FLAG RECOVERY")
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

local function setScore(team: Team, value: number, scoringPlayerName: string?)
	scores[team] = value
	ReplicatedStorage:SetAttribute("CTFScore_" .. team.Name, value)
	scoreEvent:FireAllClients(team.Name, value, scoringPlayerName)
end

local function resetAllFlags()
	for _, flag in flags do
		returnFlagToBase(flag)
	end
end

local function onCapture(flag: Flag, scoringPlayer: Player)
	local scoringTeam = scoringPlayer.Team :: Team?
	if not scoringTeam then return end

	local newScore = (scores[scoringTeam] or 0) + 1
	setScore(scoringTeam, newScore, scoringPlayer.Name)
	CombatService.AddCapture(scoringPlayer)
	CTFSignals.FireCaptureOccurred(scoringTeam, newScore)

	returnFlagToBase(flag)
end

local function checkCaptureCondition(carrierFlag: Flag, player: Player)
	if not isLiveCapturePhase() then return end
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
	if not isLiveCapturePhase() then return end
	local team = player.Team :: Team?
	if not team then return end

	if team == flag.team then
		-- Eigenes Team berührt eigene (gedroppte) Flagge -> sofortige Rückkehr
		if flag.state == "Dropped" then
			returnFlagToBase(flag, true, player)
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
	local function bindCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			for _, flag in flags do
				if flag.state == "Carried" and flag.carrier == player then
					local root = character:FindFirstChild("HumanoidRootPart")
					dropFlag(flag, root and root.Position or flag.homeCFrame.Position)
				end
			end
		end)
	end
	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then bindCharacter(player.Character) end
end

RunService.Heartbeat:Connect(function(dt)
	for _, flag in flags do
		if flag.state == "Carried" and flag.carrier then
			checkCaptureCondition(flag, flag.carrier)
		elseif flag.state == "Dropped" and flag.returnTimer then
			flag.returnTimer -= dt
			local returnSecond = math.max(0, math.ceil(flag.returnTimer))
			if flag.part:GetAttribute("ReturnTime") ~= returnSecond then
				flag.part:SetAttribute("ReturnTime", returnSecond)
			end
			if flag.returnTimer <= 0 then
				returnFlagToBase(flag, true)
			end
		end
	end
end)

CTFSignals.ResetScoresRequested:Connect(function()
	for team in pairs(scores) do
		setScore(team, 0)
	end
	resetAllFlags()
end)

CTFSignals.FlagFumbleRequested:Connect(function(player: Player)
	for _, flag in flags do
		if flag.state == "Carried" and flag.carrier == player then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			dropFlag(flag, root and root.Position or flag.homeCFrame.Position)
		end
	end
end)

MatchSignals.PhaseChanged:Connect(function(newPhase: MatchSignals.MatchPhase)
	if newPhase ~= "InProgress" and newPhase ~= "Overtime" then resetAllFlags() end
end)

-- === Setup ===

for _, team in Teams:GetTeams() do
	setScore(team, 0)
end

-- Flaggen-Stände registrieren - robust gegen Timing UND Rebuilds:
-- GetTagged erfasst bereits vorhandene Stände, GetInstanceAddedSignal die, die
-- erst zur Laufzeit getaggt werden (MapBuilder baut die Map evtl. erst NACH
-- diesem Script - die Reihenfolge in ServerScriptService ist nicht garantiert).
-- GetInstanceRemovedSignal räumt Flaggen weg, deren Stand zerstört wird (z.B.
-- wenn MapBuilder eine alte Map ersetzt). Das seen-Set verhindert Doppel.
local seenStands: { [Instance]: boolean } = {}

local function registerStand(standPart: Instance)
	if seenStands[standPart] or not standPart:IsA("BasePart") then return end

	local teamName = standPart:GetAttribute("Team")
	local team = teamName and Teams:FindFirstChild(teamName)
	if not team then
		warn("FlagStand ohne gültiges Team-Attribut: " .. standPart:GetFullName())
		return
	end
	seenStands[standPart] = true

	local homeCFrame = standPart.CFrame
	local flagPart = createFlagVisual(homeCFrame, team)

	local flag: Flag = {
		team = team,
		homeCFrame = homeCFrame,
		part = flagPart,
		state = "AtBase",
		carrier = nil,
		returnTimer = nil,
		stand = standPart,
	}
	table.insert(flags, flag)
	setupFlagTouch(flag)
end

local function unregisterStand(standPart: Instance)
	if not seenStands[standPart] then return end
	seenStands[standPart] = nil
	for i = #flags, 1, -1 do
		local flag = flags[i]
		if flag.stand == standPart then
			if flag.carrier then
				carryStatusEvent:FireClient(flag.carrier, false, flag.team.Name)
			end
			flag.part:Destroy()
			table.remove(flags, i)
		end
	end
end

CollectionService:GetInstanceAddedSignal(Constants.FLAG_STAND_TAG):Connect(registerStand)
CollectionService:GetInstanceRemovedSignal(Constants.FLAG_STAND_TAG):Connect(unregisterStand)
for _, standPart in CollectionService:GetTagged(Constants.FLAG_STAND_TAG) do
	registerStand(standPart)
end

Players.PlayerAdded:Connect(bindDeathDrop)
for _, player in Players:GetPlayers() do
	bindDeathDrop(player)
end

Players.PlayerRemoving:Connect(function(player)
	for _, flag in flags do
		if flag.state == "Carried" and flag.carrier == player then
			returnFlagToBase(flag, true)
		end
	end
end)
