-- Accepts Studio Importer's default Add-to-Workspace result and moves all
-- recognized Blender arsenal models into the runtime discovery folder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ASSET_NAMES = {
	"Pathfinder_LightSpinfusor", "Pathfinder_LightAssaultRifle", "Pathfinder_ImpactNitron",
	"Sentinel_NovaBlaster", "Sentinel_BXT1Rifle", "Sentinel_GrenadeXL",
	"Infiltrator_StealthSpinfusor", "Infiltrator_RhinoSMG", "Infiltrator_StickyGrenade",
	"Soldier_Spinfusor", "Soldier_AssaultRifle", "Soldier_APGrenade",
	"Technician_Thumper", "Technician_TCN4SMG", "Technician_TCNGrenade",
	"Raider_ARXBuster", "Raider_NJ5SMG", "Raider_EMPGrenade",
	"Juggernaut_HeavySpinfusor", "Juggernaut_X1LMG", "Juggernaut_HeavyAPGrenade",
	"Brute_BruteSpinfusor", "Brute_AutoShotgun", "Brute_FractalGrenade",
	"Doombringer_SaberLauncher", "Doombringer_Chaingun", "Doombringer_FragGrenade",
}

local weaponAssets = ReplicatedStorage:FindFirstChild("WeaponAssets")
if not weaponAssets then
	weaponAssets = Instance.new("Folder")
	weaponAssets.Name = "WeaponAssets"
	weaponAssets.Parent = ReplicatedStorage
end

local moved = 0
for _, assetName in ASSET_NAMES do
	if not weaponAssets:FindFirstChild(assetName, true) then
		local imported = workspace:FindFirstChild(assetName, true)
		if imported and (imported:IsA("Model") or imported:IsA("BasePart")) then
			imported.Parent = weaponAssets
			moved += 1
		end
	end
end

ReplicatedStorage:SetAttribute("ImportedWeaponsResolved", true)
print(string.format("[ImportedAssetOrganizer] %d fresh Blender arsenal models activated", moved))
