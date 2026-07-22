-- WeaponPresentation.client.lua
-- Scope, lokales Waffen-Audio sowie geschwindigkeitsabhängiger Wind/Jet-Sound.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local WeaponFeedback = require(ReplicatedStorage.Modules.WeaponFeedback)
local WeaponState = require(ReplicatedStorage.Modules.WeaponState)

local player = Players.LocalPlayer
local zoomHeld = false

local scopeGui = Instance.new("ScreenGui")
scopeGui.Name = "WeaponScope"
scopeGui.ResetOnSpawn = false
scopeGui.IgnoreGuiInset = true
scopeGui.DisplayOrder = 12
scopeGui.Enabled = false
scopeGui.Parent = player:WaitForChild("PlayerGui")

local function scopePanel(name: string, size: UDim2, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Color3.fromRGB(2, 5, 8)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = scopeGui
	return frame
end

scopePanel("Top", UDim2.fromScale(1, 0.37), UDim2.fromScale(0, 0))
scopePanel("Bottom", UDim2.fromScale(1, 0.37), UDim2.fromScale(0, 0.63))
scopePanel("Left", UDim2.fromScale(0.34, 0.26), UDim2.fromScale(0, 0.37))
scopePanel("Right", UDim2.fromScale(0.34, 0.26), UDim2.fromScale(0.66, 0.37))

local scopeTint = Instance.new("Frame")
scopeTint.Name = "Lens"
scopeTint.Size = UDim2.fromScale(0.32, 0.26)
scopeTint.Position = UDim2.fromScale(0.34, 0.37)
scopeTint.BackgroundColor3 = Color3.fromRGB(80, 190, 220)
scopeTint.BackgroundTransparency = 0.9
scopeTint.BorderColor3 = Color3.fromRGB(140, 235, 255)
scopeTint.BorderSizePixel = 2
scopeTint.Parent = scopeGui

local horizontal = Instance.new("Frame")
horizontal.Size = UDim2.new(1, 0, 0, 1)
horizontal.Position = UDim2.fromScale(0, 0.5)
horizontal.BackgroundColor3 = Color3.fromRGB(145, 235, 255)
horizontal.BorderSizePixel = 0
horizontal.Parent = scopeTint

local vertical = Instance.new("Frame")
vertical.Size = UDim2.new(0, 1, 1, 0)
vertical.Position = UDim2.fromScale(0.5, 0)
vertical.BackgroundColor3 = horizontal.BackgroundColor3
vertical.BorderSizePixel = 0
vertical.Parent = scopeTint

local hint = Instance.new("TextLabel")
hint.Size = UDim2.fromOffset(180, 22)
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -28)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamBold
hint.TextSize = 12
hint.TextColor3 = Color3.fromRGB(150, 225, 245)
hint.Text = "[C] PRECISION SCOPE"
hint.Parent = scopeGui

local function currentAutomatic(): ClassKitConstants.AutomaticProfile
	return ClassKitConstants.Get(player:GetAttribute("Loadout")).automatic
end

local function refreshZoom()
	local profile = currentAutomatic()
	local canZoom = WeaponState.Get() == "Chaingun"
		and profile.zoomFov ~= nil
		and not player:GetAttribute("LoadoutMenuOpen")
	local active = zoomHeld and canZoom
	scopeGui.Enabled = active
	player:SetAttribute("WeaponZoomFov", active and profile.zoomFov or nil)
	if active then
		scopeTint.BackgroundColor3 = profile.tracerColor
		horizontal.BackgroundColor3 = profile.tracerColor:Lerp(Color3.new(1, 1, 1), 0.35)
		vertical.BackgroundColor3 = horizontal.BackgroundColor3
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and (input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonL2) then
		zoomHeld = true
		refreshZoom()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonL2 then
		zoomHeld = false
		refreshZoom()
	end
end)

WeaponState.Changed:Connect(refreshZoom)
player:GetAttributeChangedSignal("Loadout"):Connect(refreshZoom)
player:GetAttributeChangedSignal("LoadoutMenuOpen"):Connect(refreshZoom)

local function playOneShot(soundId: string, volume: number, playbackSpeed: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
end

WeaponFeedback.Fired:Connect(function(weapon: WeaponFeedback.Weapon)
	local kit = ClassKitConstants.Get(player:GetAttribute("Loadout"))
	if weapon == "Spinfusor" then
		local weight = math.clamp(kit.disc.directDamage / 115, 0.45, 1)
		playOneShot("rbxasset://sounds/electronicpingshort.wav", 0.38 + weight * 0.2, 1.35 - weight * 0.45)
		playOneShot("rbxasset://sounds/collide.wav", 0.12 + weight * 0.12, 0.75 + weight * 0.2)
	elseif weapon == "Chaingun" then
		local pitch = math.clamp(1.45 - kit.automatic.damagePerHit / 30, 0.72, 1.35)
		playOneShot("rbxasset://sounds/electronicpingshort.wav", 0.22, pitch)
	elseif weapon == "Grenade" then
		playOneShot("rbxasset://sounds/action_jump.mp3", 0.28, 0.82)
	elseif weapon == "Melee" then
		playOneShot("rbxasset://sounds/action_jump.mp3", 0.34, 1.28)
	end
end)

local wind = Instance.new("Sound")
wind.Name = "SkiWind"
wind.SoundId = "rbxasset://sounds/action_falling.ogg"
wind.Looped = true
wind.Volume = 0
wind.PlaybackSpeed = 0.45
wind.Parent = SoundService
wind:Play()

local jet = Instance.new("Sound")
jet.Name = "JetpackLoop"
jet.SoundId = "rbxasset://sounds/action_falling.ogg"
jet.Looped = true
jet.Volume = 0
jet.PlaybackSpeed = 1.7
jet.Parent = SoundService
jet:Play()

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local speed = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity.Magnitude else 0
	local menuOpen = player:GetAttribute("LoadoutMenuOpen") == true
	local windTarget = if menuOpen then 0 else math.clamp((speed - 25) / 150, 0, 0.42)
	wind.Volume += (windTarget - wind.Volume) * math.clamp(dt * 5, 0, 1)
	wind.PlaybackSpeed = 0.45 + math.clamp(speed / 180, 0, 0.8)

	local jetHeld = not menuOpen
		and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
	local jetTarget = jetHeld and 0.24 or 0
	jet.Volume += (jetTarget - jet.Volume) * math.clamp(dt * 9, 0, 1)
end)

refreshZoom()
