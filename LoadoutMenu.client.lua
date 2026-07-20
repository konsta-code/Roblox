-- LoadoutMenu.client.lua
-- L öffnet die Auswahl der neun Light-/Medium-/Heavy-Klassen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local AbilityConstants = require(ReplicatedStorage.Modules.AbilityConstants)
local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local Constants = require(ReplicatedStorage.Modules.LoadoutConstants)

local player = Players.LocalPlayer
local selectEvent = ReplicatedStorage:WaitForChild("SelectLoadout")
local inventoryEvent = ReplicatedStorage:WaitForChild("InventoryStation")

local gui = Instance.new("ScreenGui")
gui.Name = "LoadoutMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local openButton = Instance.new("TextButton")
openButton.Size = UDim2.fromOffset(150, 30)
openButton.AnchorPoint = Vector2.new(0, 1)
openButton.Position = UDim2.new(0, 24, 1, -78)
openButton.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
openButton.BackgroundTransparency = 0.15
openButton.BorderSizePixel = 0
openButton.Font = Enum.Font.GothamBold
openButton.TextSize = 13
openButton.TextColor3 = Color3.fromRGB(235, 235, 240)
openButton.Text = "[L] LOADOUT"
openButton.Parent = gui

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 6)
openCorner.Parent = openButton

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(5, 8, 14)
overlay.BackgroundTransparency = 0.25
overlay.Active = true
overlay.Visible = false
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(820, 650)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(16, 21, 30)
panel.BorderSizePixel = 0
panel.Parent = overlay

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 0, 60)
title.Position = UDim2.fromOffset(28, 12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 24
title.TextColor3 = Color3.fromRGB(240, 245, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "LOADOUT WÄHLEN"
title.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(42, 42)
closeButton.Position = UDim2.new(1, -56, 0, 18)
closeButton.BackgroundColor3 = Color3.fromRGB(38, 45, 58)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.TextColor3 = Color3.fromRGB(235, 235, 240)
closeButton.Text = "X"
closeButton.Modal = true
closeButton.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -56, 0, 34)
statusLabel.Position = UDim2.new(0, 28, 1, -48)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.fromRGB(170, 185, 205)
statusLabel.Text = "Auswahl gilt ab dem nächsten Spawn."
statusLabel.Parent = panel

local cards: { [string]: TextButton } = {}

for index, loadoutId in Constants.ORDER do
	local definition = Constants.LOADOUTS[loadoutId]
	local kit = ClassKitConstants.Get(loadoutId)
	local ability = AbilityConstants.Get(loadoutId)
	local column = (index - 1) % 3
	local row = math.floor((index - 1) / 3)
	local card = Instance.new("TextButton")
	card.Name = loadoutId
	card.Size = UDim2.fromOffset(240, 162)
	card.Position = UDim2.fromOffset(28 + column * 255, 78 + row * 172)
	card.BackgroundColor3 = Color3.fromRGB(30, 38, 52)
	card.BorderSizePixel = 0
	card.AutoButtonColor = true
	card.Font = Enum.Font.GothamBold
	card.TextSize = 12
	card.TextColor3 = Color3.fromRGB(235, 240, 250)
	card.TextWrapped = true
	card.Text = string.format(
		"%s  |  %s\nHP %d   ENERGY %d   GRENADES %d\n\n1  %s\n2  %s\nG  %s\nQ  %s\n\n%s",
		definition.displayName,
		definition.armor,
		definition.maxHealth,
		definition.maxEnergy,
		definition.maxGrenades,
		string.upper(kit.disc.name),
		string.upper(kit.automatic.name),
		string.upper(kit.grenade.name),
		ability.name,
		definition.description
	)
	card.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card

	card.Activated:Connect(function()
		statusLabel.Text = definition.displayName .. " wird angefordert ..."
		selectEvent:FireServer(loadoutId)
	end)
	cards[loadoutId] = card
end

local function refreshCards()
	local selected = player:GetAttribute("Loadout")
	for loadoutId, card in cards do
		card.BackgroundColor3 = if loadoutId == selected
			then Color3.fromRGB(42, 105, 150)
			else Color3.fromRGB(30, 38, 52)
	end
end

local function setOpen(isOpen: boolean)
	overlay.Visible = isOpen
	player:SetAttribute("LoadoutMenuOpen", isOpen)
	RunService:UnbindFromRenderStep("LoadoutMenuMouseRelease")
	if isOpen then
		player.CameraMode = Enum.CameraMode.Classic
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		RunService:BindToRenderStep("LoadoutMenuMouseRelease", Enum.RenderPriority.Camera.Value + 50, function()
			if overlay.Visible then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			end
		end)
		GuiService.SelectedObject = cards[player:GetAttribute("Loadout")] or cards[Constants.DEFAULT_LOADOUT]
		refreshCards()
	else
		GuiService.SelectedObject = nil
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
end

openButton.Activated:Connect(function()
	setOpen(true)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.L and not processed then
		setOpen(not overlay.Visible)
	elseif input.KeyCode == Enum.KeyCode.Escape and overlay.Visible then
		setOpen(false)
	end
end)

player:GetAttributeChangedSignal("Loadout"):Connect(refreshCards)
selectEvent.OnClientEvent:Connect(function(success: boolean, message: string)
	statusLabel.Text = message
	statusLabel.TextColor3 = success and Color3.fromRGB(110, 225, 145) or Color3.fromRGB(255, 120, 110)
	if success then
		task.delay(0.35, function()
			setOpen(false)
		end)
	end
end)

inventoryEvent.OnClientEvent:Connect(function(success: boolean, message: string)
	statusLabel.Text = message
	statusLabel.TextColor3 = success and Color3.fromRGB(110, 225, 145) or Color3.fromRGB(255, 120, 110)
	if success then
		setOpen(true)
	end
end)

-- Auto-Öffnen bei neuer Warmup-Runde (Attribut-Signal, falls Phase wechselt).
local function autoOpenIfWarmup()
	if not overlay.Visible and ReplicatedStorage:GetAttribute("MatchPhase") == "Warmup" then
		setOpen(true)
	end
end
ReplicatedStorage:GetAttributeChangedSignal("MatchPhase"):Connect(autoOpenIfWarmup)

-- Erst-Öffnen DETERMINISTISCH am Charakter-Spawn - unabhängig von der
-- Attribut-Replikation (das war die fragile Stelle). Feuert garantiert beim
-- ersten eigenen Spawn; danach jederzeit mit L. Öffnet nie doppelt.
local autoOpenedOnce = false
local function autoOpenOnFirstSpawn()
	if autoOpenedOnce then
		return
	end
	autoOpenedOnce = true
	task.wait(0.6)
	if not overlay.Visible then
		setOpen(true)
	end
end
player.CharacterAdded:Connect(autoOpenOnFirstSpawn)
if player.Character then
	task.spawn(autoOpenOnFirstSpawn)
end

print("[LoadoutMenu] bereit - Auto-Oeffnen am Spawn aktiv")
