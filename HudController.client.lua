-- HudController.client.lua
-- Ablageort: StarterPlayerScripts
--
-- Baut das komplette HUD zur Laufzeit per Script (kein manuelles GUI-Bauen
-- in Studio nötig). Score + Flaggen-Status kommen vom Server, Jetpack-
-- Energie von SkiController über PlayerHudState, Health direkt vom Humanoid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PlayerHudState = require(ReplicatedStorage.Modules.PlayerHudState)

local player = Players.LocalPlayer

local scoreEvent = ReplicatedStorage:WaitForChild("CTFScoreUpdate")
local carryStatusEvent = ReplicatedStorage:WaitForChild("FlagCarryStatus")
local matchStateEvent = ReplicatedStorage:WaitForChild("MatchStateChanged")

-- === GUI-Aufbau ===

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MatchHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

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

-- Health (unten links)
local healthFill, healthLabel = makeBar(
	Vector2.new(0, 1),
	UDim2.new(0, 24, 1, -24),
	Color3.fromRGB(220, 70, 70)
)
healthLabel.Text = "HEALTH"

-- Jetpack (unten rechts)
local jetpackFill, jetpackLabel = makeBar(
	Vector2.new(1, 1),
	UDim2.new(1, -24, 1, -24),
	Color3.fromRGB(70, 170, 220)
)
jetpackLabel.Text = "JETPACK"

-- === Score (oben mittig) ===

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
scoreLabel.Text = "0  —  0"
scoreLabel.Parent = scoreFrame

local phaseLabel = Instance.new("TextLabel")
phaseLabel.Size = UDim2.new(1, 0, 0, 20)
phaseLabel.Position = UDim2.new(0, 0, 0, 40)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Font = Enum.Font.Gotham
phaseLabel.TextSize = 13
phaseLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
phaseLabel.Text = "Aufwärmphase"
phaseLabel.Parent = scoreFrame

-- === Flag-Carry-Banner (nur sichtbar wenn aktiv) ===

local carryBanner = Instance.new("TextLabel")
carryBanner.Size = UDim2.fromOffset(320, 34)
carryBanner.AnchorPoint = Vector2.new(0.5, 0)
carryBanner.Position = UDim2.new(0.5, 0, 0, 92)
carryBanner.BackgroundColor3 = Color3.fromRGB(230, 200, 60)
carryBanner.BorderSizePixel = 0
carryBanner.Font = Enum.Font.GothamBold
carryBanner.TextSize = 16
carryBanner.TextColor3 = Color3.fromRGB(20, 20, 20)
carryBanner.Text = "DU TRÄGST DIE FLAGGE"
carryBanner.Visible = false
carryBanner.Parent = screenGui

local carryCorner = Instance.new("UICorner")
carryCorner.CornerRadius = UDim.new(0, 8)
carryCorner.Parent = carryBanner

-- === Winner-Overlay (nur sichtbar in PostMatch) ===

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

-- === Live-Updates ===

local scores: { [string]: number } = {}

local function refreshScoreLabel()
	local names = {}
	for name in scores do
		table.insert(names, name)
	end
	table.sort(names) -- einfache stabile Reihenfolge; bei Bedarf hart auf Team-Reihenfolge umstellen

	if #names >= 2 then
		scoreLabel.Text = string.format("%s %d  —  %d %s", names[1], scores[names[1]], scores[names[2]], names[2])
	elseif #names == 1 then
		scoreLabel.Text = string.format("%s %d", names[1], scores[names[1]])
	end
end

scoreEvent.OnClientEvent:Connect(function(teamName: string, newScore: number)
	scores[teamName] = newScore
	refreshScoreLabel()
end)

carryStatusEvent.OnClientEvent:Connect(function(isCarrying: boolean)
	carryBanner.Visible = isCarrying
end)

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", mins, secs)
end

local PHASE_LABELS = {
	Warmup = "Aufwärmphase",
	InProgress = "Laufende Runde",
	PostMatch = "Rundenende",
}

matchStateEvent.OnClientEvent:Connect(function(phase: string, timeRemaining: number, winnerName: string?)
	phaseLabel.Text = string.format("%s · %s", PHASE_LABELS[phase] or phase, formatTime(timeRemaining))

	if phase == "PostMatch" and winnerName then
		winnerOverlay.Text = winnerName == "Unentschieden" and "UNENTSCHIEDEN" or (winnerName .. " GEWINNT")
		winnerOverlay.Visible = true
	else
		winnerOverlay.Visible = false
	end
end)

PlayerHudState.JetpackEnergyChanged:Connect(function(energy: number)
	local ratio = math.clamp(energy / 100, 0, 1)
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
