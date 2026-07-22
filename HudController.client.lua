-- HudController.client.lua
-- Ablageort: StarterPlayerScripts
--
-- Baut das komplette HUD zur Laufzeit per Script.
-- + Crosshair für präzises Zielen

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")

local PlayerHudState = require(ReplicatedStorage.Modules.PlayerHudState)
local SpawnConstants = require(ReplicatedStorage.Modules.SpawnConstants)
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
screenGui.DisplayOrder = 10
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Personal cockpit palette. Blue players see frozen revenant telemetry; red
-- players see the hotter organic Ember interface.
local hudAccent = Color3.fromRGB(52, 222, 255)
local hudBright = Color3.fromRGB(211, 249, 255)
local hudPanel = Color3.fromRGB(4, 15, 24)
local hudMuted = Color3.fromRGB(69, 112, 130)
local hudFaction = "CRYO REVENANT"
local themeCallbacks: { () -> () } = {}

local function registerTheme(callback: () -> ())
	table.insert(themeCallbacks, callback)
	callback()
end

local function refreshFactionPalette()
	local ember = player.Team ~= nil and player.Team.TeamColor.Color.R > player.Team.TeamColor.Color.B
	if ember then
		hudAccent = Color3.fromRGB(255, 76, 28)
		hudBright = Color3.fromRGB(255, 225, 208)
		hudPanel = Color3.fromRGB(22, 5, 8)
		hudMuted = Color3.fromRGB(136, 61, 48)
		hudFaction = "EMBER BROOD"
	else
		hudAccent = Color3.fromRGB(52, 222, 255)
		hudBright = Color3.fromRGB(211, 249, 255)
		hudPanel = Color3.fromRGB(4, 15, 24)
		hudMuted = Color3.fromRGB(69, 112, 130)
		hudFaction = "CRYO REVENANT"
	end
	for _, callback in themeCallbacks do callback() end
end

local function addTitanShell(target: GuiObject, transparency: number?)
	target.BorderSizePixel = 0
	target.BackgroundTransparency = transparency or 0.16
	local corner = target:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = target
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TitanStroke"
	stroke.Thickness = 1
	stroke.Transparency = 0.38
	stroke.Parent = target
	local gradient = Instance.new("UIGradient")
	gradient.Name = "TitanGradient"
	gradient.Rotation = 90
	gradient.Parent = target
	local rail = Instance.new("Frame")
	rail.Name = "TitanRail"
	rail.Size = UDim2.new(1, -12, 0, 2)
	rail.Position = UDim2.fromOffset(6, 0)
	rail.BorderSizePixel = 0
	rail.ZIndex = target.ZIndex + 1
	rail.Parent = target
	local node = Instance.new("Frame")
	node.Name = "TitanNode"
	node.Size = UDim2.fromOffset(7, 7)
	node.AnchorPoint = Vector2.new(1, 0)
	node.Position = UDim2.new(1, -5, 0, 5)
	node.Rotation = 45
	node.BorderSizePixel = 0
	node.ZIndex = target.ZIndex + 2
	node.Parent = target
	registerTheme(function()
		target.BackgroundColor3 = hudPanel
		stroke.Color = hudAccent
		rail.BackgroundColor3 = hudAccent
		node.BackgroundColor3 = hudAccent
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, hudPanel:Lerp(hudAccent, 0.12)),
			ColorSequenceKeypoint.new(0.52, hudPanel),
			ColorSequenceKeypoint.new(1, hudPanel:Lerp(Color3.new(0, 0, 0), 0.22)),
		})
	end)
end

-- === CROSSHAIR ===

local crosshairFrame = Instance.new("Frame")
crosshairFrame.Name = "Crosshair"
crosshairFrame.Size = UDim2.fromOffset(28, 28)
crosshairFrame.AnchorPoint = Vector2.new(0.5, 0.5)
crosshairFrame.Position = UDim2.fromScale(0.5, 0.5)
crosshairFrame.BackgroundTransparency = 1
crosshairFrame.Parent = screenGui

local crosshairScale = Instance.new("UIScale")
crosshairScale.Scale = 1
crosshairScale.Parent = crosshairFrame

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
centerDot.Size = UDim2.fromOffset(6, 6)
centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
centerDot.Position = UDim2.fromScale(0.5, 0.5)
centerDot.BackgroundTransparency = 1
centerDot.BorderSizePixel = 0
centerDot.Parent = crosshairFrame

local centerCorner = Instance.new("UICorner")
centerCorner.CornerRadius = UDim.new(0, 1)
centerCorner.Parent = centerDot
local centerStroke = Instance.new("UIStroke")
centerStroke.Thickness = 1.5
centerStroke.Transparency = 0.05
centerStroke.Parent = centerDot
centerDot.Rotation = 45
registerTheme(function() centerStroke.Color = hudAccent end)

for index, data in {
	{ UDim2.fromOffset(3, 13), UDim2.new(0.5, -1, 0, 0) },
	{ UDim2.fromOffset(3, 13), UDim2.new(0.5, -1, 1, -13) },
	{ UDim2.fromOffset(13, 3), UDim2.new(0, 0, 0.5, -1) },
	{ UDim2.fromOffset(13, 3), UDim2.new(1, -13, 0.5, -1) },
} do
	local tick = Instance.new("Frame")
	tick.Name = "AimTick" .. index
	tick.Size = data[1]
	tick.Position = data[2]
	tick.BorderSizePixel = 0
	tick.BackgroundTransparency = 0.18
	tick.Parent = crosshairFrame
	registerTheme(function() tick.BackgroundColor3 = hudBright end)
end

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

local damageVignette = Instance.new("Frame")
damageVignette.Name = "DamageVignette"
damageVignette.Size = UDim2.fromScale(1, 1)
damageVignette.BackgroundColor3 = Color3.fromRGB(185, 18, 22)
damageVignette.BackgroundTransparency = 1
damageVignette.BorderSizePixel = 0
damageVignette.ZIndex = 0
damageVignette.Parent = screenGui

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
addTitanShell(cooldownFrame, 0.22)

local heatFrame = Instance.new("Frame")
heatFrame.Name = "AutomaticHeat"
heatFrame.Size = UDim2.fromOffset(138, 20)
heatFrame.AnchorPoint = Vector2.new(0.5, 0)
heatFrame.Position = UDim2.new(0.5, 0, 0.5, 56)
heatFrame.BackgroundColor3 = Color3.fromRGB(8, 13, 20)
heatFrame.BackgroundTransparency = 0.2
heatFrame.BorderSizePixel = 0
heatFrame.Visible = false
heatFrame.Parent = screenGui
local heatCorner = Instance.new("UICorner")
heatCorner.CornerRadius = UDim.new(0, 5)
heatCorner.Parent = heatFrame

