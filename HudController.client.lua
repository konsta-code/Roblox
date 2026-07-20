-- HudController.client.lua
-- Ablageort: StarterPlayerScripts
--
-- Baut das komplette HUD zur Laufzeit per Script.
-- + Crosshair für präzises Zielen

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")

local PlayerHudState = require(ReplicatedStorage.Modules.PlayerHudState)
local WeaponFeedback = require(ReplicatedStorage.Modules.WeaponFeedback)
local WeaponState = require(ReplicatedStorage.Modules.WeaponState)

local player = Players.LocalPlayer
local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)

local scoreEvent = ReplicatedStorage:WaitForChild("CTFScoreUpdate")
local carryStatusEvent = ReplicatedStorage:WaitForChild("FlagCarryStatus")
local matchStateEvent = ReplicatedStorage:WaitForChild("MatchStateChanged")
local combatFeedEvent = ReplicatedStorage:WaitForChild("CombatFeed")
local damageFeedbackEvent = ReplicatedStorage:WaitForChild("DamageFeedback")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MatchHud"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

-- === CROSSHAIR ===

local crosshairFrame = Instance.new("Frame")
crosshairFrame.Name = "Crosshair"
crosshairFrame.Size = UDim2.fromOffset(28, 28)
crosshairFrame.AnchorPoint = Vector2.new(0.5, 0.5)
crosshairFrame.Position = UDim2.fromScale(0.5, 0.5)
crosshairFrame.BackgroundTransparency = 1
crosshairFrame.Parent = screenGui

local hBar = Instance.new("Frame")
hBar.Size = UDim2.fromOffset(18, 2)
hBar.AnchorPoint = Vector2.new(0.5, 0.5)
hBar.Position = UDim2.fromScale(0.5, 0.5)
hBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
hBar.BackgroundTransparency = 0.15
hBar.BorderSizePixel = 0
hBar.Parent = crosshairFrame

local vBar = Instance.new("Frame")
vBar.Size = UDim2.fromOffset(2, 18)
vBar.AnchorPoint = Vector2.new(0.5, 0.5)
vBar.Position = UDim2.fromScale(0.5, 0.5)
vBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
vBar.BackgroundTransparency = 0.15
vBar.BorderSizePixel = 0
vBar.Parent = crosshairFrame

local centerDot = Instance.new("Frame")
centerDot.Size = UDim2.fromOffset(3, 3)
centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
centerDot.Position = UDim2.fromScale(0.5, 0.5)
centerDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
centerDot.BorderSizePixel = 0
centerDot.Parent = crosshairFrame

local centerCorner = Instance.new("UICorner")
centerCorner.CornerRadius = UDim.new(1, 0)
centerCorner.Parent = centerDot

local hitMarker = Instance.new("TextLabel")
hitMarker.Name = "HitMarker"
hitMarker.Size = UDim2.fromOffset(90, 24)
hitMarker.AnchorPoint = Vector2.new(0.5, 0)
hitMarker.Position = UDim2.new(0.5, 0, 0.5, 18)
hitMarker.BackgroundTransparency = 1
hitMarker.Font = Enum.Font.GothamBold
hitMarker.TextSize = 14
hitMarker.TextColor3 = Color3.fromRGB(255, 255, 255)
hitMarker.TextTransparency = 1
hitMarker.Parent = screenGui

-- === Weapon cooldown / shot readiness ===

local cooldownFrame = Instance.new("Frame")
cooldownFrame.Name = "WeaponCooldown"
cooldownFrame.Size = UDim2.fromOffset(138, 22)
cooldownFrame.AnchorPoint = Vector2.new(0.5, 0)
cooldownFrame.Position = UDim2.new(0.5, 0, 0.5, 31)
cooldownFrame.BackgroundColor3 = Color3.fromRGB(8, 13, 20)
cooldownFrame.BackgroundTransparency = 0.2
cooldownFrame.BorderSizePixel = 0
cooldownFrame.Parent = screenGui

local cooldownCorner = Instance.new("UICorner")
cooldownCorner.CornerRadius = UDim.new(0, 5)
cooldownCorner.Parent = cooldownFrame

local cooldownTrack = Instance.new("Frame")
cooldownTrack.Name = "Track"
cooldownTrack.Size = UDim2.new(1, -8, 0, 6)
cooldownTrack.Position = UDim2.fromOffset(4, 12)
cooldownTrack.BackgroundColor3 = Color3.fromRGB(34, 43, 54)
cooldownTrack.BorderSizePixel = 0
cooldownTrack.ClipsDescendants = true
cooldownTrack.Parent = cooldownFrame

