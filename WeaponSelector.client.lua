-- WeaponSelector.client.lua
-- Ablageort: StarterPlayerScripts
--
-- Waffenwahl per Tastatur: 1 = Spinfusor, 2 = Chaingun. Setzt den lokalen
-- WeaponState (den die Waffen-Clients lesen, um zu entscheiden ob sie auf
-- Linksklick feuern) UND meldet die Wahl serverautoritativ an den Server
-- (SelectWeapon), damit der Server erzwingt, dass man nur die ausgerüstete
-- Waffe feuern kann. Zeigt zusätzlich eine kleine HUD-Anzeige der aktiven Waffe.
--
-- Benötigt: RemoteEvent "SelectWeapon" in ReplicatedStorage (Client -> Server)

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local WeaponState = require(ReplicatedStorage.Modules.WeaponState)
local selectEvent = ReplicatedStorage:WaitForChild("SelectWeapon")
local player = Players.LocalPlayer
local SELECT_COOLDOWN = 0.1
local lastSelect = -math.huge

-- === kleine HUD-Anzeige (unten mittig) ===
local gui = Instance.new("ScreenGui")
gui.Name = "WeaponHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -78)
label.Size = UDim2.fromOffset(390, 26)
label.BackgroundTransparency = 0.35
label.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
label.BorderSizePixel = 0
label.TextColor3 = Color3.fromRGB(235, 235, 240)
label.Font = Enum.Font.GothamBold
label.TextSize = 14
label.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = label

local function refresh()
	local w = WeaponState.Get()
	local kit = ClassKitConstants.Get(player:GetAttribute("Loadout"))
	local oneName = string.upper(kit.disc.name)
	local twoName = string.upper(kit.automatic.name)
	local one = w == "Spinfusor" and "[1] " .. oneName or "1 " .. oneName
	local two = w == "Chaingun" and "[2] " .. twoName or "2 " .. twoName
	label.Text = one .. "     " .. two
end

local function selectWeapon(weapon: WeaponState.Weapon)
	local now = os.clock()
	if now - lastSelect < SELECT_COOLDOWN then
		return
	end
	lastSelect = now
	WeaponState.SetPrimaryDown(false)
	WeaponState.Set(weapon)
	selectEvent:FireServer(weapon)
	refresh()
end

WeaponState.Changed:Connect(refresh)
player:GetAttributeChangedSignal("Loadout"):Connect(refresh)
refresh()
selectEvent:FireServer("Spinfusor") -- Startwaffe auch dem Server melden

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or player:GetAttribute("LoadoutMenuOpen") then
		return
	end
	if input.KeyCode == Enum.KeyCode.One then
		selectWeapon("Spinfusor")
	elseif input.KeyCode == Enum.KeyCode.Two then
		selectWeapon("Chaingun")
	end
end)

local function primaryAction(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		WeaponState.SetPrimaryDown(false)
		return Enum.ContextActionResult.Sink
	end
	if inputState ~= Enum.UserInputState.Begin
		or player:GetAttribute("LoadoutMenuOpen")
		or UserInputService:GetFocusedTextBox() ~= nil then
		return Enum.ContextActionResult.Pass
	end
	WeaponState.SetPrimaryDown(true)
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction(
	"PrimaryWeaponFire",
	primaryAction,
	true,
	Enum.UserInputType.MouseButton1,
	Enum.KeyCode.ButtonR2
)
ContextActionService:SetTitle("PrimaryWeaponFire", "FIRE")
ContextActionService:SetPosition("PrimaryWeaponFire", UDim2.new(1, -95, 1, -210))

local function swapAction(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin or player:GetAttribute("LoadoutMenuOpen") then
		return Enum.ContextActionResult.Pass
	end
	selectWeapon(if WeaponState.Get() == "Spinfusor" then "Chaingun" else "Spinfusor")
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("SwapWeapon", swapAction, true, Enum.KeyCode.ButtonR1)
ContextActionService:SetTitle("SwapWeapon", "SWAP")
ContextActionService:SetPosition("SwapWeapon", UDim2.new(1, -190, 1, -285))

player:GetAttributeChangedSignal("LoadoutMenuOpen"):Connect(function()
	if player:GetAttribute("LoadoutMenuOpen") then
		WeaponState.SetPrimaryDown(false)
	end
end)

player.CharacterAdded:Connect(function()
	WeaponState.SetPrimaryDown(false)
end)
