-- Cohesive alpine-canyon lighting and atmosphere for the live Tribes arena.

local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

Lighting.ClockTime = 16.4
Lighting.Brightness = 2.35
Lighting.Ambient = Color3.fromRGB(58, 70, 92)
Lighting.OutdoorAmbient = Color3.fromRGB(112, 126, 148)
Lighting.ColorShift_Top = Color3.fromRGB(18, 24, 35)
Lighting.EnvironmentDiffuseScale = 0.48
Lighting.EnvironmentSpecularScale = 0.82
Lighting.ExposureCompensation = 0.08
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.28
Lighting.FogColor = Color3.fromRGB(151, 174, 197)
Lighting.FogStart = 650
Lighting.FogEnd = 1850

for _, name in { "TribesAtmosphere", "TribesBloom", "TribesGrade", "TribesSunRays" } do
	local previous = Lighting:FindFirstChild(name)
	if previous then
		previous:Destroy()
	end
end

local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "TribesAtmosphere"
atmosphere.Density = 0.27
atmosphere.Offset = 0.08
atmosphere.Color = Color3.fromRGB(186, 207, 226)
atmosphere.Decay = Color3.fromRGB(80, 101, 130)
atmosphere.Glare = 0.16
atmosphere.Haze = 1.55
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Name = "TribesBloom"
bloom.Intensity = 0.22
bloom.Size = 34
bloom.Threshold = 1.45
bloom.Parent = Lighting

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "TribesGrade"
grade.Brightness = 0.015
grade.Contrast = 0.11
grade.Saturation = -0.06
grade.TintColor = Color3.fromRGB(225, 236, 248)
grade.Parent = Lighting

local sunRays = Instance.new("SunRaysEffect")
sunRays.Name = "TribesSunRays"
sunRays.Intensity = 0.055
sunRays.Spread = 0.82
sunRays.Parent = Lighting

local terrain = workspace:FindFirstChildOfClass("Terrain")
if terrain then
	local previousClouds = terrain:FindFirstChild("TribesClouds")
	if previousClouds then
		previousClouds:Destroy()
	end

	local clouds = Instance.new("Clouds")
	clouds.Name = "TribesClouds"
	clouds.Cover = 0.32
	clouds.Density = 0.22
	clouds.Color = Color3.fromRGB(224, 233, 241)
	clouds.Parent = terrain
end

SoundService.AmbientReverb = Enum.ReverbType.Mountains
SoundService.DistanceFactor = 3.33
SoundService.DopplerScale = 1.15

print("[WorldEnvironment] alpine canyon atmosphere active")