local heatTrack = Instance.new("Frame")
heatTrack.Size = UDim2.new(1, -8, 0, 5)
heatTrack.Position = UDim2.fromOffset(4, 12)
heatTrack.BackgroundColor3 = Color3.fromRGB(34, 43, 54)
heatTrack.BorderSizePixel = 0
heatTrack.ClipsDescendants = true
heatTrack.Parent = heatFrame
local heatTrackCorner = Instance.new("UICorner")
heatTrackCorner.CornerRadius = UDim.new(1, 0)
heatTrackCorner.Parent = heatTrack

local heatFill = Instance.new("Frame")
heatFill.Size = UDim2.fromScale(0, 1)
heatFill.BackgroundColor3 = Color3.fromRGB(95, 205, 255)
heatFill.BorderSizePixel = 0
heatFill.Parent = heatTrack
local heatFillCorner = Instance.new("UICorner")
heatFillCorner.CornerRadius = UDim.new(1, 0)
heatFillCorner.Parent = heatFill

local heatLabel = Instance.new("TextLabel")
heatLabel.Size = UDim2.new(1, -8, 0, 11)
heatLabel.Position = UDim2.fromOffset(4, 1)
heatLabel.BackgroundTransparency = 1
heatLabel.Font = Enum.Font.GothamBold
heatLabel.Text = "HEAT  000%"
heatLabel.TextColor3 = Color3.fromRGB(145, 220, 255)
heatLabel.TextSize = 9
heatLabel.Parent = heatFrame
addTitanShell(heatFrame, 0.22)

local speedFrame = Instance.new("Frame")
speedFrame.Name = "SpeedReadout"
speedFrame.Size = UDim2.fromOffset(150, 34)
speedFrame.AnchorPoint = Vector2.new(0.5, 1)
speedFrame.Position = UDim2.new(0.5, 0, 1, -80)
speedFrame.BackgroundColor3 = Color3.fromRGB(8, 13, 20)
speedFrame.BackgroundTransparency = 0.28
speedFrame.BorderSizePixel = 0
speedFrame.Parent = screenGui

local speedCorner = Instance.new("UICorner")
speedCorner.CornerRadius = UDim.new(0, 6)
speedCorner.Parent = speedFrame

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.fromScale(1, 1)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.GothamBlack
speedLabel.Text = "SPEED  000"
speedLabel.TextColor3 = Color3.fromRGB(145, 225, 255)
speedLabel.TextSize = 15
speedLabel.Parent = speedFrame
addTitanShell(speedFrame, 0.20)

RunService.RenderStepped:Connect(function()
	local selected = WeaponState.Get()
	local startedAt, duration = WeaponFeedback.GetCooldown(selected)
	local elapsed = os.clock() - startedAt
	local ratio = if duration <= 0 then 1 else math.clamp(elapsed / duration, 0, 1)
	local ready = ratio >= 1
	local kit = ClassKitConstants.Get(player:GetAttribute("Loadout"))
	local weaponName = if selected == "Spinfusor" then kit.disc.name else kit.automatic.name

	cooldownFrame.Visible = player:GetAttribute("LoadoutMenuOpen") ~= true
	cooldownFill.Size = UDim2.fromScale(ratio, 1)
	cooldownFill.BackgroundColor3 = if ready
		then hudAccent
		else Color3.fromRGB(255, 174, 68)
	cooldownLabel.TextColor3 = if ready
		then hudBright
		else Color3.fromRGB(255, 208, 125)
	cooldownLabel.Text = if ready
		then string.upper(weaponName) .. " // READY"
		else string.format("RECHARGE // %.1fs", math.max(0, duration - elapsed))

	local heat, lockedUntil = WeaponState.GetAutomaticHeat()
	local overheated = lockedUntil > os.clock()
	local heatRatio = math.clamp(heat / 100, 0, 1)
	heatFrame.Visible = selected == "Chaingun" and player:GetAttribute("LoadoutMenuOpen") ~= true
	heatFill.Size = UDim2.fromScale(heatRatio, 1)
	heatFill.BackgroundColor3 = Color3.fromRGB(75, 200, 255):Lerp(Color3.fromRGB(255, 72, 45), heatRatio)
	heatLabel.Text = if overheated then "OVERHEAT" else string.format("HEAT  %03d%%", math.floor(heat + 0.5))
	heatLabel.TextColor3 = if overheated then Color3.fromRGB(255, 105, 75) else heatFill.BackgroundColor3

	local crosshairColor = if ready
		then hudBright
		else Color3.fromRGB(255, 170, 70)
	hBar.BackgroundColor3 = crosshairColor
	vBar.BackgroundColor3 = crosshairColor
	centerStroke.Color = if ready then hudAccent else Color3.fromRGB(255, 120, 65)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local speed = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity.Magnitude else 0
	local speedRatio = math.clamp((speed - 30) / 150, 0, 1)
	speedLabel.Text = string.format("VELOCITY // %03d", math.floor(speed + 0.5))
	speedLabel.TextColor3 = hudAccent:Lerp(Color3.fromRGB(255, 178, 72), speedRatio)
	speedFrame.BackgroundTransparency = 0.35 - speedRatio * 0.16
end)

-- === Health / Jetpack Bars ===

