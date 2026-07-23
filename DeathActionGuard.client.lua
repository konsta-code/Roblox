-- Hard local action gate between Humanoid.Died and the next CharacterAdded.
-- This deliberately sits above individual weapon scripts so a held automatic
-- fire input cannot survive death due to event ordering.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponState = require(ReplicatedStorage.Modules.WeaponState)
local player = Players.LocalPlayer

local ACTION_NAME = "DeadCombatActionLock"
local BLOCK_PRIORITY = Enum.ContextActionPriority.High.Value + 100

local function sinkAction(): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

local function setDeadLocked(locked: boolean)
	player:SetAttribute("LocalCombatDead", locked)
	WeaponState.SetPrimaryDown(false)
	if locked then
		ContextActionService:BindActionAtPriority(
			ACTION_NAME,
			sinkAction,
			false,
			BLOCK_PRIORITY,
			Enum.UserInputType.MouseButton1,
			Enum.UserInputType.MouseButton2,
			Enum.KeyCode.ButtonR2,
			Enum.KeyCode.ButtonR1,
			Enum.KeyCode.ButtonL2,
			Enum.KeyCode.ButtonL1,
			Enum.KeyCode.ButtonX,
			Enum.KeyCode.One,
			Enum.KeyCode.Two,
			Enum.KeyCode.G,
			Enum.KeyCode.F,
			Enum.KeyCode.Q,
			Enum.KeyCode.C,
			Enum.KeyCode.V,
			Enum.KeyCode.Z
		)
	else
		ContextActionService:UnbindAction(ACTION_NAME)
	end
end

local function bindCharacter(character: Model)
	setDeadLocked(false)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if humanoid.Health <= 0 then
		setDeadLocked(true)
		return
	end
	humanoid.Died:Connect(function()
		if player.Character == character then
			setDeadLocked(true)
		end
	end)
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then bindCharacter(player.Character) end
