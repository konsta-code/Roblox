-- PlayerData.server.lua
-- Ablageort: ServerScriptService
--
-- Persistenz der Karriere-Statistiken (Kills/Deaths/Captures) über DataStore.
-- CombatService legt die leaderstats pro Session an und zählt hoch, speichert
-- sie aber nicht. Dieses Script lädt die gespeicherten Karriere-Werte beim
-- Beitritt und ADDIERT sie auf den aktuellen Stand (frühe Session-Zähler gehen
-- so nicht verloren), speichert bei Verlassen, periodisch und beim Shutdown.
--
-- Alle DataStore-Zugriffe laufen in pcall mit Backoff-Retry. Schlägt das Laden
-- fehl, wird für den Spieler NICHT gespeichert - sonst würde eine Karriere mit
-- 0 überschrieben. In Studio bitte "Enable Studio Access to API Services"
-- aktivieren, sonst schlagen DataStore-Aufrufe fehl (Spiel läuft trotzdem,
-- nur ohne Persistenz).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local STAT_NAMES = { "Kills", "Deaths", "Captures" }
local STORE_NAME = "CareerStats_v1"
local AUTOSAVE_INTERVAL = 120
local MAX_RETRIES = 4

local store = DataStoreService:GetDataStore(STORE_NAME)
local loaded: { [Player]: boolean } = {}

local function keyFor(player: Player): string
	return "p_" .. player.UserId
end

local function ensureLeaderstats(player: Player): Folder
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	return leaderstats :: Folder
end

local function ensureStat(player: Player, name: string): IntValue
	local leaderstats = ensureLeaderstats(player)
	local stat = leaderstats:FindFirstChild(name)
	if not (stat and stat:IsA("IntValue")) then
		if stat then
			stat:Destroy()
		end
		stat = Instance.new("IntValue")
		stat.Name = name
		stat.Parent = leaderstats
	end
	return stat :: IntValue
end

-- pcall mit exponentiellem Backoff gegen DataStore-Throttling/Fehler.
local function retry(fn: () -> any): (boolean, any)
	local attempt = 0
	while attempt < MAX_RETRIES do
		attempt += 1
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		task.wait(0.2 * 2 ^ attempt)
	end
	return false, nil
end

local function loadPlayer(player: Player)
	local ok, data = retry(function()
		return store:GetAsync(keyFor(player))
	end)

	if player.Parent ~= Players then
		return -- Spieler ist während des Ladens gegangen
	end

	if ok and typeof(data) == "table" then
		for _, name in STAT_NAMES do
			local saved = data[name]
			if typeof(saved) == "number" then
				ensureStat(player, name).Value += math.max(0, math.floor(saved))
			end
		end
		loaded[player] = true
	elseif ok then
		-- kein gespeicherter Datensatz (neuer Spieler) - Karriere startet bei 0
		for _, name in STAT_NAMES do
			ensureStat(player, name)
		end
		loaded[player] = true
	else
		warn(
			"[PlayerData] Laden fehlgeschlagen für "
				.. player.Name
				.. " - Stats werden diese Session nicht gespeichert"
		)
	end
end

local function savePlayer(player: Player)
	if not loaded[player] then
		return -- nie erfolgreich geladen -> nicht speichern (Karriere nicht mit 0 überschreiben)
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local payload = {}
	for _, name in STAT_NAMES do
		local stat = leaderstats:FindFirstChild(name)
		payload[name] = (stat and stat:IsA("IntValue")) and stat.Value or 0
	end

	retry(function()
		store:SetAsync(keyFor(player), payload)
	end)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	loaded[player] = nil
end)

-- Periodisches Autosave (Absicherung gegen Crashes)
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			savePlayer(player)
		end
	end
end)

-- Beim Server-Shutdown alle noch verbliebenen Spieler speichern
game:BindToClose(function()
	if RunService:IsStudio() then
		return
	end
	for _, player in Players:GetPlayers() do
		task.spawn(savePlayer, player)
	end
	task.wait(2)
end)

print("[PlayerData] Karriere-Persistenz aktiv (Kills/Deaths/Captures)")