local function makeBar(name: string, anchorPoint: Vector2, position: UDim2, fillColor: Color3): (Frame, TextLabel)
	local container = Instance.new("Frame")
	container.Name = name .. "Telemetry"
	container.Size = UDim2.fromOffset(270, 62)
	container.AnchorPoint = anchorPoint
	container.Position = position
	container.Parent = screenGui
	addTitanShell(container, 0.13)

	local system = Instance.new("TextLabel")
	system.Size = UDim2.new(1, -18, 0, 13)
	system.Position = UDim2.fromOffset(9, 5)
	system.BackgroundTransparency = 1
	system.Font = Enum.Font.RobotoMono
	system.Text = hudFaction .. " // " .. name
	system.TextSize = 9
	system.TextXAlignment = Enum.TextXAlignment.Left
	system.Parent = container
	registerTheme(function()
		system.Text = hudFaction .. " // " .. name
		system.TextColor3 = hudMuted:Lerp(hudBright, 0.35)
	end)

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -18, 0, 13)
	track.Position = UDim2.fromOffset(9, 40)
	track.BackgroundColor3 = Color3.fromRGB(23, 31, 39)
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = container

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new(fillColor:Lerp(Color3.new(1, 1, 1), 0.32), fillColor)
	fillGradient.Parent = fill
	if name == "THRUST" then
		registerTheme(function()
			fill.BackgroundColor3 = hudAccent
			fillGradient.Color = ColorSequence.new(hudBright, hudAccent)
		end)
	end

	for index = 1, 11 do
		local divider = Instance.new("Frame")
		divider.Name = "Segment" .. index
		divider.Size = UDim2.fromOffset(1, 13)
		divider.Position = UDim2.new(index / 12, 0, 0, 0)
		divider.BackgroundColor3 = hudPanel
		divider.BackgroundTransparency = 0.18
		divider.BorderSizePixel = 0
		divider.ZIndex = track.ZIndex + 3
		divider.Parent = track
		registerTheme(function() divider.BackgroundColor3 = hudPanel end)
	end

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -18, 0, 20)
	label.Position = UDim2.fromOffset(9, 18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(235, 242, 248)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	return fill, label
end

local healthFill, healthLabel = makeBar("VITALS", Vector2.new(0, 1), UDim2.new(0, 24, 1, -24), Color3.fromRGB(234, 67, 62))
healthLabel.Text = "VITAL INTEGRITY // 100"

local jetpackFill, jetpackLabel = makeBar("THRUST", Vector2.new(1, 1), UDim2.new(1, -24, 1, -24), hudAccent)
jetpackLabel.Text = "THRUST RESERVE // 100"
registerTheme(function()
	healthLabel.TextColor3 = hudBright
	jetpackLabel.TextColor3 = hudBright
end)

local equipmentLabel = Instance.new("TextLabel")
equipmentLabel.Name = "CombatDock"
equipmentLabel.Size = UDim2.fromOffset(660, 52)
equipmentLabel.AnchorPoint = Vector2.new(0.5, 1)
equipmentLabel.Position = UDim2.new(0.5, 0, 1, -18)
equipmentLabel.Font = Enum.Font.RobotoMono
equipmentLabel.TextSize = 11
equipmentLabel.TextWrapped = true
equipmentLabel.TextColor3 = Color3.fromRGB(225, 235, 243)
equipmentLabel.Parent = screenGui
addTitanShell(equipmentLabel, 0.14)
registerTheme(function() equipmentLabel.TextColor3 = hudBright:Lerp(Color3.fromRGB(225, 235, 243), 0.35) end)

local isCarryingFlag = false
local function refreshEquipment()
	local grenades = player:GetAttribute("Grenades")
	local kit = ClassKitConstants.Get(player:GetAttribute("Loadout"))
	local grenadeName = string.upper(kit.grenade.name)
	local selected = WeaponState.Get()
	local discMark = if selected == "Spinfusor" then "◆" else "◇"
	local automaticMark = if selected == "Chaingun" then "◆" else "◇"
	equipmentLabel.Text = string.format(
		"%s [1] %s    //    %s [2] %s\n[G] %s ×%d    [F] MELEE    [V] PING%s",
		discMark,
		string.upper(kit.disc.name),
		automaticMark,
		string.upper(kit.automatic.name),
		grenadeName,
		typeof(grenades) == "number" and grenades or 0,
		if isCarryingFlag then "    [Z] FLAG PUNT" else ""
	)
end

player:GetAttributeChangedSignal("Grenades"):Connect(refreshEquipment)
player:GetAttributeChangedSignal("Loadout"):Connect(refreshEquipment)
WeaponState.Changed:Connect(refreshEquipment)
refreshEquipment()

-- === Score ===

local scoreFrame = Instance.new("Frame")
scoreFrame.Name = "TitanScoreCore"
scoreFrame.Size = UDim2.fromOffset(354, 82)
scoreFrame.AnchorPoint = Vector2.new(0.5, 0)
scoreFrame.Position = UDim2.new(0.5, 0, 0, 14)
scoreFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
scoreFrame.BackgroundTransparency = 0.25
scoreFrame.BorderSizePixel = 0
scoreFrame.Parent = screenGui

local scoreCorner = Instance.new("UICorner")
scoreCorner.CornerRadius = UDim.new(0, 3)
scoreCorner.Parent = scoreFrame
addTitanShell(scoreFrame, 0.10)

local modeLabel = Instance.new("TextLabel")
modeLabel.Size = UDim2.new(1, -20, 0, 13)
modeLabel.Position = UDim2.fromOffset(10, 5)
modeLabel.BackgroundTransparency = 1
modeLabel.Font = Enum.Font.RobotoMono
modeLabel.Text = "TITAN CORE // CAPTURE PROTOCOL"
modeLabel.TextColor3 = Color3.fromRGB(128, 151, 171)
modeLabel.TextSize = 9
modeLabel.Parent = scoreFrame

local blueTeamTag = Instance.new("TextLabel")
blueTeamTag.Size = UDim2.fromOffset(95, 20)
blueTeamTag.Position = UDim2.fromOffset(12, 27)
blueTeamTag.BackgroundTransparency = 1
blueTeamTag.Font = Enum.Font.GothamBlack
blueTeamTag.Text = "CRYO"
blueTeamTag.TextColor3 = Color3.fromRGB(65, 214, 255)
blueTeamTag.TextSize = 11
blueTeamTag.TextXAlignment = Enum.TextXAlignment.Left
blueTeamTag.Parent = scoreFrame

local redTeamTag = blueTeamTag:Clone()
redTeamTag.Position = UDim2.new(1, -107, 0, 27)
redTeamTag.Text = "EMBER"
redTeamTag.TextColor3 = Color3.fromRGB(255, 86, 43)
redTeamTag.TextXAlignment = Enum.TextXAlignment.Right
redTeamTag.Parent = scoreFrame

local scoreLabel = Instance.new("TextLabel")
scoreLabel.Size = UDim2.new(1, 0, 0, 38)
scoreLabel.Position = UDim2.fromOffset(0, 17)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Font = Enum.Font.GothamBlack
scoreLabel.TextSize = 24
scoreLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
scoreLabel.Text = "0  --  0"
scoreLabel.Parent = scoreFrame

local phaseLabel = Instance.new("TextLabel")
phaseLabel.Size = UDim2.new(1, -20, 0, 19)
phaseLabel.Position = UDim2.fromOffset(10, 58)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Font = Enum.Font.RobotoMono
phaseLabel.TextSize = 10
phaseLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
phaseLabel.Text = "Aufwaermphase"
phaseLabel.Parent = scoreFrame

local carryBanner = Instance.new("TextLabel")
carryBanner.Size = UDim2.fromOffset(320, 34)
carryBanner.AnchorPoint = Vector2.new(0.5, 0)
carryBanner.Position = UDim2.new(0.5, 0, 0, 104)
carryBanner.BackgroundColor3 = Color3.fromRGB(38, 29, 5)
carryBanner.BorderSizePixel = 0
carryBanner.Font = Enum.Font.GothamBold
carryBanner.TextSize = 16
carryBanner.TextColor3 = Color3.fromRGB(255, 218, 81)
carryBanner.Text = "FLAG CORE ACQUIRED // [Z] PUNT"
carryBanner.Visible = false
carryBanner.Parent = screenGui

local carryCorner = Instance.new("UICorner")
carryCorner.CornerRadius = UDim.new(0, 8)
carryCorner.Parent = carryBanner
local carryStroke = Instance.new("UIStroke")
carryStroke.Color = Color3.fromRGB(255, 205, 62)
carryStroke.Thickness = 1
carryStroke.Transparency = 0.2
carryStroke.Parent = carryBanner

local winnerOverlay = Instance.new("TextLabel")
winnerOverlay.Size = UDim2.fromOffset(620, 112)
winnerOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
winnerOverlay.Position = UDim2.new(0.5, 0, 0.4, 0)
winnerOverlay.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
winnerOverlay.BackgroundTransparency = 0.15
winnerOverlay.BorderSizePixel = 0
winnerOverlay.Font = Enum.Font.GothamBold
winnerOverlay.TextSize = 27
winnerOverlay.TextWrapped = true
winnerOverlay.TextColor3 = Color3.fromRGB(245, 245, 250)
winnerOverlay.Text = ""
winnerOverlay.Visible = false
winnerOverlay.Parent = screenGui

local winnerCorner = Instance.new("UICorner")
winnerCorner.CornerRadius = UDim.new(0, 12)
winnerCorner.Parent = winnerOverlay

local roundIntro = Instance.new("CanvasGroup")
roundIntro.Name = "RoundIntro"
roundIntro.Size = UDim2.fromOffset(720, 132)
roundIntro.AnchorPoint = Vector2.new(0.5, 0.5)
roundIntro.Position = UDim2.fromScale(0.5, 0.43)
roundIntro.BackgroundColor3 = Color3.fromRGB(4, 10, 18)
roundIntro.BackgroundTransparency = 0.12
roundIntro.BorderSizePixel = 0
roundIntro.GroupTransparency = 1
roundIntro.Visible = false
roundIntro.ZIndex = 20
roundIntro.Parent = screenGui
local roundIntroCorner = Instance.new("UICorner")
roundIntroCorner.CornerRadius = UDim.new(0, 12)
roundIntroCorner.Parent = roundIntro
local roundIntroStroke = Instance.new("UIStroke")
roundIntroStroke.Color = Color3.fromRGB(92, 222, 255)
roundIntroStroke.Thickness = 2
roundIntroStroke.Transparency = 0.18
roundIntroStroke.Parent = roundIntro
local roundIntroTitle = Instance.new("TextLabel")
roundIntroTitle.Size = UDim2.new(1, -36, 0, 74)
roundIntroTitle.Position = UDim2.fromOffset(18, 10)
roundIntroTitle.BackgroundTransparency = 1
roundIntroTitle.Font = Enum.Font.GothamBlack
roundIntroTitle.Text = "BATTLE ON TITAN"
roundIntroTitle.TextColor3 = Color3.fromRGB(235, 247, 255)
roundIntroTitle.TextSize = 34
roundIntroTitle.ZIndex = 21
roundIntroTitle.Parent = roundIntro
local roundIntroSubtitle = Instance.new("TextLabel")
roundIntroSubtitle.Size = UDim2.new(1, -36, 0, 34)
roundIntroSubtitle.Position = UDim2.fromOffset(18, 78)
roundIntroSubtitle.BackgroundTransparency = 1
roundIntroSubtitle.Font = Enum.Font.GothamBold
roundIntroSubtitle.Text = "CAPTURE THE FLAG // CONTROL THE CORE"
roundIntroSubtitle.TextColor3 = Color3.fromRGB(106, 220, 255)
roundIntroSubtitle.TextSize = 14
roundIntroSubtitle.ZIndex = 21
roundIntroSubtitle.Parent = roundIntro
local roundIntroSequence = 0

local function showRoundIntro(title: string, subtitle: string, color: Color3)
	roundIntroSequence += 1
	local sequence = roundIntroSequence
	roundIntroTitle.Text = title
	roundIntroSubtitle.Text = subtitle
	roundIntroSubtitle.TextColor3 = color
	roundIntroStroke.Color = color
	roundIntro.Position = UDim2.fromScale(0.5, 0.45)
	roundIntro.GroupTransparency = 1
	roundIntro.Visible = true
	TweenService:Create(roundIntro, TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.43),
		GroupTransparency = 0,
	}):Play()
	task.delay(1.75, function()
		if sequence ~= roundIntroSequence or not roundIntro.Parent then return end
		local tween = TweenService:Create(roundIntro, TweenInfo.new(0.42, Enum.EasingStyle.Quad), {
			Position = UDim2.fromScale(0.5, 0.4),
			GroupTransparency = 1,
		})
		tween:Play()
		tween.Completed:Once(function()
			if sequence == roundIntroSequence then roundIntro.Visible = false end
		end)
	end)
