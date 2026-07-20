-- CombatService.lua
-- Gemeinsame, serverautoritäre Schadens- und Statistikschicht. Waffen melden
-- Schaden hier, damit Friendly Fire, Kill-Zuordnung und Leaderstats nicht in
-- jeder Waffe unterschiedlich implementiert werden.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local combatFeedEvent = ReplicatedStorage:WaitForChild("CombatFeed")
local damageFeedbackEvent = ReplicatedStorage:WaitForChild("DamageFeedback")
local MatchSignals = require(ReplicatedStorage.Modules.MatchSignals)

local CombatService = {}

type HitInfo = {
	attacker: Player?,
	sourceName: string?,
	weapon: string,
	time: number,
}

type Contribution = {
	damage: number,
	time: number,
}

local HIT_CREDIT_WINDOW = 10
local MULTIKILL_WINDOW = 5
local initialized = false
local lastHits: { [Humanoid]: HitInfo } = {}
local damageContributions: { [Humanoid]: { [Player]: Contribution } } = {}
local killStreaks: { [Player]: number } = {}
local lastKillTimes: { [Player]: number } = {}
local multiKillCounts: { [Player]: number } = {}

local function awardPlayer(player: Player, award: string)
	damageFeedbackEvent:FireClient(player, 0, false, "Award", nil, award)
end

local function getOrCreateStat(player: Player, name: string): IntValue
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local existing = leaderstats:FindFirstChild(name)
	if existing and existing:IsA("IntValue") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local stat = Instance.new("IntValue")
	stat.Name = name
	stat.Parent = leaderstats
	return stat
end

local function addStat(player: Player, name: string, amount: number)
	getOrCreateStat(player, name).Value += amount
end

local ROUND_STAT_NAMES = { "Kills", "Deaths", "Captures", "Assists", "Score" }

local function ensureRoundStats(player: Player)
	for _, name in ROUND_STAT_NAMES do
		local attributeName = "Round" .. name
		if typeof(player:GetAttribute(attributeName)) ~= "number" then
			player:SetAttribute(attributeName, 0)
		end
	end
end

local function addCareerAndRound(player: Player, name: string, amount: number)
	addStat(player, name, amount)
	local attributeName = "Round" .. name
	local current = player:GetAttribute(attributeName)
	player:SetAttribute(attributeName, (if typeof(current) == "number" then current else 0) + amount)
end

local function awardScore(player: Player, amount: number, reason: string)
	if player.Parent ~= Players or amount <= 0 then
		return
	end
	addCareerAndRound(player, "Score", math.floor(amount))
	damageFeedbackEvent:FireClient(player, math.floor(amount), false, "Score", nil, reason)
end

local function bindCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		addCareerAndRound(player, "Deaths", 1)
		killStreaks[player] = 0

		local hit = lastHits[humanoid]
		lastHits[humanoid] = nil
		local contributions = damageContributions[humanoid]
		damageContributions[humanoid] = nil
		local killer: Player? = nil
		local killerName: string? = nil
		local weapon = "Umgebung"
		if hit and os.clock() - hit.time <= HIT_CREDIT_WINDOW then
			weapon = hit.weapon
			if hit.attacker and hit.attacker.Parent == Players and hit.attacker ~= player then
				killer = hit.attacker
				addCareerAndRound(killer, "Kills", 1)
				awardScore(killer, 100, "ELIMINATION")
				killerName = killer.DisplayName

				local now = os.clock()
				if now - (lastKillTimes[killer] or -math.huge) <= MULTIKILL_WINDOW then
					multiKillCounts[killer] = (multiKillCounts[killer] or 1) + 1
				else
					multiKillCounts[killer] = 1
				end
				lastKillTimes[killer] = now
				killStreaks[killer] = (killStreaks[killer] or 0) + 1

				local multiCount = multiKillCounts[killer]
				if multiCount == 2 then
					awardPlayer(killer, "DOUBLE KILL")
				elseif multiCount == 3 then
					awardPlayer(killer, "TRIPLE KILL")
				elseif multiCount >= 4 then
					awardPlayer(killer, "MULTI KILL")
				end

				local streak = killStreaks[killer]
				if streak == 5 then
					awardPlayer(killer, "KILLING SPREE")
				elseif streak == 10 then
					awardPlayer(killer, "UNSTOPPABLE")
				end
			elseif not hit.attacker then
				killerName = hit.sourceName
			end
		end

		if contributions then
			local now = os.clock()
			for contributor, contribution in contributions do
				if contributor ~= killer
					and contributor ~= player
					and contributor.Parent == Players
					and contribution.damage >= 10
					and now - contribution.time <= HIT_CREDIT_WINDOW then
					addCareerAndRound(contributor, "Assists", 1)
					awardScore(contributor, 50, "ASSIST")
				end
			end
		end

		local killDistance = 0
		if killer then
			local killerRoot = killer.Character and killer.Character:FindFirstChild("HumanoidRootPart")
			local victimRoot = character:FindFirstChild("HumanoidRootPart")
			if killerRoot and killerRoot:IsA("BasePart") and victimRoot and victimRoot:IsA("BasePart") then
				killDistance = math.floor((killerRoot.Position - victimRoot.Position).Magnitude / 3.57 + 0.5)
			end
		end
		player:SetAttribute("LastKillerName", killerName or "UMGEBUNG")
		player:SetAttribute("LastKillerUserId", killer and killer.UserId or 0)
		player:SetAttribute("LastDeathWeapon", weapon)
		player:SetAttribute("LastDeathDistance", killDistance)
		player:SetAttribute("LastDeathTime", workspace:GetServerTimeNow())

		combatFeedEvent:FireAllClients(killerName, player.DisplayName, weapon)
	end)
