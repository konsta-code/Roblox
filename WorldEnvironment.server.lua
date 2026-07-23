-- Cohesive alpine-canyon lighting and atmosphere for the live Tribes arena.

local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

Lighting.ClockTime = 13.8
Lighting.Brightness = 2.35
Lighting.Ambient = Color3.fromRGB(82, 95, 116)
Lighting.OutdoorAmbient = Color3.fromRGB(142, 157, 178)
Lighting.ColorShift_Top = Color3.fromRGB(13, 21, 34)
Lighting.EnvironmentDiffuseScale = 0.72
Lighting.EnvironmentSpecularScale = 0.78
Lighting.ExposureCompensation = 0.08
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.42
Lighting.FogColor = Color3.fromRGB(181, 201, 218)
Lighting.FogStart = 620
Lighting.FogEnd = 1900
Lighting.GeographicLatitude = 38

for _, name in { "TribesAtmosphere", "TribesBloom", "TribesGrade", "TribesSunRays", "TribesDepth" } do
	local previous = Lighting:FindFirstChild(name)
	if previous then
		previous:Destroy()
	end
end

local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "TribesAtmosphere"
atmosphere.Density = 0.19
atmosphere.Offset = 0.12
atmosphere.Color = Color3.fromRGB(206, 222, 235)
atmosphere.Decay = Color3.fromRGB(92, 116, 145)
atmosphere.Glare = 0.12
atmosphere.Haze = 1.05
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Name = "TribesBloom"
bloom.Intensity = 0.28
bloom.Size = 34
bloom.Threshold = 1.45
bloom.Parent = Lighting

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "TribesGrade"
grade.Brightness = 0.015
grade.Contrast = 0.11
grade.Saturation = -0.08
grade.TintColor = Color3.fromRGB(232, 240, 248)
grade.Parent = Lighting

local sunRays = Instance.new("SunRaysEffect")
sunRays.Name = "TribesSunRays"
sunRays.Intensity = 0.055
sunRays.Spread = 0.82
sunRays.Parent = Lighting

local depth = Instance.new("DepthOfFieldEffect")
depth.Name = "TribesDepth"
depth.FarIntensity = 0.11
depth.FocusDistance = 240
depth.InFocusRadius = 185
depth.NearIntensity = 0
depth.Parent = Lighting

local terrain = workspace:FindFirstChildOfClass("Terrain")
if terrain then
	local previousClouds = terrain:FindFirstChild("TribesClouds")
	if previousClouds then
		previousClouds:Destroy()
	end

	local clouds = Instance.new("Clouds")
	clouds.Name = "TribesClouds"
	clouds.Cover = 0.38
	clouds.Density = 0.28
	clouds.Color = Color3.fromRGB(224, 233, 241)
	clouds.Parent = terrain
end

SoundService.AmbientReverb = Enum.ReverbType.Mountains
SoundService.DistanceFactor = 3.33
SoundService.DopplerScale = 1.15

print("[WorldEnvironment] alpine canyon atmosphere active")
