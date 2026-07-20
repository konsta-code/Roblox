-- LoadoutManager.server.lua
-- Serverseitige Auswahl und Anwendung von Rüstungsklassen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.LoadoutConstants)
local MatchSignals = require(ReplicatedStorage.Modules.MatchSignals)

local selectEvent = ReplicatedStorage:WaitForChild("SelectLoadout")
local lastChange: { [Player]: number } = {}

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

local function canChangeNow(player: Player): boolean
	local inventoryAccess = player:GetAttribute("InventoryAccessUntil")
	if typeof(inventoryAccess) == "number" and inventoryAccess >= os.clock() then
		return true
	end
	if MatchSignals.GetPhase() ~= "InProgress" then
		return true
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid == nil or humanoid.Health <= 0 or character:FindFirstChildOfClass("ForceField") ~= nil
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
	if not canChangeNow(player) then
		selectEvent:FireClient(player, false, "Loadout nur im Warmup, nach dem Tod oder direkt am Spawn")
		return
	end

	lastChange[player] = now
	player:SetAttribute("Loadout", loadoutId)
	applyPlayerAttributes(player, definition)
	selectEvent:FireClient(player, true, definition.displayName .. " ausgewählt")
	player:LoadCharacter()
end)

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastChange[player] = nil
end)
