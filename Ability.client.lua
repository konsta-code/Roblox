-- Ability input and faction-responsive cooldown telemetry. Gameplay remains server-authoritative.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AbilityConstants = require(ReplicatedStorage.Modules.AbilityConstants)
local activateEvent = ReplicatedStorage:WaitForChild("ActivateAbility")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "AbilityHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local factionAccent = Color3.fromRGB(73, 211, 255)
local factionPanel = Color3.fromRGB(4, 18, 32)

local function refreshFactionTheme()
	if player.Team and player.Team.Name == "Red" then
		factionAccent = Color3.fromRGB(255, 91, 58)
		factionPanel = Color3.fromRGB(31, 9, 8)
	else
		factionAccent = Color3.fromRGB(73, 211, 255)
		factionPanel = Color3.fromRGB(4, 18, 32)
	end
end

refreshFactionTheme()

local panel = Instance.new("Frame")
panel.Name = "WarlinkAbility"
panel.Size = UDim2.fromOffset(244, 62)
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -20, 1, -280)
panel.BackgroundColor3 = factionPanel
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 3)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 1
panelStroke.Transparency = 0.2
panelStroke.Color = factionAccent
panelStroke.Parent = panel

local panelGradient = Instance.new("UIGradient")
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 24, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 8, 16)),
})
panelGradient.Rotation = 12
panelGradient.Parent = panel

local rail = Instance.new("Frame")
rail.Name = "FactionRail"
rail.Size = UDim2.new(1, 0, 0, 3)
rail.BackgroundColor3 = factionAccent
rail.BorderSizePixel = 0
rail.Parent = panel

local node = Instance.new("Frame")
node.Name = "WarlinkNode"
node.Size = UDim2.fromOffset(8, 8)
node.Position = UDim2.new(1, -15, 0, 9)
node.Rotation = 45
node.BackgroundColor3 = factionAccent
node.BorderSizePixel = 0
node.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -34, 0, 18)
title.Position = UDim2.fromOffset(12, 7)
title.BackgroundTransparency = 1
title.Font = Enum.Font.RobotoMono
title.TextSize = 11
title.TextColor3 = Color3.fromRGB(238, 245, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -24, 0, 14)
status.Position = UDim2.fromOffset(12, 25)
status.BackgroundTransparency = 1
status.Font = Enum.Font.RobotoMono
status.TextSize = 9
status.TextColor3 = Color3.fromRGB(168, 183, 202)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = panel

local track = Instance.new("Frame")
track.Size = UDim2.new(1, -24, 0, 9)
track.Position = UDim2.fromOffset(12, 44)
track.BackgroundColor3 = Color3.fromRGB(17, 34, 47)
track.BorderSizePixel = 0
track.ClipsDescendants = true
track.Parent = panel

local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(0, 2)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(1, 1)
fill.BorderSizePixel = 0
fill.Parent = track

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 2)
fillCorner.Parent = fill

local dividers: { Frame } = {}
for index = 1, 5 do
	local divider = Instance.new("Frame")
	divider.Name = "Segment" .. index
	divider.Size = UDim2.fromOffset(2, 9)
	divider.Position = UDim2.new(index / 6, -1, 0, 0)
	divider.BackgroundColor3 = factionPanel
	divider.BackgroundTransparency = 0.15
	divider.BorderSizePixel = 0
	divider.ZIndex = 3
	divider.Parent = track
	table.insert(dividers, divider)
end

local scale = Instance.new("UIScale")
scale.Parent = panel

local function activate(_name: string, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	if player:GetAttribute("LoadoutMenuOpen") then return Enum.ContextActionResult.Sink end
	if player:GetAttribute("CombatAlive") == false then return Enum.ContextActionResult.Sink end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return Enum.ContextActionResult.Sink end
	local now = workspace:GetServerTimeNow()
	if (player:GetAttribute("AbilityReadyAt") or 0) <= now
		and (player:GetAttribute("AbilitySilencedUntil") or 0) <= now then
		activateEvent:FireServer()
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("ActivateClassAbility", activate, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle("ActivateClassAbility", "ABILITY")
ContextActionService:SetPosition("ActivateClassAbility", UDim2.new(1, -285, 1, -120))

activateEvent.OnClientEvent:Connect(function(success: boolean)
	if success then
		node.Size = UDim2.fromOffset(14, 14)
		node.BackgroundColor3 = Color3.new(1, 1, 1)
		TweenService:Create(node, TweenInfo.new(0.32, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = factionAccent,
		}):Play()
	end
end)

RunService.RenderStepped:Connect(function()
	local definition = AbilityConstants.Get(player:GetAttribute("Loadout"))
	local now = workspace:GetServerTimeNow()
	local readyAt = player:GetAttribute("AbilityReadyAt") or 0
	local activeUntil = player:GetAttribute("AbilityActiveUntil") or 0
	local silencedUntil = player:GetAttribute("AbilitySilencedUntil") or 0
	local remaining = math.max(0, readyAt - now)
	local ratio = math.clamp(1 - remaining / definition.cooldown, 0, 1)

	panel.Visible = player:GetAttribute("LoadoutMenuOpen") ~= true
		and (remaining > 0 or activeUntil > now or silencedUntil > now)
	local camera = workspace.CurrentCamera
	if camera then
		scale.Scale = math.clamp(camera.ViewportSize.X / 1500, 0.78, 1)
	end
	panel.BackgroundColor3 = factionPanel
	panelStroke.Color = factionAccent
	rail.BackgroundColor3 = factionAccent
	if node.Size.X.Offset == 8 then node.BackgroundColor3 = factionAccent end
	panelGradient.Color = ColorSequence.new(factionPanel:Lerp(factionAccent, 0.13), factionPanel)
	for _, divider in dividers do divider.BackgroundColor3 = factionPanel end
	fill.BackgroundColor3 = definition.color
	fill.Size = UDim2.fromScale(ratio, 1)
	title.Text = "Q // " .. string.upper(definition.name) .. " // WARLINK"
	if silencedUntil > now then
		status.Text = string.format("SIGNAL JAMMED // %.1fs", silencedUntil - now)
		status.TextColor3 = Color3.fromRGB(255, 105, 90)
	elseif activeUntil > now then
		status.Text = string.format("SYSTEM ACTIVE // %.1fs", activeUntil - now)
		status.TextColor3 = definition.color
	elseif remaining > 0 then
		status.Text = string.format("RECHARGING // %.1fs", remaining)
		status.TextColor3 = Color3.fromRGB(255, 195, 105)
	else
		status.Text = "SYSTEM ARMED // PRESS Q"
		status.TextColor3 = Color3.fromRGB(168, 183, 202)
	end
end)

player:GetPropertyChangedSignal("Team"):Connect(refreshFactionTheme)
