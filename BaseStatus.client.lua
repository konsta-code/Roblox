-- BaseStatus.client.lua
-- Kompakte Generator-/Stromanzeige für beide Teams.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "BaseStatusHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "CoreNetwork"
frame.Size = UDim2.fromOffset(286, 112)
frame.AnchorPoint = Vector2.new(0, 0.5)
frame.Position = UDim2.new(0, 18, 0.57, 0)
frame.BackgroundColor3 = Color3.fromRGB(4, 13, 21)
frame.BackgroundTransparency = 0.14
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 3)
corner.Parent = frame
local frameStroke = Instance.new("UIStroke")
frameStroke.Thickness = 1
frameStroke.Transparency = 0.35
frameStroke.Parent = frame
local frameGradient = Instance.new("UIGradient")
frameGradient.Rotation = 90
frameGradient.Parent = frame
local topRail = Instance.new("Frame")
topRail.Size = UDim2.new(1, -12, 0, 2)
topRail.Position = UDim2.fromOffset(6, 0)
topRail.BorderSizePixel = 0
topRail.Parent = frame

local function refreshShell()
	local ember = player.Team ~= nil and player.Team.TeamColor.Color.R > player.Team.TeamColor.Color.B
	local accent = if ember then Color3.fromRGB(255, 76, 28) else Color3.fromRGB(52, 222, 255)
	local panel = if ember then Color3.fromRGB(22, 5, 8) else Color3.fromRGB(4, 15, 24)
	frame.BackgroundColor3 = panel
	frameStroke.Color = accent
	topRail.BackgroundColor3 = accent
	frameGradient.Color = ColorSequence.new(panel:Lerp(accent, 0.12), panel)
end
player:GetPropertyChangedSignal("Team"):Connect(refreshShell)
refreshShell()

local layout = Instance.new("UIListLayout")
local content = Instance.new("Frame")
content.Name = "CoreRows"
content.Size = UDim2.new(1, -20, 1, -16)
content.Position = UDim2.fromOffset(10, 8)
content.BackgroundTransparency = 1
content.Parent = frame
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.Parent = content

local header = Instance.new("TextLabel")
header.Name = "CoreHeader"
header.Size = UDim2.fromOffset(266, 14)
header.BackgroundTransparency = 1
header.Font = Enum.Font.RobotoMono
header.Text = "CORE NETWORK // LIVE TELEMETRY"
header.TextColor3 = Color3.fromRGB(135, 157, 176)
header.TextSize = 9
header.TextXAlignment = Enum.TextXAlignment.Left
header.LayoutOrder = 0
header.Parent = content

local labels: { [Team]: TextLabel } = {}

local function refreshPanelVisibility()
	local show = false
	for _, team in Teams:GetTeams() do
		local health = ReplicatedStorage:GetAttribute("GeneratorHealth_" .. team.Name)
		local maxHealth = ReplicatedStorage:GetAttribute("GeneratorMaxHealth_" .. team.Name)
		local powered = ReplicatedStorage:GetAttribute("BasePower_" .. team.Name)
		if powered == false or (typeof(health) == "number" and typeof(maxHealth) == "number" and health < maxHealth) then
			show = true
			break
		end
	end
	frame.Visible = show
end

local function updateTeam(team: Team)
	local label = labels[team]
	if not label then
		return
	end
	local health = ReplicatedStorage:GetAttribute("GeneratorHealth_" .. team.Name)
	local maxHealth = ReplicatedStorage:GetAttribute("GeneratorMaxHealth_" .. team.Name)
	local powered = ReplicatedStorage:GetAttribute("BasePower_" .. team.Name)
	local percent = if typeof(health) == "number"
			and typeof(maxHealth) == "number"
			and maxHealth > 0
		then math.round(health / maxHealth * 100)
		else 0
	local status = if not powered then "OFFLINE" elseif percent <= 25 then "CRITICAL" elseif percent <= 60 then "DAMAGED" else "ONLINE"
	local faction = if team.Name == "Blue" then "CRYO CORE" else "EMBER HIVE"
	label.Text = string.format("%s  //  %03d%%  //  %s", faction, percent, status)
	label.TextColor3 = if not powered
		then Color3.fromRGB(255, 90, 80)
		elseif percent <= 25
		then Color3.fromRGB(255, 179, 69)
		else team.TeamColor.Color:Lerp(Color3.new(1, 1, 1), 0.35)
	label.BackgroundColor3 = team.TeamColor.Color:Lerp(Color3.fromRGB(8, 12, 18), 0.72)
	refreshPanelVisibility()