end

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
	scoreLabel.Text = string.format("%02d    ◇    %02d", scores.Blue or 0, scores.Red or 0)
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
	isCarryingFlag = isCarrying
	carryBanner.Visible = isCarrying
	refreshEquipment()
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

local medalFrame = Instance.new("CanvasGroup")
medalFrame.Name = "CombatMedal"
medalFrame.Size = UDim2.fromOffset(300, 58)
medalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
medalFrame.Position = UDim2.fromScale(0.5, 0.66)
medalFrame.BackgroundColor3 = Color3.fromRGB(8, 14, 22)
medalFrame.BackgroundTransparency = 0.12
medalFrame.BorderSizePixel = 0
medalFrame.GroupTransparency = 1
medalFrame.Parent = screenGui

local medalCorner = Instance.new("UICorner")
medalCorner.CornerRadius = UDim.new(0, 9)
medalCorner.Parent = medalFrame
local medalStroke = Instance.new("UIStroke")
medalStroke.Color = Color3.fromRGB(92, 224, 255)
medalStroke.Thickness = 2
medalStroke.Transparency = 0.18
medalStroke.Parent = medalFrame
local medalScale = Instance.new("UIScale")
medalScale.Parent = medalFrame

local medalTitle = Instance.new("TextLabel")
medalTitle.Size = UDim2.new(1, -20, 0, 34)
medalTitle.Position = UDim2.fromOffset(10, 3)
medalTitle.BackgroundTransparency = 1
medalTitle.Font = Enum.Font.GothamBlack
medalTitle.Text = "BLUE PLATE SPECIAL"
medalTitle.TextColor3 = Color3.fromRGB(127, 231, 255)
medalTitle.TextSize = 19
medalTitle.TextStrokeColor3 = Color3.fromRGB(3, 7, 12)
medalTitle.TextStrokeTransparency = 0.3
medalTitle.Parent = medalFrame

