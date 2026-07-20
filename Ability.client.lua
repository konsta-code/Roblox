-- Ability input and cooldown HUD. Gameplay effects remain server-authoritative.

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
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "AbilityPanel"
panel.Size = UDim2.fromOffset(225, 54)
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -24, 1, -82)
panel.BackgroundColor3 = Color3.fromRGB(9, 14, 22)
panel.BackgroundTransparency = 0.18
panel.BorderSizePixel = 0
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 7)
panelCorner.Parent = panel

local accent = Instance.new("Frame")
accent.Name = "Accent"
accent.Size = UDim2.fromOffset(4, 54)
accent.BorderSizePixel = 0
accent.Parent = panel

local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(0, 7)
accentCorner.Parent = accent

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 20)
title.Position = UDim2.fromOffset(11, 4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextColor3 = Color3.fromRGB(238, 245, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 15)
status.Position = UDim2.fromOffset(11, 22)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 10
status.TextColor3 = Color3.fromRGB(168, 183, 202)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = panel

local track = Instance.new("Frame")
track.Size = UDim2.new(1, -18, 0, 7)
track.Position = UDim2.fromOffset(11, 41)
track.BackgroundColor3 = Color3.fromRGB(36, 45, 58)
track.BorderSizePixel = 0
track.ClipsDescendants = true
track.Parent = panel

local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(1, 1)
fill.BorderSizePixel = 0
fill.Parent = track

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

local function activate(_name: string, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	if player:GetAttribute("LoadoutMenuOpen") then return Enum.ContextActionResult.Sink end
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
		panel.BackgroundColor3 = Color3.fromRGB(28, 48, 60)
		TweenService:Create(panel, TweenInfo.new(0.45), { BackgroundColor3 = Color3.fromRGB(9, 14, 22) }):Play()
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
	accent.BackgroundColor3 = definition.color
	fill.BackgroundColor3 = definition.color
	fill.Size = UDim2.fromScale(ratio, 1)
	title.Text = "[Q]  " .. definition.name
	if silencedUntil > now then
		status.Text = string.format("EMP BLOCKIERT  %.1fs", silencedUntil - now)
		status.TextColor3 = Color3.fromRGB(255, 105, 90)
	elseif activeUntil > now then
		status.Text = string.format("AKTIV  %.1fs", activeUntil - now)
		status.TextColor3 = definition.color
	elseif remaining > 0 then
		status.Text = string.format("LÄDT  %.1fs", remaining)
		status.TextColor3 = Color3.fromRGB(255, 195, 105)
	else
		status.Text = definition.description
		status.TextColor3 = Color3.fromRGB(168, 183, 202)
	end
end)
