-- LoadoutManager.server.lua
-- Serverseitige Auswahl und Anwendung von Rüstungsklassen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.LoadoutConstants)
local MatchSignals = require(ReplicatedStorage.Modules.MatchSignals)

local selectEvent = ReplicatedStorage:WaitForChild("SelectLoadout")
local lastChange: { [Player]: number } = {}

local function clearActiveAbility(player: Player, character: Model)
	player:SetAttribute("AbilityActiveUntil", 0)
	player:SetAttribute("AbilityReadyAt", 0)
	player:SetAttribute("AbilityMoveScale", 1)
	player:SetAttribute("AbilityDamageMultiplier", 1)
	player:SetAttribute("AbilityDamageReduction", 0)
	player:SetAttribute("IsCloaked", false)
	for _, descendant in character:GetDescendants() do
		if descendant.Name == "AbilityForceField" or descendant.Name == "AbilityHighlight" then
			descendant:Destroy()
		end
	end
end

local function applyPlayerAttributes(player: Player, definition: Constants.LoadoutDefinition)
	player:SetAttribute("ArmorClass", definition.armor)
	player:SetAttribute("MaxEnergy", definition.maxEnergy)
	player:SetAttribute("MaxGrenades", definition.maxGrenades)
	player:SetAttribute("WalkSpeedScale", definition.walkSpeedScale)
	player:SetAttribute("JetThrustScale", definition.jetThrustScale)
	player:SetAttribute("AirControlScale", definition.airControlScale)
	player:SetAttribute("SkiControlScale", definition.skiControlScale)
	player:SetAttribute("ImpulseScale", definition.impulseScale)
end

local function getDefinition(loadoutId: any): (Constants.LoadoutId?, Constants.LoadoutDefinition?)
	if typeof(loadoutId) ~= "string" then
		return nil, nil
	end
	local definition = Constants.LOADOUTS[loadoutId]
	if not definition then
		return nil, nil
	end
	return loadoutId :: Constants.LoadoutId, definition
end

local function applyLoadout(player: Player, character: Model)
	-- Ausstehende Auswahl beim Spawn übernehmen: das aktive Loadout-Attribut,
	-- das Waffen/Fähigkeit/Granate/HUD/Viewmodel LIVE lesen, wechselt so
	-- ausschließlich hier beim CharacterAdded - nie mitten im Leben.
	local pendingId = getDefinition(player:GetAttribute("PendingLoadout"))
	if pendingId then
		player:SetAttribute("Loadout", pendingId)
		player:SetAttribute("PendingLoadout", nil)
	end

	local loadoutId, definition = getDefinition(player:GetAttribute("Loadout"))
	if not loadoutId or not definition then
		loadoutId = Constants.DEFAULT_LOADOUT
		definition = Constants.LOADOUTS[loadoutId]
		player:SetAttribute("Loadout", loadoutId)
	end

	applyPlayerAttributes(player, definition)
	player:SetAttribute("Grenades", definition.maxGrenades)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = definition.maxHealth
	humanoid.Health = definition.maxHealth
end

local function setupPlayer(player: Player)
	if not Constants.LOADOUTS[player:GetAttribute("Loadout")] then
		player:SetAttribute("Loadout", Constants.DEFAULT_LOADOUT)
	end
	local definition = Constants.LOADOUTS[player:GetAttribute("Loadout")]
	applyPlayerAttributes(player, definition)

	player.CharacterAdded:Connect(function(character)
		applyLoadout(player, character)
	end)
	if player.Character then
		applyLoadout(player, player.Character)
	end
end

selectEvent.OnServerEvent:Connect(function(player: Player, requestedLoadout: any)
	local loadoutId, definition = getDefinition(requestedLoadout)
	if not loadoutId or not definition then
		selectEvent:FireClient(player, false, "Ungültiges Loadout")
		return
	end

	local now = os.clock()
	if now - (lastChange[player] or -math.huge) < Constants.CHANGE_COOLDOWN then
		selectEvent:FireClient(player, false, "Loadout-Wechsel noch im Cooldown")
		return
	end
	lastChange[player] = now
	local accessUntil = player:GetAttribute("InventoryAccessUntil")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local stationAccess = typeof(accessUntil) == "number" and accessUntil >= now
	-- Lobby/Warmup sind kampffreie Phasen (Damage nur InProgress/Overtime):
	-- ein Live-Wechsel ist dort genauso sicher wie an der Inventarstation --
	-- und Pflicht fuer den Lobby-Flow (Klasse waehlen -> sofort spuerbar).
	local matchPhase = MatchSignals.GetPhase()
	local outOfCombat = matchPhase == "Lobby" or matchPhase == "Warmup"
	if (stationAccess or outOfCombat)
		and character and humanoid and humanoid.Health > 0 then
		-- The station granted this short access window after validating team,
		-- proximity and generator power, so a live class swap is safe here.
		player:SetAttribute("Loadout", loadoutId)
		player:SetAttribute("PendingLoadout", nil)
		clearActiveAbility(player, character)
		applyLoadout(player, character)
		player:SetAttribute("InventoryAccessUntil", 0)
		selectEvent:FireClient(player, true, definition.displayName .. " sofort ausgerüstet")
		return
	end
	-- Auswahl NUR als AUSSTEHEND merken (PendingLoadout). Das aktive Loadout-
	-- Attribut, das Waffen/Fähigkeit/Granate/HUD/Viewmodel live lesen, wechselt
	-- erst beim nächsten Respawn (applyLoadout übernimmt PendingLoadout beim
	-- CharacterAdded). So gibt es KEINEN sofortigen Waffen-/Klassenwechsel im
	-- Leben - alles wechselt gemeinsam erst nach dem Tod.
	player:SetAttribute("PendingLoadout", loadoutId)
	selectEvent:FireClient(player, true, definition.displayName .. " - aktiv ab nächstem Tod")
end)

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastChange[player] = nil
end)