local medalSubtitle = Instance.new("TextLabel")
medalSubtitle.Size = UDim2.new(1, -20, 0, 16)
medalSubtitle.Position = UDim2.fromOffset(10, 36)
medalSubtitle.BackgroundTransparency = 1
medalSubtitle.Font = Enum.Font.GothamBold
medalSubtitle.Text = "COMBAT AWARD"
medalSubtitle.TextColor3 = Color3.fromRGB(164, 178, 194)
medalSubtitle.TextSize = 10
medalSubtitle.Parent = medalFrame

local medalSequence = 0
local function showCombatMedal(award: string)
	medalSequence += 1
	local sequence = medalSequence
	local isBluePlate = award == "BLUE PLATE SPECIAL"
	local color = if isBluePlate then Color3.fromRGB(92, 224, 255) else Color3.fromRGB(255, 205, 78)
	medalTitle.Text = award
	medalTitle.TextColor3 = color
	medalStroke.Color = color
	medalSubtitle.Text = if isBluePlate then "MID-AIR DIRECT HIT" else "COMBAT AWARD"
	medalFrame.GroupTransparency = 0
	medalScale.Scale = 0.72
	TweenService:Create(medalScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 0.5
	sound.PlaybackSpeed = if isBluePlate then 1.55 else 1.35
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 2)

	task.delay(1.45, function()
		if sequence == medalSequence then
			TweenService:Create(medalFrame, TweenInfo.new(0.45), { GroupTransparency = 1 }):Play()
		end
	end)
end

local function showDamageDirection(sourcePosition: any)
	if typeof(sourcePosition) ~= "Vector3" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not root:IsA("BasePart") or not camera then
		return
	end
	local offset = sourcePosition - root.Position
	if offset.Magnitude < 0.1 then
		return
	end
	local localDirection = camera.CFrame:VectorToObjectSpace(offset.Unit)
	local angle = math.atan2(localDirection.X, -localDirection.Z)
	local radius = 126
	local arrow = Instance.new("TextLabel")
	arrow.Name = "DamageDirection"
	arrow.Size = UDim2.fromOffset(34, 34)
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.new(0.5, math.sin(angle) * radius, 0.5, -math.cos(angle) * radius)
	arrow.BackgroundColor3 = Color3.fromRGB(98, 8, 12)
	arrow.BackgroundTransparency = 0.18
	arrow.BorderSizePixel = 0
	arrow.Font = Enum.Font.GothamBlack
	arrow.Text = "^"
	arrow.TextColor3 = Color3.fromRGB(255, 82, 77)
	arrow.TextSize = 24
	arrow.TextStrokeTransparency = 0.25
	arrow.Rotation = math.deg(angle) + 180
	arrow.Parent = screenGui
	local arrowCorner = Instance.new("UICorner")
	arrowCorner.CornerRadius = UDim.new(1, 0)
	arrowCorner.Parent = arrow
	TweenService:Create(arrow, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, math.sin(angle) * 104, 0.5, -math.cos(angle) * 104),
		BackgroundTransparency = 1,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(arrow, 0.75)
end

local function showScorePopup(points: number, reason: string?)
	local popup = Instance.new("TextLabel")
	popup.Name = "ScorePopup"
	popup.Size = UDim2.fromOffset(310, 30)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.fromScale(0.5, 0.57)
	popup.BackgroundTransparency = 1
	popup.Font = Enum.Font.GothamBlack
	popup.Text = string.format("%s  +%d", typeof(reason) == "string" and reason or "TEAMPLAY", points)
	popup.TextColor3 = Color3.fromRGB(112, 244, 185)
	popup.TextSize = 15
	popup.TextStrokeColor3 = Color3.fromRGB(3, 8, 9)
	popup.TextStrokeTransparency = 0.28
	popup.Parent = screenGui
	TweenService:Create(popup, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.525),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(popup, 0.95)
end