local cooldownTrackCorner = Instance.new("UICorner")
cooldownTrackCorner.CornerRadius = UDim.new(1, 0)
cooldownTrackCorner.Parent = cooldownTrack

local cooldownFill = Instance.new("Frame")
cooldownFill.Name = "Fill"
cooldownFill.Size = UDim2.fromScale(1, 1)
cooldownFill.BackgroundColor3 = Color3.fromRGB(80, 225, 165)
cooldownFill.BorderSizePixel = 0
cooldownFill.Parent = cooldownTrack

local cooldownFillCorner = Instance.new("UICorner")
cooldownFillCorner.CornerRadius = UDim.new(1, 0)
cooldownFillCorner.Parent = cooldownFill

local cooldownLabel = Instance.new("TextLabel")
cooldownLabel.Name = "Status"
cooldownLabel.Size = UDim2.new(1, -8, 0, 11)
cooldownLabel.Position = UDim2.fromOffset(4, 1)
cooldownLabel.BackgroundTransparency = 1
cooldownLabel.Font = Enum.Font.GothamBold
cooldownLabel.Text = "BEREIT"
cooldownLabel.TextColor3 = Color3.fromRGB(150, 245, 205)
cooldownLabel.TextSize = 9
cooldownLabel.Parent = cooldownFrame

RunService.RenderStepped:Connect(function()
	local selected = WeaponState.Get()
	local startedAt, duration = WeaponFeedback.GetCooldown(selected)
	local elapsed = os.clock() - startedAt
	local ratio = if duration <= 0 then 1 else math.clamp(elapsed / duration, 0, 1)
	local ready = ratio >= 1

	cooldownFrame.Visible = player:GetAttribute("LoadoutMenuOpen") ~= true
	cooldownFill.Size = UDim2.fromScale(ratio, 1)
	cooldownFill.BackgroundColor3 = if ready
		then Color3.fromRGB(80, 225, 165)
		else Color3.fromRGB(255, 174, 68)
	cooldownLabel.TextColor3 = if ready
		then Color3.fromRGB(150, 245, 205)
		else Color3.fromRGB(255, 208, 125)
	cooldownLabel.Text = if ready
		then "BEREIT"
		else string.format("LÄDT  %.1fs", math.max(0, duration - elapsed))

	local crosshairColor = if ready
		then Color3.fromRGB(235, 250, 255)
		else Color3.fromRGB(255, 170, 70)
	hBar.BackgroundColor3 = crosshairColor
	vBar.BackgroundColor3 = crosshairColor
	centerDot.BackgroundColor3 = if ready
		then Color3.fromRGB(80, 225, 165)
		else Color3.fromRGB(255, 120, 65)
end)

-- === Health / Jetpack Bars ===

local function makeBar(anchorPoint: Vector2, position: UDim2, fillColor: Color3): (Frame, TextLabel)
	local container = Instance.new("Frame")
	container.Size = UDim2.fromOffset(220, 46)
	container.AnchorPoint = anchorPoint
	container.Position = position
	container.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	container.BackgroundTransparency = 0.25
	container.BorderSizePixel = 0
	container.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = container

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -16, 0, 10)
	track.Position = UDim2.fromOffset(8, 30)
	track.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	track.BorderSizePixel = 0
	track.Parent = container

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 0, 18)
	label.Position = UDim2.fromOffset(8, 4)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(235, 235, 240)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	return fill, label
end

local healthFill, healthLabel = makeBar(Vector2.new(0, 1), UDim2.new(0, 24, 1, -24), Color3.fromRGB(220, 70, 70))
healthLabel.Text = "HEALTH"

local jetpackFill, jetpackLabel = makeBar(Vector2.new(1, 1), UDim2.new(1, -24, 1, -24), Color3.fromRGB(70, 170, 220))
jetpackLabel.Text = "JETPACK"

local equipmentLabel = Instance.new("TextLabel")
equipmentLabel.Size = UDim2.fromOffset(390, 24)
equipmentLabel.AnchorPoint = Vector2.new(0.5, 1)
equipmentLabel.Position = UDim2.new(0.5, 0, 1, -46)
equipmentLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
equipmentLabel.BackgroundTransparency = 0.35
equipmentLabel.BorderSizePixel = 0
equipmentLabel.Font = Enum.Font.GothamBold
equipmentLabel.TextSize = 13
equipmentLabel.TextColor3 = Color3.fromRGB(225, 225, 235)
equipmentLabel.Parent = screenGui

local equipmentCorner = Instance.new("UICorner")
equipmentCorner.CornerRadius = UDim.new(0, 6)
equipmentCorner.Parent = equipmentLabel

