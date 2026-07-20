-- ProjectileWeapon.client.lua
-- Input and local feedback only. The server creates the single visible projectile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ClassKitConstants = require(ReplicatedStorage.Modules.ClassKitConstants)
local WeaponFeedback = require(ReplicatedStorage.Modules.WeaponFeedback)
local WeaponState = require(ReplicatedStorage.Modules.WeaponState)
local fireEvent = ReplicatedStorage:WaitForChild("FireWeapon")
local player = Players.LocalPlayer

local lastFireTime = 0

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if player:GetAttribute("LoadoutMenuOpen") then return end
	local silencedUntil = player:GetAttribute("AbilitySilencedUntil")
	if typeof(silencedUntil) == "number" and silencedUntil > workspace:GetServerTimeNow() then return end
	if WeaponState.Get() ~= "Spinfusor" then return end -- Linksklick nur wenn Spinfusor gewählt

	local profile = ClassKitConstants.Get(player:GetAttribute("Loadout")).disc
	local now = os.clock()
	if now - lastFireTime < profile.fireCooldown then return end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 or not camera then return end

	lastFireTime = now
	WeaponFeedback.StartCooldown("Spinfusor", profile.fireCooldown)
	local direction = camera.CFrame.LookVector.Unit
	fireEvent:FireServer(direction)
	WeaponFeedback.Fire("Spinfusor")
end)

print("[Spinfusor] single-authority client loaded")
