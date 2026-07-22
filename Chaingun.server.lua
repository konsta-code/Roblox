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
local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local CombatService = require(script.Parent.CombatService)
local BaseService = require(script.Parent.BaseService)

local fireEvent = ReplicatedStorage:WaitForChild("FireChaingun")

local lastFireTime: { [Player]: number } = {}
local chainStartTime: { [Player]: number } = {}
local heat: { [Player]: number } = {}
local lastHeatUpdateTime: { [Player]: number } = {}
local overheatUntil: { [Player]: number } = {}

local function getCurrentHeat(player: Player, now: number, profile: ClassKitConstants.AutomaticProfile): number
	local last = lastHeatUpdateTime[player] or now
	local elapsed = now - last
	return math.max(0, (heat[player] or 0) - profile.heatCooldownRate * elapsed)
end

local function validateAndApplyDamage(
	shooter: Player,
	origin: Vector3,
	direction: Vector3,
	profile: ClassKitConstants.AutomaticProfile
)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { shooter.Character }

	local aimFrame = CFrame.lookAt(Vector3.zero, direction.Unit)
	local pelletCount = math.clamp(math.floor(profile.pellets or 1), 1, 12)
	for _ = 1, pelletCount do
		local pitch = math.rad((math.random() - 0.5) * 2 * profile.spreadAngle)
		local yaw = math.rad((math.random() - 0.5) * 2 * profile.spreadAngle)
		local shotDirection = (aimFrame * CFrame.Angles(pitch, yaw, 0)).LookVector
		local result = workspace:Raycast(origin, shotDirection * profile.maxRange, rayParams)
		if result then
			local hitCharacter = result.Instance:FindFirstAncestorOfClass("Model")
			local targetPlayer = hitCharacter and Players:GetPlayerFromCharacter(hitCharacter)
			local targetHumanoid = hitCharacter and hitCharacter:FindFirstChildOfClass("Humanoid")
			local targetBotTeam = hitCharacter and hitCharacter:GetAttribute("BotTeam")
			local canDamage = if targetPlayer
				then targetPlayer == shooter or targetPlayer.Team ~= shooter.Team
				else targetBotTeam ~= nil and targetBotTeam ~= (shooter.Team and shooter.Team.Name)
			if targetHumanoid and targetHumanoid.Health > 0 and canDamage then
				CombatService.Damage(shooter, targetHumanoid, profile.damagePerHit, profile.name)
			else
				BaseService.DamageHit(shooter, result.Instance, profile.damagePerHit)
			end
		end
	end
end

local function isFiniteVector(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < 1e6 and math.abs(value.Y) < 1e6 and math.abs(value.Z) < 1e6
end

local function tryFire(player: Player, direction: any)
	local now = os.clock()
	local profile = ClassKitConstants.Get(player:GetAttribute("Loadout")).automatic

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return end
	if not isFiniteVector(direction) or direction.Magnitude < 0.5 then return end
	local origin = root.Position + direction.Unit * 2

	if (overheatUntil[player] or 0) > now then
		return -- Waffe überhitzt, Server ignoriert jeden Feuerversuch
	end

	local last = lastFireTime[player] or 0
	local singleShotCooldown = profile.singleShotCooldown
	if singleShotCooldown then
		if now - last < singleShotCooldown then
			return
		end
	else
		if now - last > profile.maxFireInterval * 1.5 then
			chainStartTime[player] = now -- Pause war lang genug: neue Feuersequenz, Spin-up von vorn
		end

		local spinProgress = math.clamp((now - (chainStartTime[player] or now)) / profile.spinUpTime, 0, 1)
		local requiredInterval = profile.maxFireInterval
			- (profile.maxFireInterval - profile.minFireInterval) * spinProgress
		if now - last < requiredInterval then
			return -- schneller als der aktuelle Spin-up-Zustand erlaubt
		end
	end
	CombatService.BreakSpawnProtection(player)
	lastFireTime[player] = now

	local newHeat = getCurrentHeat(player, now, profile) + profile.heatPerShot
	if newHeat >= Constants.HEAT_MAX then
		overheatUntil[player] = now + profile.overheatLockout
		newHeat = Constants.HEAT_MAX
	end
	heat[player] = newHeat
	lastHeatUpdateTime[player] = now

	validateAndApplyDamage(player, origin, direction, profile)
end

fireEvent.OnServerEvent:Connect(function(player: Player, direction: any, _claimedTarget: any)
	local silencedUntil = player:GetAttribute("AbilitySilencedUntil")
	if typeof(silencedUntil) == "number" and silencedUntil > workspace:GetServerTimeNow() then return end
	-- Serverautoritative Waffenwahl (WeaponState.server): nur feuern, wenn die
	-- Chaingun wirklich ausgerüstet ist - verhindert gleichzeitiges Feuern
	-- beider Waffen über gespoofte Remotes.
	if player:GetAttribute("EquippedWeapon") ~= "Chaingun" then return end
	tryFire(player, direction)
end)

local function resetPlayerWeapon(player: Player)
	lastFireTime[player] = nil
	chainStartTime[player] = nil
	heat[player] = nil
	lastHeatUpdateTime[player] = nil
	overheatUntil[player] = nil
end

local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		resetPlayerWeapon(player)
	end)
	player:GetAttributeChangedSignal("Loadout"):Connect(function()
		resetPlayerWeapon(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	resetPlayerWeapon(player)
end)
