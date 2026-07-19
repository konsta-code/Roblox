-- TeamAssignment.server.lua
-- Ablageort: ServerScriptService
--
-- Schließt die in SpawnManager.server.lua dokumentierte Lücke: ohne dieses
-- Script bleibt player.Team für neue Spieler nil, wodurch weder das
-- eingebaute SpawnLocation-System (TeamColor-Filter) noch die
-- CollectionService-Spawns (SpawnManager), noch die Capture-Logik
-- (CTFManager) noch der Friendly-Fire-Schutz der Waffen funktionieren.
--
-- Auto-Balance: Spieler werden immer dem Team mit weniger Mitgliedern
-- zugeteilt (bei Gleichstand: zufällig), damit Teams nie einseitig
-- volllaufen. Läuft in PlayerAdded, also vor dem ersten Character-Spawn.
--
-- Manueller Setup-Schritt: Zwei Team-Objekte in der Teams-Service anlegen
-- (Name "Red" und "Blue", siehe auch CTFManager.server.lua) - dieses Script
-- erzeugt keine Teams, es verteilt nur Spieler auf vorhandene.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local function getAssignableTeams(): { Team }
	local list = {}
	for _, team in Teams:GetTeams() do
		if not team.AutoAssignable then
			-- Team.AutoAssignable ist Robloxens eingebautes Flag für genau
			-- diesen Zweck (steuert auch Robloxens eigene Auto-Balance-Fälle).
			-- false heißt hier: kein Spawn-/Capture-Team, z.B. für Spectator.
			continue
		end
		table.insert(list, team)
	end
	return list
end

local function countMembers(team: Team): number
	return #team:GetPlayers()
end

local function pickSmallestTeam(teams: { Team }): Team?
	if #teams == 0 then return nil end

	local smallest = { teams[1] }
	local smallestCount = countMembers(teams[1])

	for i = 2, #teams do
		local count = countMembers(teams[i])
		if count < smallestCount then
			smallest = { teams[i] }
			smallestCount = count
		elseif count == smallestCount then
			table.insert(smallest, teams[i])
		end
	end

	return smallest[math.random(1, #smallest)]
end

local function assignTeam(player: Player)
	if player.Team then return end -- schon zugeteilt (z.B. Script-Reload im Test)

	local teams = getAssignableTeams()
	local team = pickSmallestTeam(teams)
	if not team then
		warn("TeamAssignment: keine Teams in der Teams-Service gefunden - " .. player.Name .. " bleibt teamlos")
		return
	end

	player.Team = team
	player.TeamColor = team.TeamColor
end

Players.PlayerAdded:Connect(assignTeam)
for _, player in Players:GetPlayers() do
	assignTeam(player)
end
