-- Equipment.client.lua
-- G / Controller-L1: Granate. F / Controller-R3: Nahkampf.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Modules.EquipmentConstants)
local WeaponFeedback = require(ReplicatedStorage.Modules.WeaponFeedback)

local player = Players.LocalPlayer
local throwEvent = ReplicatedStorage:WaitForChild("ThrowGrenade")
local meleeEvent = ReplicatedStorage:WaitForChild("MeleeAttack")

local lastLocalThrow = -math.huge
local lastLocalMelee = -math.huge

local function getAimDirection(): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	return camera.CFrame.LookVector.Unit
end

local function canUseInput(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local silencedUntil = player:GetAttribute("AbilitySilencedUntil")
	return not player:GetAttribute("LoadoutMenuOpen")
		and UserInputService:GetFocusedTextBox() == nil
		and not (typeof(silencedUntil) == "number" and silencedUntil > workspace:GetServerTimeNow())
		and humanoid ~= nil
		and humanoid.Health > 0
end

local function onThrowGrenade(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin or not canUseInput() then
		return Enum.ContextActionResult.Pass
	end
	if (player:GetAttribute("Grenades") or 0) <= 0 then
		return Enum.ContextActionResult.Sink
	end

	local now = os.clock()
	if now - lastLocalThrow < Constants.GRENADE_THROW_COOLDOWN then
		return Enum.ContextActionResult.Sink
	end
	local direction = getAimDirection()
	if not direction then
		return Enum.ContextActionResult.Pass
	end

	lastLocalThrow = now
	throwEvent:FireServer(direction)
	WeaponFeedback.Fire("Grenade")
	return Enum.ContextActionResult.Sink
end

local function onMelee(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin or not canUseInput() then
		return Enum.ContextActionResult.Pass
	end

	local now = os.clock()
	if now - lastLocalMelee < Constants.MELEE_COOLDOWN then
		return Enum.ContextActionResult.Sink
	end
	local direction = getAimDirection()
	if not direction then
		return Enum.ContextActionResult.Pass
	end

	lastLocalMelee = now
	meleeEvent:FireServer(direction)
	WeaponFeedback.Fire("Melee")
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("ThrowGrenade", onThrowGrenade, true, Enum.KeyCode.G, Enum.KeyCode.ButtonL1)
ContextActionService:SetTitle("ThrowGrenade", "GRENADE")
ContextActionService:SetPosition("ThrowGrenade", UDim2.new(1, -190, 1, -210))

ContextActionService:BindAction("MeleeAttack", onMelee, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR3)
ContextActionService:SetTitle("MeleeAttack", "MELEE")
ContextActionService:SetPosition("MeleeAttack", UDim2.new(1, -95, 1, -285))
