-- Chaingun.server.lua
-- Ablageort: ServerScriptService
--
-- Anders als beim Splash-Projectile (komplett serverseitig simuliert) läuft
-- Hitscan andersrum: Client raycastet selbst (für Reaktionsfreude bei
-- Instant-Hit-Waffen ohne Travel-Time-Puffer), Server bestätigt mit einem
-- eigenen, unabhängigen Raycast gegen den behaupteten Treffer. Spin-up-
-- Feuerrate UND Hitze/Overheat werden ausschließlich serverseitig geführt -
-- der Client kann beides simulieren, aber nicht erzwingen.
--
-- Bekannte Lücke: Servers Raycast prüft gegen die aktuelle (replizierte)
-- Position des Ziels, nicht gegen eine lag-kompensierte Rückrechnung auf
-- den Schusszeitpunkt. Bei höherer Latenz werden dadurch gelegentlich
-- eigentlich berechtigte Treffer abgelehnt - nie das Gegenteil, Cheats
-- werden dadurch nicht leichter durchgelassen. Echte Lag-Compensation ist
-- Teil vom offenen "Server-Validator"-Baustein.
--
-- Benötigt: RemoteEvent "FireChaingun" in ReplicatedStorage (Client -> Server)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.ChaingunConstants)

local fireEvent = ReplicatedStorage:WaitForChild("FireChaingun")

local lastFireTime: { [Player]: number } = {}
local chainStartTime: { [Player]: number } = {}
local heat: { [Player]: number } = {}
local lastHeatUpdateTime: { [Player]: number } = {}
local overheatUntil: { [Player]: number } = {}

local function getCurrentHeat(player: Player, now: number): number
	local last = lastHeatUpdateTime[player] or now
	local elapsed = now - last
	return math.max(0, (heat[player] or 0) - Constants.HEAT_COOLDOWN_RATE * elapsed)
end

local function validateAndApplyDamage(shooter: Player, origin: Vector3, direction: Vector3, claimedTarget: Player)
	local targetCharacter = claimedTarget.Character
	local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then return end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { shooter.Character }

	local result = workspace:Raycast(origin, direction.Unit * Constants.MAX_RANGE, rayParams)
	if not result then return end

	local hitCharacter = result.Instance:FindFirstAncestorOfClass("Model")
	if hitCharacter ~= targetCharacter then return end -- Servers eigener Raycast bestätigt den Treffer nicht

	targetHumanoid:TakeDamage(Constants.DAMAGE_PER_HIT)
end

local function tryFire(player: Player, origin: Vector3, direction: Vector3, claimedTarget: Player?)
	local now = os.clock()

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - origin).Magnitude > 10 then
		return
	end

	if (overheatUntil[player] or 0) > now then
		return -- Waffe überhitzt, Server ignoriert jeden Feuerversuch
	end

	local last = lastFireTime[player] or 0
	if now - last > Constants.MAX_FIRE_INTERVAL * 1.5 then
		chainStartTime[player] = now -- Pause war lang genug: neue Feuersequenz, Spin-up von vorn
	end

	local spinProgress = math.clamp((now - (chainStartTime[player] or now)) / Constants.SPIN_UP_TIME, 0, 1)
	local requiredInterval = Constants.MAX_FIRE_INTERVAL
		- (Constants.MAX_FIRE_INTERVAL - Constants.MIN_FIRE_INTERVAL) * spinProgress

	if now - last < requiredInterval then
		return -- schneller als der aktuelle Spin-up-Zustand erlaubt
	end
	lastFireTime[player] = now

	local newHeat = getCurrentHeat(player, now) + Constants.HEAT_PER_SHOT
	if newHeat >= Constants.HEAT_MAX then
		overheatUntil[player] = now + Constants.OVERHEAT_LOCKOUT
		newHeat = Constants.HEAT_MAX
	end
	heat[player] = newHeat
	lastHeatUpdateTime[player] = now

	if claimedTarget then
		validateAndApplyDamage(player, origin, direction, claimedTarget)
	end
end

fireEvent.OnServerEvent:Connect(function(player: Player, origin: Vector3, direction: Vector3, claimedTarget: Player?)
	tryFire(player, origin, direction, claimedTarget)
end)

Players.PlayerRemoving:Connect(function(player)
	lastFireTime[player] = nil
	chainStartTime[player] = nil
	heat[player] = nil
	lastHeatUpdateTime[player] = nil
	overheatUntil[player] = nil
end)