local function refreshEquipment()
	local grenades = player:GetAttribute("Grenades")
	local grenadeName = string.upper(ClassKitConstants.Get(player:GetAttribute("Loadout")).grenade.name)
	equipmentLabel.Text = string.format(
		"[G] %s x%d     [F] MELEE",
		grenadeName,
		typeof(grenades) == "number" and grenades or 0
	)
end

player:GetAttributeChangedSignal("Grenades"):Connect(refreshEquipment)
player:GetAttributeChangedSignal("Loadout"):Connect(refreshEquipment)
refreshEquipment()

-- === Score ===

local scoreFrame = Instance.new("Frame")
scoreFrame.Size = UDim2.fromOffset(260, 64)
scoreFrame.AnchorPoint = Vector2.new(0.5, 0)
scoreFrame.Position = UDim2.new(0.5, 0, 0, 20)
scoreFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
scoreFrame.BackgroundTransparency = 0.25
scoreFrame.BorderSizePixel = 0
scoreFrame.Parent = screenGui

local scoreCorner = Instance.new("UICorner")
scoreCorner.CornerRadius = UDim.new(0, 8)
scoreCorner.Parent = scoreFrame

local scoreLabel = Instance.new("TextLabel")
scoreLabel.Size = UDim2.new(1, 0, 0, 40)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Font = Enum.Font.GothamBold
scoreLabel.TextSize = 20
scoreLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
scoreLabel.Text = "0  --  0"
scoreLabel.Parent = scoreFrame

local phaseLabel = Instance.new("TextLabel")
phaseLabel.Size = UDim2.new(1, 0, 0, 20)
phaseLabel.Position = UDim2.new(0, 0, 0, 40)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Font = Enum.Font.Gotham
phaseLabel.TextSize = 13
phaseLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
phaseLabel.Text = "Aufwaermphase"
phaseLabel.Parent = scoreFrame

local carryBanner = Instance.new("TextLabel")
carryBanner.Size = UDim2.fromOffset(320, 34)
carryBanner.AnchorPoint = Vector2.new(0.5, 0)
carryBanner.Position = UDim2.new(0.5, 0, 0, 92)
carryBanner.BackgroundColor3 = Color3.fromRGB(230, 200, 60)
carryBanner.BorderSizePixel = 0
carryBanner.Font = Enum.Font.GothamBold
carryBanner.TextSize = 16
carryBanner.TextColor3 = Color3.fromRGB(20, 20, 20)
carryBanner.Text = "DU TRAEGST DIE FLAGGE"
carryBanner.Visible = false
carryBanner.Parent = screenGui

local carryCorner = Instance.new("UICorner")
carryCorner.CornerRadius = UDim.new(0, 8)
carryCorner.Parent = carryBanner

local winnerOverlay = Instance.new("TextLabel")
winnerOverlay.Size = UDim2.fromOffset(500, 80)
winnerOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
winnerOverlay.Position = UDim2.new(0.5, 0, 0.4, 0)
winnerOverlay.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
winnerOverlay.BackgroundTransparency = 0.15
winnerOverlay.BorderSizePixel = 0
winnerOverlay.Font = Enum.Font.GothamBold
winnerOverlay.TextSize = 32
winnerOverlay.TextColor3 = Color3.fromRGB(245, 245, 250)
winnerOverlay.Text = ""
winnerOverlay.Visible = false
winnerOverlay.Parent = screenGui

local winnerCorner = Instance.new("UICorner")
winnerCorner.CornerRadius = UDim.new(0, 12)
winnerCorner.Parent = winnerOverlay

local combatFeed = Instance.new("Frame")
combatFeed.Name = "CombatFeed"
combatFeed.Size = UDim2.fromOffset(360, 160)
combatFeed.AnchorPoint = Vector2.new(1, 0)
combatFeed.Position = UDim2.new(1, -24, 0, 24)
combatFeed.BackgroundTransparency = 1
combatFeed.Parent = screenGui

local feedLayout = Instance.new("UIListLayout")
feedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
feedLayout.Padding = UDim.new(0, 4)
feedLayout.Parent = combatFeed

-- === Live-Updates ===

local scores: { [string]: number } = {}

local function refreshScoreLabel()
	local names = {}
	for name in scores do
		table.insert(names, name)
	end
	table.sort(names)

	if #names >= 2 then
		scoreLabel.Text = string.format("%s %d  --  %d %s", names[1], scores[names[1]], scores[names[2]], names[2])
	elseif #names == 1 then
		scoreLabel.Text = string.format("%s %d", names[1], scores[names[1]])
	end
end

local function syncTeamScore(teamName: string)
	local score = ReplicatedStorage:GetAttribute("CTFScore_" .. teamName)
	if typeof(score) == "number" then
		scores[teamName] = score
		refreshScoreLabel()
	end
