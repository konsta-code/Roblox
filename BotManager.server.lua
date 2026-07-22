-- BotManager.server.lua
-- Studio-only CTF opponents for solo playtests. Bots use real Humanoids,
-- capture/return flags, fight both players and other bots, and respawn.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")

local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local LoadoutConstants = require(ReplicatedStorage.Modules.LoadoutConstants)
local MatchSignals = require(ReplicatedStorage.Modules.MatchSignals)
local CombatService = require(script.Parent.CombatService)

local ENABLED = RunService:IsStudio()
local BOTS_PER_TEAM = 3
local THINK_INTERVAL = 0.18
local RESPAWN_DELAY = 4
local BOT_GRAVITY = 92

if not ENABLED then
	return
end

local BOT_NAMES = {
	Red = { "RED RAVEN", "RED ANVIL", "RED VIPER" },
	Blue = { "BLUE FROST", "BLUE COMET", "BLUE WARDEN" },
}
local BOT_CLASSES = {
	Red = { "Raider", "Juggernaut", "Soldier" },
	Blue = { "Pathfinder", "Doombringer", "Technician" },
}

local botFolder = Instance.new("Folder")
botFolder.Name = "CTFBots"
botFolder.Parent = workspace

type BotState = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	team: Team,
	loadout: string,
	index: number,
	nextShot: number,
	nextMove: number,
	lastPosition: Vector3,
	lastProgressAt: number,
}

local botStates: { [Model]: BotState } = {}

local function makePart(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, collide: boolean): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = collide
	part.CanTouch = true
	part.Massless = name ~= "HumanoidRootPart"
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = part0
	joint.Part1 = part1
	joint.C0 = c0
	joint.C1 = c1
	joint.Parent = part0
end

local function addBotHud(model: Model, head: BasePart, humanoid: Humanoid, team: Team, loadout: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BotStatus"
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(150, 38)
	billboard.StudsOffset = Vector3.new(0, 2.25, 0)
	billboard.Parent = model

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 22)
	label.Font = Enum.Font.GothamBold
	label.Text = model.Name .. "  //  " .. string.upper(loadout)
	label.TextColor3 = team.TeamColor.Color:Lerp(Color3.new(1, 1, 1), 0.35)
	label.TextStrokeTransparency = 0.35
	label.TextScaled = true
	label.Parent = billboard

	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.fromRGB(17, 23, 31)
	bar.BorderSizePixel = 0
	bar.Position = UDim2.fromOffset(12, 25)
	bar.Size = UDim2.new(1, -24, 0, 7)
	bar.Parent = billboard

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = team.TeamColor.Color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bar
	humanoid.HealthChanged:Connect(function(health)
		fill.Size = UDim2.fromScale(math.clamp(health / humanoid.MaxHealth, 0, 1), 1)
	end)
end

