-- Activates the segmented Blender environment after its FBX modules have
-- been imported under ReplicatedStorage/MapAssets. MapBuilder always remains
-- responsible for gameplay collision, flags, stations and other tagged parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MODULES = {
	{ name = "Titan_CoreRoute", pivot = Vector3.new(0, 0, 0) },
	{ name = "Titan_NorthFlank", pivot = Vector3.new(0, 20, -250) },
	{ name = "Titan_SouthFlank", pivot = Vector3.new(0, 20, 250) },
	{ name = "Titan_RedCitadel", pivot = Vector3.new(-570, 24, 0) },
	{ name = "Titan_BlueCitadel", pivot = Vector3.new(570, 24, 0) },
	{ name = "Titan_WestGlacierVault", pivot = Vector3.new(-255, 2, -250) },
	{ name = "Titan_EastGlacierVault", pivot = Vector3.new(255, 2, 250) },
	{ name = "Titan_CanyonBackdrop", pivot = Vector3.new(0, 0, 0) },
}

local assetFolder = ReplicatedStorage:FindFirstChild("MapAssets")
local templates = {}
local missing = {}
for _, definition in MODULES do
	local template = assetFolder and assetFolder:FindFirstChild(definition.name, true)
	if template and (template:IsA("Model") or template:IsA("BasePart")) then
		templates[definition.name] = template
	else
		table.insert(missing, definition.name)
	end
end

if #missing > 0 then
	workspace:SetAttribute("TitanImportedArtReady", false)
	workspace:SetAttribute("TitanImportedArtResolved", true)
	print(string.format("[ImportedMapLoader] native fallback active; %d/8 Blender modules missing", #missing))
	return
end

local previous = workspace:FindFirstChild("ImportedMap")
if previous then previous:Destroy() end
local importedRoot = Instance.new("Folder")
importedRoot.Name = "ImportedMap"
importedRoot.Parent = workspace
local titan = Instance.new("Folder")
titan.Name = "TitanAlpine"
titan.Parent = importedRoot

local function configurePart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Massless = true
end

for _, definition in MODULES do
	local clone = templates[definition.name]:Clone()
	clone.Name = definition.name
	clone.Parent = titan
	if clone:IsA("BasePart") then
		configurePart(clone)
		clone.CFrame = CFrame.new(definition.pivot)
	else
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") then configurePart(descendant) end
		end
		local origin = clone:FindFirstChild("__PIVOT_" .. string.gsub(definition.name, "Titan_", ""), true)
		if origin and origin:IsA("BasePart") then
			local delta = CFrame.new(definition.pivot) * origin.CFrame:Inverse()
			clone:PivotTo(delta * clone:GetPivot())
			origin:Destroy()
		else
			clone:PivotTo(CFrame.new(definition.pivot))
			warn("[ImportedMapLoader] origin marker missing for " .. definition.name .. "; model pivot used")
		end
	end
end

workspace:SetAttribute("TitanImportedArtReady", true)
workspace:SetAttribute("TitanImportedArtResolved", true)
print("[ImportedMapLoader] 8/8 Blender Titan modules active")
