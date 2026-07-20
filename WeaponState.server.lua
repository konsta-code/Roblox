-- WeaponState.server.lua
-- Ablageort: ServerScriptService
--
-- Serverautoritative Waffenwahl: der Client meldet per SelectWeapon, welche
-- Waffe ausgerüstet ist; der Server speichert das pro Spieler als Attribut
-- "EquippedWeapon". Die Waffen-Server-Scripts (ProjectileWeapon, Chaingun)
-- prüfen beim Feuern gegen dieses Attribut - damit kann ein Client nicht beide
-- Waffen gleichzeitig über die Remotes feuern (Waffe muss ausgerüstet sein).
--
-- Benötigt: RemoteEvent "SelectWeapon" in ReplicatedStorage (Client -> Server)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local selectEvent = ReplicatedStorage:WaitForChild("SelectWeapon")

local VALID_WEAPONS = { Spinfusor = true, Chaingun = true }
local SELECT_COOLDOWN = 0.1 -- gegen Remote-Spam
local lastSelect: { [Player]: number } = {}

local function setDefault(player: Player)
	player:SetAttribute("EquippedWeapon", "Spinfusor")
end

selectEvent.OnServerEvent:Connect(function(player: Player, weapon: any)
	if typeof(weapon) ~= "string" or not VALID_WEAPONS[weapon] then
		return -- ungültige/erfundene Daten ignorieren
	end
	if player:GetAttribute("EquippedWeapon") == weapon then
		return
	end
	local now = os.clock()
	if now - (lastSelect[player] or 0) < SELECT_COOLDOWN then
		return
	end
	lastSelect[player] = now
	player:SetAttribute("EquippedWeapon", weapon)
end)

Players.PlayerAdded:Connect(setDefault)
for _, player in Players:GetPlayers() do
	setDefault(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastSelect[player] = nil
end)
