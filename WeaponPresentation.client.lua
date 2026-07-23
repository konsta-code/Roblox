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

local function isAlive(): boolean
	if player:GetAttribute("CombatAlive") == false then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

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
		and isAlive()
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
player:GetAttributeChangedSignal("CombatAlive"):Connect(refreshZoom)

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		zoomHeld = false
		refreshZoom()
	end)
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then bindCharacter(player.Character) end

local function playOneShot(
	soundId: string,
	volume: number,
	playbackSpeed: number,
	lowGain: number?,
	midGain: number?,
	highGain: number?,
	distortion: number?,
	echo: number?
)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed * (0.975 + math.random() * 0.05)
	local equalizer = Instance.new("EqualizerSoundEffect")
	equalizer.LowGain = lowGain or 0
	equalizer.MidGain = midGain or 0
	equalizer.HighGain = highGain or 0
	equalizer.Parent = sound
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Threshold = -18
	compressor.Ratio = 4
	compressor.Attack = 0.01
	compressor.Release = 0.12
	compressor.Parent = sound
	if distortion and distortion > 0 then
		local drive = Instance.new("DistortionSoundEffect")
		drive.Level = distortion
		drive.Parent = sound
	end
	if echo and echo > 0 then
		local tail = Instance.new("EchoSoundEffect")
		tail.Delay = 0.08
		tail.Feedback = echo
		tail.DryLevel = 0
		tail.WetLevel = -8
		tail.Parent = sound
	end
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
end

WeaponFeedback.Fired:Connect(function(weapon: WeaponFeedback.Weapon)
	local kit = ClassKitConstants.Get(player:GetAttribute("Loadout"))
	if weapon == "Spinfusor" then
		local weight = math.clamp(kit.disc.directDamage / 115, 0.45, 1)
		-- Low launch body, physical breech and a short plasma crack. Layering
		-- avoids the toy-like single electronic ping of the prototype.
		playOneShot("rbxasset://sounds/impact_explosion_03.mp3", 0.13 + weight * 0.12, 1.32 - weight * 0.42, 5, -3, -10, 0.05)
		playOneShot("rbxasset://sounds/collide.wav", 0.16 + weight * 0.11, 0.66 + weight * 0.17, 3, 1, -5, 0.10)
		playOneShot("rbxasset://sounds/electronicpingshort.wav", 0.20 + weight * 0.13, 1.18 - weight * 0.26, -8, 2, 5, 0.03, 0.12)
	elseif weapon == "Chaingun" then
		local pitch = math.clamp(1.45 - kit.automatic.damagePerHit / 30, 0.72, 1.35)
		local heavyShot = math.clamp(kit.automatic.damagePerHit / 48 + (kit.automatic.pellets or 1) * 0.04, 0.18, 1)
		playOneShot("rbxasset://sounds/collide.wav", 0.13 + heavyShot * 0.12, pitch, 2, 2, -1, 0.12 + heavyShot * 0.08)
		playOneShot("rbxasset://sounds/electronicpingshort.wav", 0.07 + heavyShot * 0.08, pitch * 1.34, -9, 1, 4, 0.04)
		if heavyShot > 0.62 then
			playOneShot("rbxasset://sounds/impact_explosion_03.mp3", 0.07 + heavyShot * 0.07, 1.45 - heavyShot * 0.42, 4, -4, -12, 0.05)
		end
	elseif weapon == "Grenade" then
		playOneShot("rbxasset://sounds/action_jump.mp3", 0.22, 0.76, 4, -2, -8, 0.06)
		playOneShot("rbxasset://sounds/collide.wav", 0.13, 1.18, -3, 2, 2, 0.04)
	elseif weapon == "Melee" then
		playOneShot("rbxasset://sounds/action_jump.mp3", 0.25, 1.36, -7, 2, 5, 0.05)
		playOneShot("rbxasset://sounds/collide.wav", 0.16, 0.88, 3, 1, -4, 0.08)
	end
end)

local wind = Instance.new("Sound")
wind.Name = "SkiWind"
wind.SoundId = "rbxasset://sounds/action_falling.ogg"
wind.Looped = true
wind.Volume = 0
wind.PlaybackSpeed = 0.45
wind.Parent = SoundService
local windEq = Instance.new("EqualizerSoundEffect")
windEq.LowGain = -12
windEq.MidGain = -3
windEq.HighGain = 3
windEq.Parent = wind
wind:Play()

local jet = Instance.new("Sound")
jet.Name = "JetpackLoop"
jet.SoundId = "rbxasset://sounds/action_falling.ogg"
jet.Looped = true
jet.Volume = 0
jet.PlaybackSpeed = 1.7
jet.Parent = SoundService
local jetEq = Instance.new("EqualizerSoundEffect")
jetEq.LowGain = 5
jetEq.MidGain = -2
jetEq.HighGain = -7
jetEq.Parent = jet
local jetDrive = Instance.new("DistortionSoundEffect")
jetDrive.Level = 0.18
jetDrive.Parent = jet
jet:Play()

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local speed = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity.Magnitude else 0
	local menuOpen = player:GetAttribute("LoadoutMenuOpen") == true or not isAlive()
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