end

for _, team in Teams:GetTeams() do
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(266, 34)
	label.BackgroundTransparency = 0.3
	label.BorderSizePixel = 0
	label.Font = Enum.Font.RobotoMono
	label.TextSize = 10
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LayoutOrder = if team.Name == "Blue" then 1 else 2
	label.Parent = content
	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 2)
	labelCorner.Parent = label
	local labelStroke = Instance.new("UIStroke")
	labelStroke.Color = team.TeamColor.Color
	labelStroke.Thickness = 1
	labelStroke.Transparency = 0.58
	labelStroke.Parent = label
	local accentRail = Instance.new("Frame")
	accentRail.Size = UDim2.fromOffset(3, 24)
	accentRail.Position = UDim2.fromOffset(5, 5)
	accentRail.BackgroundColor3 = team.TeamColor.Color
	accentRail.BorderSizePixel = 0
	accentRail.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.Parent = label
	labels[team] = label

	for _, prefix in { "GeneratorHealth_", "GeneratorMaxHealth_", "BasePower_" } do
		ReplicatedStorage:GetAttributeChangedSignal(prefix .. team.Name):Connect(function()
			updateTeam(team)
		end)
	end
	updateTeam(team)
end

-- Generator-Weltmarker: beide Objectives bleiben auch auf der Titan-Map
-- auffindbar, ohne dass ein zusaetzlicher RemoteEvent noetig ist.
type GeneratorMarker = { gui: BillboardGui, label: TextLabel, part: BasePart }
local generatorMarkers: { [BasePart]: GeneratorMarker } = {}

local function attachGeneratorMarker(instance: Instance)
	if not instance:IsA("BasePart") or generatorMarkers[instance] then
		return
	end
	local markerGui = Instance.new("BillboardGui")
	markerGui.Name = "GeneratorMarker"
	markerGui.Size = UDim2.fromOffset(150, 26)
	markerGui.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	markerGui.AlwaysOnTop = false
	markerGui.MaxDistance = 500
	markerGui.ResetOnSpawn = false
	markerGui.Parent = instance

	local markerLabel = Instance.new("TextLabel")
	markerLabel.Size = UDim2.fromScale(1, 1)
	markerLabel.BackgroundColor3 = Color3.fromRGB(6, 11, 17)
	markerLabel.BackgroundTransparency = 0.68
	markerLabel.BorderSizePixel = 0
	markerLabel.Font = Enum.Font.GothamBlack
	markerLabel.Text = "GENERATOR"
	markerLabel.TextColor3 = instance.Color
	markerLabel.TextSize = 10
	markerLabel.TextStrokeColor3 = Color3.fromRGB(3, 6, 9)
	markerLabel.TextStrokeTransparency = 0.35
	markerLabel.Parent = markerGui
	local markerCorner = Instance.new("UICorner")
	markerCorner.CornerRadius = UDim.new(0, 7)
	markerCorner.Parent = markerLabel

	generatorMarkers[instance] = { gui = markerGui, label = markerLabel, part = instance }
end

local function removeGeneratorMarker(instance: Instance)
	local marker = generatorMarkers[instance :: BasePart]
	if marker then
		marker.gui:Destroy()
		generatorMarkers[instance :: BasePart] = nil
	end
end

CollectionService:GetInstanceAddedSignal("PowerGenerator"):Connect(attachGeneratorMarker)
CollectionService:GetInstanceRemovedSignal("PowerGenerator"):Connect(removeGeneratorMarker)
for _, instance in CollectionService:GetTagged("PowerGenerator") do
	attachGeneratorMarker(instance)
end

local alert = Instance.new("TextLabel")
alert.Name = "BaseAlert"
alert.Size = UDim2.fromOffset(620, 52)
alert.AnchorPoint = Vector2.new(0.5, 0)
alert.Position = UDim2.new(0.5, 0, 0, 306)
alert.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
alert.BackgroundTransparency = 1
alert.BorderSizePixel = 0
alert.Font = Enum.Font.GothamBlack
alert.Text = ""
alert.TextColor3 = Color3.fromRGB(255, 105, 90)
alert.TextSize = 22
alert.TextStrokeColor3 = Color3.fromRGB(5, 7, 10)
alert.TextStrokeTransparency = 1
alert.TextTransparency = 1
alert.Parent = gui
local alertCorner = Instance.new("UICorner")
alertCorner.CornerRadius = UDim.new(0, 9)
alertCorner.Parent = alert
local alertScale = Instance.new("UIScale")
alertScale.Parent = alert