local function getSpawnCFrame(team: Team): CFrame?
	local candidates = {}
	for _, spawn in CollectionService:GetTagged("PlayerSpawn") do
		if spawn:IsA("BasePart") and spawn:GetAttribute("Team") == team.Name then
			table.insert(candidates, spawn)
		end
	end
	if #candidates == 0 then return nil end
	local chosen = candidates[math.random(1, #candidates)]
	return chosen.CFrame + Vector3.new(math.random(-4, 4), 4, math.random(-4, 4))
end

local function createBotRig(team: Team, botName: string, loadout: string): (Model, Humanoid, BasePart)
	local model = Instance.new("Model")
	model.Name = botName
	model:SetAttribute("IsCTFBot", true)
	model:SetAttribute("BotTeam", team.Name)
	model:SetAttribute("Loadout", loadout)

	local teamColor = team.TeamColor.Color
	local dark = teamColor:Lerp(Color3.fromRGB(14, 19, 28), 0.62)
	local root = makePart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), dark, false)
	root.Transparency = 1
	root.Massless = false
	local torso = makePart(model, "Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), dark, true)
	local head = makePart(model, "Head", Vector3.new(2, 1, 1), CFrame.new(0, 4.5, 0), teamColor:Lerp(Color3.new(1, 1, 1), 0.18), false)
	local leftArm = makePart(model, "Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), teamColor, false)
	local rightArm = makePart(model, "Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0), teamColor, false)
	local leftLeg = makePart(model, "Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), dark, false)
	local rightLeg = makePart(model, "Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), dark, false)

	motor("RootJoint", root, torso, CFrame.new(), CFrame.new())
	motor("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
	motor("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
	motor("Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
	motor("Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))

	local chest = makePart(model, "ArmorChest", Vector3.new(2.35, 1.5, 1.25), torso.CFrame * CFrame.new(0, 0.12, 0), teamColor, false)
	chest.Material = Enum.Material.Metal
	local chestWeld = Instance.new("WeldConstraint")
	chestWeld.Part0 = torso
	chestWeld.Part1 = chest
	chestWeld.Parent = chest

	local weapon = makePart(model, "BotWeapon", Vector3.new(0.55, 0.55, 2.7), rightArm.CFrame * CFrame.new(0, -0.45, -1), dark, false)
	weapon.Material = Enum.Material.Metal
	local weaponWeld = Instance.new("WeldConstraint")
	weaponWeld.Part0 = rightArm
	weaponWeld.Part1 = weapon
	weaponWeld.Parent = weapon

	local humanoid = Instance.new("Humanoid")
	local definition = LoadoutConstants.LOADOUTS[loadout]
	humanoid.MaxHealth = definition.maxHealth
	humanoid.Health = definition.maxHealth
	humanoid.WalkSpeed = 29 * definition.walkSpeedScale
	humanoid.JumpPower = 58
	humanoid.UseJumpPower = true
	humanoid.AutoRotate = true
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	local gravityAttachment = Instance.new("Attachment")
	gravityAttachment.Name = "BotGravityAttachment"
	gravityAttachment.Parent = root
	local gravity = Instance.new("VectorForce")
	gravity.Name = "BotGravity"
	gravity.Attachment0 = gravityAttachment
	gravity.RelativeTo = Enum.ActuatorRelativeTo.World
	gravity.ApplyAtCenterOfMass = true
	gravity.Parent = root

	model.PrimaryPart = root
	model.Parent = botFolder
	gravity.Force = Vector3.new(0, -root.AssemblyMass * BOT_GRAVITY, 0)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant:SetNetworkOwner(nil)
		end
	end
	addBotHud(model, head, humanoid, team, loadout)
	CollectionService:AddTag(model, "CTFBot")
	return model, humanoid, root
end

local function getLivingRoot(model: Model?): BasePart?
	if not model or not model.Parent then return nil end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return nil end
	return root
end

local function getNearestEnemy(state: BotState): (Model?, BasePart?)
	local bestModel: Model? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		if player.Team and player.Team ~= state.team then
			local targetRoot = getLivingRoot(player.Character)
			if targetRoot then
				local distance = (targetRoot.Position - state.root.Position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestModel = player.Character
					bestRoot = targetRoot
				end
			end
		end
	end
	for model, otherState in botStates do
		if otherState.team ~= state.team then
			local targetRoot = getLivingRoot(model)
			if targetRoot then
				local distance = (targetRoot.Position - state.root.Position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestModel = model
					bestRoot = targetRoot
				end
			end
		end
	end
	return bestModel, bestRoot
end

local function getFlag(teamName: string): BasePart?
	for _, flag in CollectionService:GetTagged("CTFFlag") do
		if flag:IsA("BasePart") and flag:GetAttribute("Team") == teamName then
			return flag
		end
	end
	return nil
end

local function getStand(teamName: string): BasePart?
	for _, stand in CollectionService:GetTagged("FlagStand") do
		if stand:IsA("BasePart") and stand:GetAttribute("Team") == teamName then
			return stand
		end
	end
	return nil
end

local function getObjective(state: BotState, enemyRoot: BasePart?): Vector3
	local enemyTeamName = if state.team.Name == "Red" then "Blue" else "Red"
	local enemyFlag = getFlag(enemyTeamName)
	local ownFlag = getFlag(state.team.Name)
	if enemyFlag and enemyFlag:GetAttribute("CarrierName") == state.model.Name then
		local stand = getStand(state.team.Name)
		if stand then return stand.Position end
	end
	if ownFlag and ownFlag:GetAttribute("FlagState") ~= "AtBase" then
		return ownFlag.Position
	end
	if enemyFlag then
		local stateName = enemyFlag:GetAttribute("FlagState")
		if stateName == "AtBase" or stateName == "Dropped" then
			return enemyFlag.Position
		end
	end
	if enemyRoot then return enemyRoot.Position end
	local enemyStand = getStand(enemyTeamName)
	return enemyStand and enemyStand.Position or state.root.Position
end

local function showTracer(origin: Vector3, target: Vector3, color: Color3)
	local distance = (target - origin).Magnitude
	if distance < 0.1 then return end
	local tracer = Instance.new("Part")
	tracer.Name = "BotTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = color
	tracer.Size = Vector3.new(0.08, 0.08, distance)
	tracer.CFrame = CFrame.lookAt((origin + target) * 0.5, target)
	tracer.Parent = workspace
	Debris:AddItem(tracer, 0.06)
end

local function tryFire(state: BotState, targetModel: Model?, targetRoot: BasePart?)
	if not targetModel or not targetRoot or os.clock() < state.nextShot then return end
	local profile = ClassKitConstants.Get(state.loadout).automatic
	local origin = state.root.Position + Vector3.new(0, 1.2, 0)
	local offset = targetRoot.Position + Vector3.new(0, 0.8, 0) - origin
	local distance = offset.Magnitude
	local maxRange = math.min(profile.maxRange, 235)
	if distance > maxRange or distance < 1 then return end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { state.model }
	local result = workspace:Raycast(origin, offset, rayParams)
	if result and not result.Instance:IsDescendantOf(targetModel) then return end

	state.nextShot = os.clock() + math.max(0.22, profile.minFireInterval * 1.7) + math.random() * 0.08
	local hitChance = math.clamp(0.83 - distance / 430, 0.38, 0.78)
	local hit = math.random() <= hitChance
	local endpoint = targetRoot.Position + Vector3.new(0, 0.8, 0)
	if not hit then
		endpoint += Vector3.new(math.random(-9, 9), math.random(-5, 7), math.random(-9, 9))
	end
	showTracer(origin, endpoint, profile.tracerColor)
	if hit then
		local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
		if humanoid then
			CombatService.DamageFromTeam(state.team, state.model.Name, humanoid, profile.damagePerHit * 0.9, profile.name)
		end
	end
end

local spawnBot
spawnBot = function(team: Team, index: number)
	local spawnCFrame = getSpawnCFrame(team)
	if not spawnCFrame then
		task.delay(1, function() spawnBot(team, index) end)
		return
	end
	local loadout = BOT_CLASSES[team.Name][index]
	local botName = BOT_NAMES[team.Name][index]
	local model, humanoid, root = createBotRig(team, botName, loadout)
	model:PivotTo(spawnCFrame)

	local forceField = Instance.new("ForceField")
	forceField.Name = "BotSpawnProtection"
	forceField.Visible = true
	forceField.Parent = model
	Debris:AddItem(forceField, 2.25)

	local state: BotState = {
		model = model,
		humanoid = humanoid,
		root = root,
		team = team,
		loadout = loadout,
		index = index,
		nextShot = os.clock() + 1.5,
		nextMove = 0,
		lastPosition = root.Position,
		lastProgressAt = os.clock(),
	}
	botStates[model] = state
	humanoid.Died:Connect(function()
		botStates[model] = nil
		local attackerId = model:GetAttribute("LastAttackerUserId")
		local attackedAt = model:GetAttribute("LastAttackedAt")
		if typeof(attackerId) == "number" and typeof(attackedAt) == "number"
			and workspace:GetServerTimeNow() - attackedAt <= 10 then
			local attacker = Players:GetPlayerByUserId(attackerId)
			if attacker then CombatService.AddBotElimination(attacker, model.Name) end
		end
		Debris:AddItem(model, RESPAWN_DELAY - 0.5)
		task.delay(RESPAWN_DELAY, function()
			if botFolder.Parent then spawnBot(team, index) end
		end)
	end)
end

task.spawn(function()
	while botFolder.Parent do
		local phase = MatchSignals.GetPhase()
		local live = phase == "InProgress" or phase == "Overtime"
		for model, state in botStates do
			if model.Parent and state.humanoid.Health > 0 then
				local targetModel, targetRoot = getNearestEnemy(state)
				if live then
					local objective = getObjective(state, targetRoot)
					if os.clock() >= state.nextMove then
						state.nextMove = os.clock() + 0.55
						state.humanoid:MoveTo(objective)
					end
					tryFire(state, targetModel, targetRoot)
				else
					state.humanoid:MoveTo(state.root.Position)
				end

				if (state.root.Position - state.lastPosition).Magnitude >= 3 then
					state.lastPosition = state.root.Position
					state.lastProgressAt = os.clock()
				elseif live and os.clock() - state.lastProgressAt > 2.2 then
					state.humanoid.Jump = true
					state.root.AssemblyLinearVelocity += state.root.CFrame.LookVector * 18 + Vector3.yAxis * 24
					state.lastProgressAt = os.clock()
				end
			end
		end
		task.wait(THINK_INTERVAL)
	end
end)

task.spawn(function()
	for _, teamName in { "Red", "Blue" } do
		local team = Teams:WaitForChild(teamName, 10)
		if team and team:IsA("Team") then
			for index = 1, BOTS_PER_TEAM do
				spawnBot(team, index)
			end
		end
	end
	print(string.format("[BotManager] %d CTF bots enabled for Studio playtest", BOTS_PER_TEAM * 2))
end)
