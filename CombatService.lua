-- CombatService.lua
-- Gemeinsame, serverautoritäre Schadens- und Statistikschicht. Waffen melden
-- Schaden hier, damit Friendly Fire, Kill-Zuordnung und Leaderstats nicht in
-- jeder Waffe unterschiedlich implementiert werden.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local combatFeedEvent = ReplicatedStorage:WaitForChild("CombatFeed")
local damageFeedbackEvent = ReplicatedStorage:WaitForChild("DamageFeedback")

local CombatService = {}

type HitInfo = {
	attacker: Player?,
	sourceName: string?,
	weapon: string,
	time: number,
}

local HIT_CREDIT_WINDOW = 10
local initialized = false
local lastHits: { [Humanoid]: HitInfo } = {}

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

local function bindCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		addStat(player, "Deaths", 1)

		local hit = lastHits[humanoid]
		lastHits[humanoid] = nil
		local killer: Player? = nil
		local killerName: string? = nil
		local weapon = "Umgebung"
		if hit and os.clock() - hit.time <= HIT_CREDIT_WINDOW then
			weapon = hit.weapon
			if hit.attacker and hit.attacker.Parent == Players and hit.attacker ~= player then
				killer = hit.attacker
				addStat(killer, "Kills", 1)
				killerName = killer.DisplayName
			elseif not hit.attacker then
				killerName = hit.sourceName
			end
		end

		combatFeedEvent:FireAllClients(killerName, player.DisplayName, weapon)
	end)
end

local function setupPlayer(player: Player)
	getOrCreateStat(player, "Kills")
	getOrCreateStat(player, "Deaths")
	getOrCreateStat(player, "Captures")

	player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			lastHits[humanoid] = nil
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
	weapon: string
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

	local healthBefore = humanoid.Health
	humanoid:TakeDamage(math.clamp(amount, 0, 500))
	local appliedDamage = math.max(0, healthBefore - humanoid.Health)
	if appliedDamage > 0 and attacker and targetPlayer ~= attacker then
		damageFeedbackEvent:FireClient(attacker, math.round(appliedDamage), humanoid.Health <= 0)
	end
	return true
end

function CombatService.Damage(attacker: Player, humanoid: Humanoid, amount: number, weapon: string): boolean
	return damageInternal(attacker, attacker.Team, nil, humanoid, amount, weapon)
end

function CombatService.DamageFromTeam(
	attackingTeam: Team,
	sourceName: string,
	humanoid: Humanoid,
	amount: number,
	weapon: string
): boolean
	return damageInternal(nil, attackingTeam, sourceName, humanoid, amount, weapon)
end

function CombatService.AddCapture(player: Player)
	CombatService.Init()
	if player.Parent == Players then
		addStat(player, "Captures", 1)
	end
end

CombatService.Init()

return CombatService
