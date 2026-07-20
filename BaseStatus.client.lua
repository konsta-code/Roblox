-- BaseStatus.client.lua
-- Kompakte Generator-/Stromanzeige für beide Teams.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "BaseStatusHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(360, 26)
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0, 132)
frame.BackgroundColor3 = Color3.fromRGB(14, 18, 25)
frame.BackgroundTransparency = 0.28
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = frame

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 14)
layout.Parent = frame

local labels: { [Team]: TextLabel } = {}

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
	label.Text = string.format("%s GEN %d%%  %s", string.upper(team.Name), percent, powered and "ONLINE" or "OFFLINE")
	label.TextColor3 = powered and team.TeamColor.Color:Lerp(Color3.new(1, 1, 1), 0.35) or Color3.fromRGB(255, 90, 80)
end

for _, team in Teams:GetTeams() do
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(160, 22)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.Parent = frame
	labels[team] = label

	for _, prefix in { "GeneratorHealth_", "GeneratorMaxHealth_", "BasePower_" } do
		ReplicatedStorage:GetAttributeChangedSignal(prefix .. team.Name):Connect(function()
			updateTeam(team)
		end)
	end
	updateTeam(team)
end
