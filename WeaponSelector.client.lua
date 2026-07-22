-- WeaponSelector.client.lua
-- Simple loadout selection: 1 = Spinfusor, 2 = Chaingun.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local function equip(name: string)
	player:SetAttribute("EquippedWeapon", name)
	print(string.format("[Weapon] equipped %s", name))
end

equip("Spinfusor")

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.One then
		equip("Spinfusor")
	elseif input.KeyCode == Enum.KeyCode.Two then
		equip("Chaingun")
	end
end)