local alertThread: thread? = nil
local lastBaseEventSerial = ReplicatedStorage:GetAttribute("BaseEventSerial")
if typeof(lastBaseEventSerial) ~= "number" then
	lastBaseEventSerial = 0
end

local function showBaseAlert(text: string, color: Color3, danger: boolean)
	if alertThread then
		task.cancel(alertThread)
	end
	alert.Text = text
	alert.TextColor3 = color
	alert.BackgroundTransparency = 0.2
	alert.TextTransparency = 0
	alert.TextStrokeTransparency = 0.35
	alertScale.Scale = 0.84
	TweenService:Create(alertScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local tone = Instance.new("Sound")
	tone.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	tone.Volume = 0.52
	tone.PlaybackSpeed = danger and 0.68 or 1.2
	tone.Parent = SoundService
	tone:Play()
	Debris:AddItem(tone, 2)

	alertThread = task.spawn(function()
		task.wait(2.6)
		TweenService:Create(alert, TweenInfo.new(0.5), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		alertThread = nil
	end)
end

ReplicatedStorage:GetAttributeChangedSignal("BaseEventSerial"):Connect(function()
	local serial = ReplicatedStorage:GetAttribute("BaseEventSerial")
	if typeof(serial) ~= "number" or serial <= lastBaseEventSerial then
		return
	end
	lastBaseEventSerial = serial
	local kind = ReplicatedStorage:GetAttribute("BaseEventKind")
	local teamName = ReplicatedStorage:GetAttribute("BaseEventTeam")
	if typeof(kind) ~= "string" or typeof(teamName) ~= "string" then
		return
	end
	local isOurBase = player.Team ~= nil and player.Team.Name == teamName
	local text: string
	local color: Color3
	local danger = false
	if kind == "UnderAttack" then
		text = if isOurBase then "ALARM // EUER GENERATOR WIRD ANGEGRIFFEN" else "FEINDLICHER GENERATOR UNTER BESCHUSS"
		color = Color3.fromRGB(255, 173, 69)
		danger = isOurBase
	elseif kind == "Destroyed" then
		text = if isOurBase then "KRITISCH // EUER GENERATOR WURDE ZERSTOERT" else "FEINDLICHER GENERATOR ZERSTOERT"
		color = if isOurBase then Color3.fromRGB(255, 80, 72) else Color3.fromRGB(112, 244, 185)
		danger = isOurBase
	elseif kind == "Restored" then
		text = if isOurBase then "ENERGIE WIEDERHERGESTELLT" else "FEINDLICHER GENERATOR WIEDER ONLINE"
		color = if isOurBase then Color3.fromRGB(112, 244, 185) else Color3.fromRGB(255, 173, 69)
	elseif kind == "Repaired" then
		text = string.upper(teamName) .. " GENERATOR VOLLSTAENDIG REPARIERT"
		color = Color3.fromRGB(112, 244, 185)
	else
		return
	end
	showBaseAlert(text, color, danger)
end)

local markerAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	markerAccumulator += dt
	if markerAccumulator < 0.15 then
		return
	end
	markerAccumulator = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for part, marker in generatorMarkers do
		if not part.Parent then
			continue
		end
		local teamName = part:GetAttribute("Team")
		local health = part:GetAttribute("Health")
		local maxHealth = part:GetAttribute("MaxHealth")
		local stage = part:GetAttribute("DamageStage")
		local percent = if typeof(health) == "number" and typeof(maxHealth) == "number" and maxHealth > 0
			then math.round(health / maxHealth * 100)
			else 0
		local distance = ""
		local distanceStuds = math.huge
		if root and root:IsA("BasePart") then
			distanceStuds = (part.Position - root.Position).Magnitude
			distance = string.format(" // %dm", math.floor(distanceStuds / 3.57))
		end
		marker.gui.Enabled = distanceStuds <= 260 or percent < 100
		marker.label.Text = string.format(
			"%s GENERATOR // %d%% // %s%s",
			string.upper(typeof(teamName) == "string" and teamName or "BASE"),
			percent,
			string.upper(typeof(stage) == "string" and stage or "UNKNOWN"),
			distance
		)
		marker.label.TextColor3 = if percent <= 0
			then Color3.fromRGB(255, 80, 72)
			elseif percent <= 25
			then Color3.fromRGB(255, 179, 69)
			else part.Color:Lerp(Color3.new(1, 1, 1), 0.25)
	end
end)