end

local function setupPlayer(player: Player)
	getOrCreateStat(player, "Kills")
	getOrCreateStat(player, "Deaths")
	getOrCreateStat(player, "Captures")
	getOrCreateStat(player, "Assists")
	getOrCreateStat(player, "Score")
	ensureRoundStats(player)
	killStreaks[player] = 0
	multiKillCounts[player] = 0

	player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			lastHits[humanoid] = nil
			damageContributions[humanoid] = nil
		end
	end)
	if player.Character then
		bindCharacter(player, player.Character)
	end
end

function CombatService.Init()
	if initialized then
		return
	end
	initialized = true

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		killStreaks[player] = nil
		lastKillTimes[player] = nil
		multiKillCounts[player] = nil
	end)
	MatchSignals.RoundStarted:Connect(function()
		for _, player in Players:GetPlayers() do
			for _, name in ROUND_STAT_NAMES do
				player:SetAttribute("Round" .. name, 0)
			end
			killStreaks[player] = 0
			multiKillCounts[player] = 0
			lastKillTimes[player] = nil
		end
		table.clear(lastHits)
		table.clear(damageContributions)
	end)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

local function damageInternal(
	attacker: Player?,
	attackingTeam: Team?,
	sourceName: string?,
	humanoid: Humanoid,
	amount: number,
	weapon: string,
	award: string?
): boolean
	CombatService.Init()
	if (attacker and attacker.Parent ~= Players) or humanoid.Health <= 0 then
		return false
	end
	if amount ~= amount or amount <= 0 or amount == math.huge then
		return false
	end

	local targetCharacter = humanoid.Parent
	local targetPlayer = targetCharacter and Players:GetPlayerFromCharacter(targetCharacter)
	if targetPlayer and targetPlayer ~= attacker and attackingTeam and targetPlayer.Team == attackingTeam then
		return false
	end
	if targetCharacter and targetCharacter:FindFirstChildOfClass("ForceField") then
		return false
	end
	if attacker then
		local multiplier = attacker:GetAttribute("AbilityDamageMultiplier")
		if typeof(multiplier) == "number" then
			amount *= math.clamp(multiplier, 0.5, 2)
		end
	end
	if targetPlayer then
		local reduction = targetPlayer:GetAttribute("AbilityDamageReduction")
		if typeof(reduction) == "number" then
			amount *= 1 - math.clamp(reduction, 0, 0.8)
		end
	end

	if targetPlayer then
		lastHits[humanoid] = {
			attacker = attacker,
			sourceName = sourceName,
			weapon = weapon,
			time = os.clock(),
		}
	end
	if targetPlayer and attacker and targetPlayer ~= attacker then
		local contributions = damageContributions[humanoid]
		if not contributions then
			contributions = {}
			damageContributions[humanoid] = contributions
		end
		local previous = contributions[attacker]
		contributions[attacker] = {
			damage = (previous and previous.damage or 0) + math.min(humanoid.Health, amount),
			time = os.clock(),
		}
	end
	if targetPlayer and targetPlayer ~= attacker and attackingTeam then
		local spottedAttribute = "SpottedUntil_" .. attackingTeam.Name
		local now = workspace:GetServerTimeNow()
		local current = targetPlayer:GetAttribute(spottedAttribute)
		if typeof(current) ~= "number" or current < now + 3.25 then
			targetPlayer:SetAttribute(spottedAttribute, now + 4)
		end
	end

	local healthBefore = humanoid.Health
	humanoid:TakeDamage(math.clamp(amount, 0, 500))
	local appliedDamage = math.max(0, healthBefore - humanoid.Health)
	if appliedDamage > 0 and attacker and targetPlayer ~= attacker then
		damageFeedbackEvent:FireClient(attacker, math.round(appliedDamage), humanoid.Health <= 0, "Hit", nil, award)
	end
	if appliedDamage > 0 and targetPlayer and targetPlayer ~= attacker then
		local attackerRoot = attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
		local sourcePosition = if attackerRoot and attackerRoot:IsA("BasePart") then attackerRoot.Position else nil
		damageFeedbackEvent:FireClient(
			targetPlayer,
			math.round(appliedDamage),
			humanoid.Health <= 0,
			"Taken",
			sourcePosition
		)
	end
	return true
end

function CombatService.Damage(
	attacker: Player,
	humanoid: Humanoid,
	amount: number,
	weapon: string,
	award: string?
): boolean
	return damageInternal(attacker, attacker.Team, nil, humanoid, amount, weapon, award)
end

function CombatService.DamageFromTeam(
	attackingTeam: Team,
	sourceName: string,
	humanoid: Humanoid,
	amount: number,
	weapon: string
): boolean
	return damageInternal(nil, attackingTeam, sourceName, humanoid, amount, weapon, nil)
end

function CombatService.AddCapture(player: Player)
	CombatService.Init()
	if player.Parent == Players then
		addCareerAndRound(player, "Captures", 1)
		awardScore(player, 500, "FLAG CAPTURE")
	end
end

function CombatService.AddObjective(player: Player, points: number, reason: string)
	CombatService.Init()
	if player.Parent == Players and typeof(points) == "number" and typeof(reason) == "string" then
		awardScore(player, math.clamp(math.floor(points), 1, 1000), reason)
	end
end

function CombatService.BreakSpawnProtection(player: Player)
	local character = player.Character
	local forceField = character and character:FindFirstChild("SpawnProtection")
	if forceField and forceField:IsA("ForceField") then
		forceField:Destroy()
	end
	if player:GetAttribute("SpawnProtectedUntil") ~= 0 then
		player:SetAttribute("SpawnProtectedUntil", 0)
	end
end

CombatService.Init()

return CombatService