end

for _, team in Teams:GetTeams() do
	local attributeName = "CTFScore_" .. team.Name
	ReplicatedStorage:GetAttributeChangedSignal(attributeName):Connect(function()
		syncTeamScore(team.Name)
	end)
	syncTeamScore(team.Name)
end

scoreEvent.OnClientEvent:Connect(function(teamName: string, newScore: number)
	scores[teamName] = newScore
	refreshScoreLabel()
end)

carryStatusEvent.OnClientEvent:Connect(function(isCarrying: boolean)
	carryBanner.Visible = isCarrying
end)

combatFeedEvent.OnClientEvent:Connect(function(killerName: string?, victimName: string, weapon: string)
	local entry = Instance.new("TextLabel")
	entry.Size = UDim2.fromOffset(350, 26)
	entry.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	entry.BackgroundTransparency = 0.25
	entry.BorderSizePixel = 0
	entry.Font = Enum.Font.GothamBold
	entry.TextSize = 13
	entry.TextColor3 = Color3.fromRGB(235, 235, 240)
	entry.TextXAlignment = Enum.TextXAlignment.Right
	entry.Text = if killerName
		then string.format("%s  [%s]  %s", killerName, weapon, victimName)
		else string.format("%s ist gefallen", victimName)
	entry.Parent = combatFeed

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = entry

	local feedEntries = {}
	for _, child in combatFeed:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(feedEntries, child)
		end
	end
	if #feedEntries > 5 then
		feedEntries[1]:Destroy()
	end

	task.delay(5, function()
		if entry.Parent then
			TweenService:Create(entry, TweenInfo.new(0.35), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
			}):Play()
			task.delay(0.4, function()
				entry:Destroy()
			end)
		end
	end)
end)

local hitMarkerSequence = 0
damageFeedbackEvent.OnClientEvent:Connect(function(damage: number, killed: boolean)
	hitMarkerSequence += 1
	local sequence = hitMarkerSequence
	hitMarker.Text = killed and ("KILL  +" .. damage) or ("HIT  +" .. damage)
	hitMarker.TextColor3 = killed and Color3.fromRGB(255, 210, 70) or Color3.fromRGB(255, 255, 255)
	hitMarker.TextTransparency = 0
	task.delay(killed and 0.45 or 0.18, function()
		if sequence ~= hitMarkerSequence then
			return
		end
		TweenService:Create(hitMarker, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
	end)
end)

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", mins, secs)
end

local PHASE_LABELS = {
	Warmup = "Aufwaermphase",
	InProgress = "Laufende Runde",
	PostMatch = "Rundenende",
}

local function applyMatchState(phase: string, timeRemaining: number, winnerName: string?)
	phaseLabel.Text = string.format("%s - %s", PHASE_LABELS[phase] or phase, formatTime(timeRemaining))

	if phase == "PostMatch" and winnerName then
		winnerOverlay.Text = winnerName == "Unentschieden" and "UNENTSCHIEDEN" or (winnerName .. " GEWINNT")
		winnerOverlay.Visible = true
	else
		winnerOverlay.Visible = false
	end
end

matchStateEvent.OnClientEvent:Connect(applyMatchState)

local function syncMatchState()
	local phase = ReplicatedStorage:GetAttribute("MatchPhase")
	local timeRemaining = ReplicatedStorage:GetAttribute("MatchTimeRemaining")
	local winnerName = ReplicatedStorage:GetAttribute("MatchWinner")
	if typeof(phase) == "string" and typeof(timeRemaining) == "number" then
		applyMatchState(phase, timeRemaining, if typeof(winnerName) == "string" then winnerName else nil)
	end
end

ReplicatedStorage:GetAttributeChangedSignal("MatchPhase"):Connect(syncMatchState)
ReplicatedStorage:GetAttributeChangedSignal("MatchTimeRemaining"):Connect(syncMatchState)
ReplicatedStorage:GetAttributeChangedSignal("MatchWinner"):Connect(syncMatchState)
syncMatchState()

PlayerHudState.JetpackEnergyChanged:Connect(function(energy: number)
	local maxEnergy = player:GetAttribute("MaxEnergy")
	local ratio = math.clamp(energy / (typeof(maxEnergy) == "number" and maxEnergy or 100), 0, 1)
	TweenService:Create(jetpackFill, TweenInfo.new(0.15), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
end)

local function bindHealth(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	local function updateHealth()
		local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		TweenService:Create(healthFill, TweenInfo.new(0.15), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
	end

	humanoid.HealthChanged:Connect(updateHealth)
	updateHealth()
end

if player.Character then
	bindHealth(player.Character)
end
player.CharacterAdded:Connect(bindHealth)
