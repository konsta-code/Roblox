-- Compact onboarding and a reusable F1 controls/objective guide.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local AbilityConstants = require(ReplicatedStorage.Modules.AbilityConstants)
local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local LoadoutConstants = require(ReplicatedStorage.Modules.LoadoutConstants)

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "GameGuide"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 18
gui.Parent = player:WaitForChild("PlayerGui")

local openButton = Instance.new("TextButton")
openButton.Name = "GuideButton"
openButton.Size = UDim2.fromOffset(150, 30)
openButton.AnchorPoint = Vector2.new(0, 1)
openButton.Position = UDim2.new(0, 24, 1, -114)
openButton.BackgroundColor3 = Color3.fromRGB(12, 21, 32)
openButton.BackgroundTransparency = 0.12
openButton.BorderSizePixel = 0
openButton.Font = Enum.Font.GothamBold
openButton.Text = "[F1] GUIDE"
openButton.TextColor3 = Color3.fromRGB(150, 225, 255)
openButton.TextSize = 12
openButton.Visible = false
openButton.Parent = gui
local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 6)
openCorner.Parent = openButton

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(2, 6, 11)
overlay.BackgroundTransparency = 0.30
overlay.Visible = false
overlay.Active = true
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(760, 460)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(8, 15, 24)
panel.BorderSizePixel = 0
panel.Parent = overlay
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(66, 164, 215)
panelStroke.Transparency = 0.25
panelStroke.Thickness = 1.5
panelStroke.Parent = panel
local scale = Instance.new("UIScale")
scale.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 0, 58)
title.Position = UDim2.fromOffset(28, 12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "CTF // FIELD GUIDE"
title.TextColor3 = Color3.fromRGB(225, 245, 255)
title.TextSize = 24
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(42, 42)
close.Position = UDim2.new(1, -58, 0, 18)
close.BackgroundColor3 = Color3.fromRGB(32, 45, 60)
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBold
close.Text = "X"
close.TextColor3 = Color3.fromRGB(235, 245, 255)
close.TextSize = 17
close.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 7)
closeCorner.Parent = close

local function section(x: number, y: number, width: number, height: number, heading: string): (Frame, TextLabel)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(width, height)
	frame.Position = UDim2.fromOffset(x, y)
	frame.BackgroundColor3 = Color3.fromRGB(15, 26, 40)
	frame.BackgroundTransparency = 0.10
	frame.BorderSizePixel = 0
	frame.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local headingLabel = Instance.new("TextLabel")
	headingLabel.Size = UDim2.new(1, -24, 0, 30)
	headingLabel.Position = UDim2.fromOffset(12, 8)
	headingLabel.BackgroundTransparency = 1
	headingLabel.Font = Enum.Font.GothamBlack
	headingLabel.Text = heading
	headingLabel.TextColor3 = Color3.fromRGB(105, 220, 255)
	headingLabel.TextSize = 14
	headingLabel.TextXAlignment = Enum.TextXAlignment.Left
	headingLabel.Parent = frame
	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -24, 1, -48)
	body.Position = UDim2.fromOffset(12, 40)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Color3.fromRGB(205, 218, 232)
	body.TextSize = 13
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = frame
	return frame, body
end

local _, objectiveBody = section(28, 78, 342, 150, "OBJECTIVE")
objectiveBody.Text = "Steal the enemy flag and bring it to your own flag stand. Your flag must be home. First team to 5 captures wins. Destroy generators to disable enemy stations and turrets."

local _, movementBody = section(390, 78, 342, 150, "MOVEMENT")
movementBody.Text = "WASD  Move\nSPACE  Ski (hold on slopes)\nSHIFT / RMB  Jetpack\nUse downhill momentum, release over ridges and combine jets with disc jumps."

local _, combatBody = section(28, 246, 342, 174, "COMBAT & TEAM")
combatBody.Text = "LMB / R2  Fire\n1 / 2 or R1  Switch weapon\nG / L1  Grenade     F / R3  Melee\nQ / X  Ability      C / L2  Scope\nV / MMB  Team ping  Z / Y  Flag punt"

local _, classBody = section(390, 246, 342, 174, "CURRENT LOADOUT")

local function refreshClass()
	local loadoutId = player:GetAttribute("Loadout")
	local definition = LoadoutConstants.LOADOUTS[loadoutId] or LoadoutConstants.LOADOUTS[LoadoutConstants.DEFAULT_LOADOUT]
	local kit = ClassKitConstants.Get(loadoutId)
	local ability = AbilityConstants.Get(loadoutId)
	classBody.Text = string.format(
		"%s // %s\n%d HP  |  %d ENERGY\n1  %s\n2  %s\nQ  %s\n\n[L] opens all nine classes.",
		string.upper(definition.displayName),
		string.upper(definition.armor),
		definition.maxHealth,
		definition.maxEnergy,
		string.upper(kit.disc.name),
		string.upper(kit.automatic.name),
		ability.name
	)
end

local function setOpen(value: boolean)
	overlay.Visible = value
	if value then
		refreshClass()
	end
end

openButton.Activated:Connect(function() setOpen(true) end)
close.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.F1 and not processed then
		setOpen(not overlay.Visible)
	elseif input.KeyCode == Enum.KeyCode.Escape and overlay.Visible then
		setOpen(false)
	end
end)
player:GetAttributeChangedSignal("Loadout"):Connect(refreshClass)

local tip = Instance.new("TextLabel")
tip.Size = UDim2.fromOffset(690, 34)
tip.AnchorPoint = Vector2.new(0.5, 0)
tip.Position = UDim2.new(0.5, 0, 0, 176)
tip.BackgroundColor3 = Color3.fromRGB(7, 15, 25)
tip.BackgroundTransparency = 0.12
tip.BorderSizePixel = 0
tip.Font = Enum.Font.GothamBold
tip.Text = "SPACE  SKI    //    SHIFT/RMB  JET    //    1/2  WEAPONS    //    L  LOADOUT    //    F1  GUIDE"
tip.TextColor3 = Color3.fromRGB(170, 228, 250)
tip.TextSize = 12
tip.TextTransparency = 1
tip.Visible = false
tip.Parent = gui
local tipCorner = Instance.new("UICorner")
tipCorner.CornerRadius = UDim.new(0, 7)
tipCorner.Parent = tip

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	scale.Scale = math.clamp(math.min(viewport.X / 840, viewport.Y / 560), 0.62, 1)
	tip.Size = UDim2.fromOffset(math.min(690, viewport.X - 24), 34)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
updateScale()
refreshClass()
