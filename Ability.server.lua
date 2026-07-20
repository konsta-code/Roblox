-- Server-authoritative class abilities. Clients only request activation.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AbilityConstants = require(ReplicatedStorage.Modules.AbilityConstants)
local CombatService = require(script.Parent.CombatService)

local activateEvent = ReplicatedStorage:WaitForChild("ActivateAbility")
local lastRequest: { [Player]: number } = {}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function getLivingCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function showPulse(position: Vector3, color: Color3, radius: number)
	local sphere = Instance.new("Part")
	sphere.Name = "AbilityPulse"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.one * 2
	sphere.Position = position
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanTouch = false
	sphere.CanQuery = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = color
	sphere.Transparency = 0.55
	sphere.Parent = workspace
	TweenService:Create(sphere, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * radius * 2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(sphere, 0.4)
end

local function addHighlight(character: Model, color: Color3, duration: number, fillTransparency: number)
	local highlight = Instance.new("Highlight")
	highlight.Name = "AbilityHighlight"
	highlight.Adornee = character
	highlight.FillColor = color
	highlight.FillTransparency = fillTransparency
	highlight.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.45)
	highlight.OutlineTransparency = 0.12
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
	Debris:AddItem(highlight, duration)
end

local function resetTimedAttribute(player: Player, attributeName: string, resetValue: any, activeUntil: number)
	task.delay(math.max(0, activeUntil - serverNow()), function()
		if player.Parent == Players and (player:GetAttribute("AbilityActiveUntil") or 0) <= serverNow() + 0.05 then
			player:SetAttribute(attributeName, resetValue)
		end
	end)
end

local function activateCloak(player: Player, character: Model, activeUntil: number)
	local originals: { [Instance]: number } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			originals[descendant] = descendant.Transparency
			descendant.Transparency = math.max(descendant.Transparency, 0.72)
		end
	end
	player:SetAttribute("IsCloaked", true)
	task.delay(math.max(0, activeUntil - serverNow()), function()
		if player.Parent ~= Players then return end
		player:SetAttribute("IsCloaked", false)
		for instance, transparency in originals do
			if instance.Parent then
				(instance :: any).Transparency = transparency
			end
		end
	end)
end

local function activateFor(player: Player, loadout: string, activeUntil: number)
	local character, humanoid, root = getLivingCharacter(player)
	if not character or not humanoid or not root then return end
	local definition = AbilityConstants.Get(loadout)

	if loadout == "Pathfinder" then
		player:SetAttribute("AbilityMoveScale", 1.25)
		resetTimedAttribute(player, "AbilityMoveScale", 1, activeUntil)
		addHighlight(character, definition.color, definition.duration, 0.82)
	elseif loadout == "Sentinel" then
		player:SetAttribute("AbilityDamageMultiplier", 1.35)
		resetTimedAttribute(player, "AbilityDamageMultiplier", 1, activeUntil)
		addHighlight(character, definition.color, definition.duration, 0.88)
	elseif loadout == "Infiltrator" then
		activateCloak(player, character, activeUntil)
	elseif loadout == "Soldier" then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 45)
	elseif loadout == "Technician" then
		for _, teammate in Players:GetPlayers() do
			if teammate.Team == player.Team then
				local teammateCharacter, teammateHumanoid, teammateRoot = getLivingCharacter(teammate)
				if teammateCharacter and teammateHumanoid and teammateRoot
					and (teammateRoot.Position - root.Position).Magnitude <= 55 then
					teammateHumanoid.Health = math.min(teammateHumanoid.MaxHealth, teammateHumanoid.Health + 35)
					addHighlight(teammateCharacter, definition.color, 0.8, 0.86)
				end
			end
		end
	elseif loadout == "Raider" then
		for _, enemy in Players:GetPlayers() do
			if enemy ~= player and enemy.Team ~= player.Team then
				local enemyCharacter, _, enemyRoot = getLivingCharacter(enemy)
				if enemyCharacter and enemyRoot and (enemyRoot.Position - root.Position).Magnitude <= 48 then
					enemy:SetAttribute("AbilitySilencedUntil", math.max(enemy:GetAttribute("AbilitySilencedUntil") or 0, activeUntil))
					addHighlight(enemyCharacter, definition.color, 0.9, 0.76)
				end
			end
		end
	elseif loadout == "Juggernaut" then
		player:SetAttribute("AbilityDamageReduction", 0.45)
		resetTimedAttribute(player, "AbilityDamageReduction", 0, activeUntil)
		addHighlight(character, definition.color, definition.duration, 0.7)
	elseif loadout == "Brute" then
		for _, enemy in Players:GetPlayers() do
			if enemy ~= player and enemy.Team ~= player.Team then
				local _, enemyHumanoid, enemyRoot = getLivingCharacter(enemy)
				if enemyHumanoid and enemyRoot then
					local offset = enemyRoot.Position - root.Position
					if offset.Magnitude <= 34 then
						CombatService.Damage(player, enemyHumanoid, 32, "Shockwave")
						local direction = if offset.Magnitude > 0.1 then offset.Unit else Vector3.xAxis
						enemyRoot.AssemblyLinearVelocity += direction * 55 + Vector3.yAxis * 22
					end
				end
			end
		end
	elseif loadout == "Doombringer" then
		local forceField = Instance.new("ForceField")
		forceField.Name = "AbilityForceField"
		forceField.Visible = true
		forceField.Parent = character
		Debris:AddItem(forceField, definition.duration)
	end

	showPulse(root.Position, definition.color, if loadout == "Brute" then 34 elseif loadout == "Raider" then 48 else 12)
end

local function setupPlayer(player: Player)
	player:SetAttribute("AbilityReadyAt", 0)
	player:SetAttribute("AbilitySilencedUntil", 0)
	local function resetActiveState()
		player:SetAttribute("AbilityActiveUntil", 0)
		player:SetAttribute("AbilitySilencedUntil", 0)
		player:SetAttribute("AbilityMoveScale", 1)
		player:SetAttribute("AbilityDamageMultiplier", 1)
		player:SetAttribute("AbilityDamageReduction", 0)
		player:SetAttribute("IsCloaked", false)
	end
	resetActiveState()
	player.CharacterAdded:Connect(resetActiveState)
end

activateEvent.OnServerEvent:Connect(function(player: Player)
	local requestTime = os.clock()
	if requestTime - (lastRequest[player] or -math.huge) < 0.1 then return end
	lastRequest[player] = requestTime

	local now = serverNow()
	if (player:GetAttribute("AbilityReadyAt") or 0) > now then
		activateEvent:FireClient(player, false, "Fähigkeit lädt noch")
		return
	end
	if (player:GetAttribute("AbilitySilencedUntil") or 0) > now then
		activateEvent:FireClient(player, false, "Durch EMP blockiert")
		return
	end
	local character = getLivingCharacter(player)
	if not character then return end

	local loadout = player:GetAttribute("Loadout")
	if typeof(loadout) ~= "string" or not AbilityConstants.ABILITIES[loadout] then return end
	local definition = AbilityConstants.Get(loadout)
	local activeUntil = now + definition.duration
	player:SetAttribute("AbilityReadyAt", now + definition.cooldown)
	player:SetAttribute("AbilityActiveUntil", activeUntil)
	player:SetAttribute("AbilityName", definition.name)
	activateFor(player, loadout, activeUntil)
	activateEvent:FireClient(player, true, definition.name)
end)

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)

print("[Ability] nine class abilities loaded")