local hitMarkerSequence = 0
damageFeedbackEvent.OnClientEvent:Connect(function(
	damage: number,
	killed: boolean,
	feedbackType: string?,
	sourcePosition: Vector3?,
	award: string?
)
	if feedbackType == "Taken" then
		showDamageDirection(sourcePosition)
		return
	elseif feedbackType == "Award" then
		if typeof(award) == "string" then
			showCombatMedal(award)
		end
		return
	elseif feedbackType == "Score" then
		showScorePopup(damage, award)
		return
	end
	if typeof(award) == "string" then
		showCombatMedal(award)
	end
	hitMarkerSequence += 1
	local sequence = hitMarkerSequence
	crosshairScale.Scale = killed and 1.65 or 1.38
	TweenService:Create(crosshairScale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local confirmSound = Instance.new("Sound")
	confirmSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	confirmSound.Volume = killed and 0.34 or 0.2
	confirmSound.PlaybackSpeed = killed and 1.55 or 1.28
	confirmSound.Parent = SoundService
	confirmSound:Play()
	Debris:AddItem(confirmSound, 2)
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
	Overtime = "OVERTIME // NAECHSTER CAP GEWINNT",
	PostMatch = "Rundenende",
}

local lastPresentedPhase: string? = nil

local function applyMatchState(phase: string, timeRemaining: number, winnerName: string?)
	if phase ~= lastPresentedPhase then
		lastPresentedPhase = phase
		if phase == "InProgress" then
			showRoundIntro("BATTLE ON TITAN", "CAPTURE THE FLAG // CONTROL THE CORE", Color3.fromRGB(92, 222, 255))
		elseif phase == "Overtime" then
			showRoundIntro("OVERTIME", "NEXT CAPTURE WINS", Color3.fromRGB(255, 184, 70))
		end
	end
	phaseLabel.Text = string.format("%s - %s", PHASE_LABELS[phase] or phase, formatTime(timeRemaining))
	phaseLabel.TextColor3 = if phase == "Overtime"
		then Color3.fromRGB(255, 190, 70)
		else Color3.fromRGB(190, 190, 200)

	if phase == "PostMatch" and winnerName then
		local mvp = ReplicatedStorage:GetAttribute("MatchMVP")
		local mvpScore = ReplicatedStorage:GetAttribute("MatchMVPScore")
		local result = winnerName == "Unentschieden" and "UNENTSCHIEDEN" or (string.upper(winnerName) .. " GEWINNT")
		winnerOverlay.Text = if typeof(mvp) == "string"
			then string.format("%s\nMVP // %s // %d PTS", result, string.upper(mvp), typeof(mvpScore) == "number" and mvpScore or 0)
			else result
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
ReplicatedStorage:GetAttributeChangedSignal("MatchMVP"):Connect(syncMatchState)
ReplicatedStorage:GetAttributeChangedSignal("MatchMVPScore"):Connect(syncMatchState)
syncMatchState()

PlayerHudState.JetpackEnergyChanged:Connect(function(energy: number)
	local maxEnergy = player:GetAttribute("MaxEnergy")
	local ratio = math.clamp(energy / (typeof(maxEnergy) == "number" and maxEnergy or 100), 0, 1)
	jetpackFill.Size = UDim2.new(ratio, 0, 1, 0)
	jetpackLabel.Text = string.format("THRUST RESERVE // %03d", math.floor(ratio * 100 + 0.5))
	jetpackLabel.TextColor3 = if ratio <= 0.18 then Color3.fromRGB(255, 104, 58) else hudBright
end)

local function bindHealth(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local lastHealth = humanoid.Health

	local function updateHealth()
		if humanoid.Health < lastHealth then
			local severity = math.clamp((lastHealth - humanoid.Health) / math.max(1, humanoid.MaxHealth), 0, 0.65)
			damageVignette.BackgroundTransparency = 0.9 - severity * 0.32
			TweenService:Create(damageVignette, TweenInfo.new(0.42), { BackgroundTransparency = 1 }):Play()
		end
		lastHealth = humanoid.Health
		local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		TweenService:Create(healthFill, TweenInfo.new(0.15), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
		healthLabel.Text = string.format("VITAL INTEGRITY // %03d", math.floor(ratio * 100 + 0.5))
		healthLabel.TextColor3 = if ratio <= 0.25 then Color3.fromRGB(255, 88, 58) else hudBright
	end

	humanoid.HealthChanged:Connect(updateHealth)
	updateHealth()
end

if player.Character then
	bindHealth(player.Character)
end
player.CharacterAdded:Connect(bindHealth)

-- === TITAN NAVIGATION ===
-- Die XL-Arena braucht Orientierung ohne eine grosse Minimap, die den Blick
-- verdeckt: laufender Kompass, aktueller Kampfsektor und Kartenrand-Countdown.

local function navRound(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local navCompass = Instance.new("Frame")
navCompass.Name = "TitanCompass"
navCompass.Size = UDim2.fromOffset(370, 42)
navCompass.AnchorPoint = Vector2.new(0.5, 0)
navCompass.Position = UDim2.new(0.5, 0, 0, 140)
navCompass.BackgroundColor3 = Color3.fromRGB(7, 12, 19)
navCompass.BackgroundTransparency = 0.18
navCompass.BorderSizePixel = 0
navCompass.ClipsDescendants = true
navCompass.Parent = screenGui
navRound(navCompass, 7)

local navCompassStroke = Instance.new("UIStroke")
navCompassStroke.Color = Color3.fromRGB(86, 112, 142)
navCompassStroke.Transparency = 0.55
navCompassStroke.Thickness = 1
navCompassStroke.Parent = navCompass
local navGradient = Instance.new("UIGradient")
navGradient.Rotation = 90
navGradient.Parent = navCompass

local navHeading = Instance.new("TextLabel")
navHeading.Name = "Heading"
navHeading.Size = UDim2.fromOffset(64, 14)
navHeading.AnchorPoint = Vector2.new(0.5, 0)
navHeading.Position = UDim2.new(0.5, 0, 0, 2)
navHeading.BackgroundTransparency = 1
navHeading.Font = Enum.Font.GothamBold
navHeading.TextColor3 = Color3.fromRGB(126, 222, 255)
navHeading.TextSize = 10
navHeading.Text = "000 DEG"
navHeading.ZIndex = 3
navHeading.Parent = navCompass

local navTickLayer = Instance.new("Frame")
navTickLayer.Name = "Ticks"
navTickLayer.Size = UDim2.new(1, -20, 0, 24)
navTickLayer.Position = UDim2.fromOffset(10, 15)
navTickLayer.BackgroundTransparency = 1
navTickLayer.ClipsDescendants = true
navTickLayer.Parent = navCompass

local navCardinals = {
	{ name = "N", angle = 0 },
	{ name = "NE", angle = 45 },
	{ name = "E", angle = 90 },
	{ name = "SE", angle = 135 },
	{ name = "S", angle = 180 },
	{ name = "SW", angle = 225 },
	{ name = "W", angle = 270 },
	{ name = "NW", angle = 315 },
}

local navTickLabels: { TextLabel } = {}
for _, cardinal in navCardinals do
	local label = Instance.new("TextLabel")
	label.Name = cardinal.name
	label.Size = UDim2.fromOffset(34, 22)
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.BackgroundTransparency = 1
	label.Font = if #cardinal.name == 1 then Enum.Font.GothamBlack else Enum.Font.GothamBold
	label.Text = cardinal.name
	label.TextColor3 = if #cardinal.name == 1
		then Color3.fromRGB(240, 246, 255)
		else Color3.fromRGB(150, 166, 184)
	label.TextSize = if #cardinal.name == 1 then 15 else 11
	label:SetAttribute("Angle", cardinal.angle)
	label.Parent = navTickLayer
	table.insert(navTickLabels, label)
end

local navPointer = Instance.new("TextLabel")
navPointer.Name = "Pointer"
navPointer.Size = UDim2.fromOffset(20, 12)
navPointer.AnchorPoint = Vector2.new(0.5, 0)
navPointer.Position = UDim2.new(0.5, 0, 0, 31)
navPointer.BackgroundTransparency = 1
navPointer.Font = Enum.Font.GothamBlack
navPointer.Text = "^"
navPointer.TextColor3 = Color3.fromRGB(89, 221, 255)
navPointer.TextSize = 11
navPointer.ZIndex = 4
navPointer.Parent = navCompass
registerTheme(function()
	navCompass.BackgroundColor3 = hudPanel
	navHeading.TextColor3 = hudAccent
	navPointer.TextColor3 = hudAccent
	navGradient.Color = ColorSequence.new(hudPanel:Lerp(hudAccent, 0.12), hudPanel)
end)

local navZoneFrame = Instance.new("Frame")
navZoneFrame.Name = "TitanZone"
navZoneFrame.Size = UDim2.fromOffset(300, 25)
navZoneFrame.AnchorPoint = Vector2.new(0.5, 0)
navZoneFrame.Position = UDim2.new(0.5, 0, 0, 186)
navZoneFrame.BackgroundColor3 = Color3.fromRGB(7, 12, 19)
navZoneFrame.BackgroundTransparency = 0.23
navZoneFrame.BorderSizePixel = 0
navZoneFrame.Parent = screenGui
navRound(navZoneFrame, 6)

local navZoneAccent = Instance.new("Frame")
navZoneAccent.Name = "Accent"
navZoneAccent.Size = UDim2.fromOffset(4, 15)
navZoneAccent.Position = UDim2.fromOffset(7, 5)
navZoneAccent.BackgroundColor3 = Color3.fromRGB(105, 232, 255)
navZoneAccent.BorderSizePixel = 0
navZoneAccent.Parent = navZoneFrame
navRound(navZoneAccent, 2)

local navZoneLabel = Instance.new("TextLabel")
navZoneLabel.Name = "Name"
navZoneLabel.Size = UDim2.new(1, -28, 1, 0)
navZoneLabel.Position = UDim2.fromOffset(20, 0)
navZoneLabel.BackgroundTransparency = 1
navZoneLabel.Font = Enum.Font.GothamBold
navZoneLabel.Text = "TITAN // CORE ROUTE"
navZoneLabel.TextColor3 = Color3.fromRGB(222, 232, 243)
navZoneLabel.TextSize = 11
navZoneLabel.TextXAlignment = Enum.TextXAlignment.Left
navZoneLabel.Parent = navZoneFrame

local spawnShieldFrame = Instance.new("Frame")
spawnShieldFrame.Name = "SpawnShield"
spawnShieldFrame.Size = UDim2.fromOffset(360, 22)
spawnShieldFrame.AnchorPoint = Vector2.new(0.5, 0)
spawnShieldFrame.Position = UDim2.new(0.5, 0, 0, 216)
spawnShieldFrame.BackgroundColor3 = Color3.fromRGB(10, 34, 50)
spawnShieldFrame.BackgroundTransparency = 0.14
spawnShieldFrame.BorderSizePixel = 0
spawnShieldFrame.ClipsDescendants = true
spawnShieldFrame.Visible = false
spawnShieldFrame.Parent = screenGui
navRound(spawnShieldFrame, 6)

local spawnShieldFill = Instance.new("Frame")
spawnShieldFill.Name = "Fill"
spawnShieldFill.Size = UDim2.fromScale(1, 1)
spawnShieldFill.BackgroundColor3 = Color3.fromRGB(72, 196, 255)
spawnShieldFill.BackgroundTransparency = 0.72
spawnShieldFill.BorderSizePixel = 0
spawnShieldFill.Parent = spawnShieldFrame

local spawnShieldLabel = Instance.new("TextLabel")
spawnShieldLabel.Size = UDim2.fromScale(1, 1)
spawnShieldLabel.BackgroundTransparency = 1
spawnShieldLabel.Font = Enum.Font.GothamBlack
spawnShieldLabel.Text = "SPAWN-SCHILD // 3.0s"
spawnShieldLabel.TextColor3 = Color3.fromRGB(188, 235, 255)
spawnShieldLabel.TextSize = 11
spawnShieldLabel.Parent = spawnShieldFrame

local navDiscovery = Instance.new("TextLabel")
navDiscovery.Name = "ZoneDiscovery"
navDiscovery.Size = UDim2.fromOffset(500, 42)
navDiscovery.AnchorPoint = Vector2.new(0.5, 0.5)
navDiscovery.Position = UDim2.fromScale(0.5, 0.29)
navDiscovery.BackgroundTransparency = 1
navDiscovery.Font = Enum.Font.GothamBlack
navDiscovery.Text = ""
navDiscovery.TextColor3 = Color3.fromRGB(232, 243, 255)
navDiscovery.TextSize = 22
navDiscovery.TextStrokeColor3 = Color3.fromRGB(4, 8, 13)
navDiscovery.TextStrokeTransparency = 0.22
navDiscovery.TextTransparency = 1
navDiscovery.Parent = screenGui

local boundaryWarning = Instance.new("Frame")
boundaryWarning.Name = "BoundaryWarning"
boundaryWarning.Size = UDim2.fromOffset(430, 72)
boundaryWarning.AnchorPoint = Vector2.new(0.5, 0.5)
boundaryWarning.Position = UDim2.fromScale(0.5, 0.37)
boundaryWarning.BackgroundColor3 = Color3.fromRGB(84, 10, 14)
boundaryWarning.BackgroundTransparency = 0.12
boundaryWarning.BorderSizePixel = 0
boundaryWarning.Visible = false
boundaryWarning.Parent = screenGui
navRound(boundaryWarning, 9)

local boundaryStroke = Instance.new("UIStroke")
boundaryStroke.Color = Color3.fromRGB(255, 74, 74)
boundaryStroke.Thickness = 2
boundaryStroke.Transparency = 0.12
boundaryStroke.Parent = boundaryWarning

local boundaryScale = Instance.new("UIScale")
boundaryScale.Parent = boundaryWarning

local boundaryTitle = Instance.new("TextLabel")
boundaryTitle.Size = UDim2.new(1, 0, 0, 39)
boundaryTitle.BackgroundTransparency = 1
boundaryTitle.Font = Enum.Font.GothamBlack
boundaryTitle.Text = "RETURN TO COMBAT AREA"
boundaryTitle.TextColor3 = Color3.fromRGB(255, 238, 238)
boundaryTitle.TextSize = 19
boundaryTitle.Parent = boundaryWarning

local boundaryTimer = Instance.new("TextLabel")
boundaryTimer.Size = UDim2.new(1, 0, 0, 24)
boundaryTimer.Position = UDim2.fromOffset(0, 38)
boundaryTimer.BackgroundTransparency = 1
boundaryTimer.Font = Enum.Font.GothamBold
boundaryTimer.Text = "6.0 SECONDS"
boundaryTimer.TextColor3 = Color3.fromRGB(255, 113, 113)
boundaryTimer.TextSize = 14
boundaryTimer.Parent = boundaryWarning

local NAV_RED = Color3.fromRGB(235, 79, 75)
local NAV_BLUE = Color3.fromRGB(77, 153, 255)
local NAV_NEUTRAL = Color3.fromRGB(105, 232, 255)
local lastNavigationZone = ""
local zoneDiscoveryTween: Tween? = nil

local function navigationDelta(angle: number, origin: number): number
	return (angle - origin + 180) % 360 - 180
end

local function navigationRoute(position: Vector3): string
	if position.Z < -335 then
		return "NORTH RIDGE"
	elseif position.Z < -155 then
		return "NORTH FLANK"
	elseif position.Z > 335 then
		return "SOUTH RIDGE"
	elseif position.Z > 155 then
		return "SOUTH FLANK"
	end
	return "CORE ROUTE"
end

local function navigationTerritory(position: Vector3): (string, Color3)
	if position.X < -620 then
		return "RED BACKFIELD", NAV_RED
	elseif position.X < -505 then
		return "RED BASE", NAV_RED
	elseif position.X < -170 then
		return "RED TERRITORY", NAV_RED
	elseif position.X > 620 then
		return "BLUE BACKFIELD", NAV_BLUE
	elseif position.X > 505 then
		return "BLUE BASE", NAV_BLUE
	elseif position.X > 170 then
		return "BLUE TERRITORY", NAV_BLUE
	end
	return "MIDFIELD", NAV_NEUTRAL
end

local function showZoneDiscovery(text: string, color: Color3)
	if zoneDiscoveryTween then
		zoneDiscoveryTween:Cancel()
	end
	navDiscovery.Text = text
	navDiscovery.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.58)
	navDiscovery.TextTransparency = 0
	navDiscovery.Position = UDim2.fromScale(0.5, 0.285)
	TweenService:Create(navDiscovery, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
		Position = UDim2.fromScale(0.5, 0.29),
	}):Play()
	zoneDiscoveryTween = TweenService:Create(
		navDiscovery,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 1.15),
		{ TextTransparency = 1 }
	)
	zoneDiscoveryTween:Play()
end

local navigationAccumulator = 0
RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if camera then
		local look = camera.CFrame.LookVector
		local heading = math.deg(math.atan2(look.X, -look.Z)) % 360
		navHeading.Text = string.format("%03d DEG", math.floor(heading + 0.5) % 360)
		for _, label in navTickLabels do
			local angle = label:GetAttribute("Angle") :: number
			local delta = navigationDelta(angle, heading)
			local visible = math.abs(delta) <= 112
			label.Visible = visible
			if visible then
				label.Position = UDim2.fromOffset(175 + (delta / 112) * 170, 0)
				label.TextTransparency = math.clamp((math.abs(delta) - 60) / 70, 0, 0.72)
			end
		end
	end

	navigationAccumulator += dt
	if navigationAccumulator >= 0.12 then
		navigationAccumulator = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local territoryName, color = navigationTerritory(root.Position)
			local zone = territoryName .. " // " .. navigationRoute(root.Position)
			navZoneLabel.Text = zone
			navZoneAccent.BackgroundColor3 = color
			navCompassStroke.Color = color
			if zone ~= lastNavigationZone then
				lastNavigationZone = zone
				showZoneDiscovery(zone, color)
			end
		end
	end

	local outside = player:GetAttribute("OutOfBounds") == true
	boundaryWarning.Visible = outside
	if outside then
		local seconds = player:GetAttribute("OutOfBoundsTime")
		boundaryTimer.Text = string.format("%.1f SECONDS", if typeof(seconds) == "number" then seconds else 0)
		boundaryScale.Scale = 1 + math.sin(os.clock() * 8) * 0.018
	end

	local protectedUntil = player:GetAttribute("SpawnProtectedUntil")
	local protectionRemaining = if typeof(protectedUntil) == "number"
		then math.max(0, protectedUntil - workspace:GetServerTimeNow())
		else 0
	spawnShieldFrame.Visible = protectionRemaining > 0
	if protectionRemaining > 0 then
		local ratio = math.clamp(protectionRemaining / SpawnConstants.SPAWN_PROTECTION_DURATION, 0, 1)
		spawnShieldFill.Size = UDim2.fromScale(ratio, 1)
		spawnShieldLabel.Text = string.format("SPAWN-SCHILD // %.1fs // FEUERN BEENDET SCHUTZ", protectionRemaining)
	end
end)

-- Preserve the cockpit hierarchy on laptop and ultrawide resolutions without
-- changing gameplay-space positions or the crosshair recoil scale.
local responsiveScales: { UIScale } = {}
for _, panel in {
	cooldownFrame,
	heatFrame,
	speedFrame,
	healthFill.Parent.Parent,
	jetpackFill.Parent.Parent,
	equipmentLabel,
	scoreFrame,
	carryBanner,
	navCompass,
	navZoneFrame,
	spawnShieldFrame,
} do
	local scale = Instance.new("UIScale")
	scale.Name = "ResponsiveScale"
	scale.Parent = panel
	table.insert(responsiveScales, scale)
end

local lastViewport = Vector2.zero
RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera or camera.ViewportSize == lastViewport then return end
	lastViewport = camera.ViewportSize
	local scaleValue = math.clamp(math.min(lastViewport.X / 1536, lastViewport.Y / 864), 0.72, 1.08)
	for _, scale in responsiveScales do scale.Scale = scaleValue end
end)

player:GetPropertyChangedSignal("Team"):Connect(function()
	refreshFactionPalette()
	refreshEquipment()
end)
refreshFactionPalette()
