-- Warm Tribes sunset atmosphere for the live CTF arena.
-- Low golden sun, peach horizon haze and saturated grass — the classic
-- Starsiege: Tribes "evening on the hills" mood. TribesSunset.server.lua adds
-- the giant moon, acacia trees and the warm re-skin on top of this.

local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

Lighting.ClockTime = 17.55            -- low golden-hour sun
Lighting.Brightness = 2.85
-- Ground light stays fairly NEUTRAL so grass reads green; only the sky/horizon is
-- orange. Warm outdoor ambient was washing the whole landscape to desert sand.
Lighting.Ambient = Color3.fromRGB(78, 78, 70)
Lighting.OutdoorAmbient = Color3.fromRGB(140, 146, 120)
Lighting.ColorShift_Top = Color3.fromRGB(255, 176, 112)
Lighting.ColorShift_Bottom = Color3.fromRGB(80, 44, 30)
Lighting.EnvironmentDiffuseScale = 0.85
Lighting.EnvironmentSpecularScale = 0.7
Lighting.ExposureCompensation = 0.12
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.55
Lighting.GeographicLatitude = 24

-- Legacy fog stays subtle and warm; the heavy horizon haze is the Atmosphere.
Lighting.FogColor = Color3.fromRGB(232, 156, 108)
Lighting.FogStart = 620
Lighting.FogEnd = 6000

for _, name in { "TribesAtmosphere", "TribesBloom", "TribesGrade", "TribesSunRays", "TribesDepth" } do
	local previous = Lighting:FindFirstChild(name)
	if previous then
		previous:Destroy()
	end
end

-- Peach horizon haze — the single most recognisable part of the Tribes look:
-- distant hills melt into a warm orange band while nearer ground stays saturated.
local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "TribesAtmosphere"
-- Lighter density + haze kept at the HORIZON (high Offset) so distant hills melt
-- into orange but the grass near the player stays saturated and green.
atmosphere.Density = 0.24
atmosphere.Offset = 0.42
atmosphere.Color = Color3.fromRGB(240, 168, 120)
atmosphere.Decay = Color3.fromRGB(158, 82, 58)
atmosphere.Glare = 0.28
atmosphere.Haze = 1.7
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Name = "TribesBloom"
bloom.Intensity = 0.4
bloom.Size = 40
bloom.Threshold = 1.15
bloom.Parent = Lighting

-- Warm grade: push the orange/green contrast the sunset screenshots have.
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "TribesGrade"
grade.Brightness = 0.01
grade.Contrast = 0.12
grade.Saturation = 0.2                      -- pop the green AND the orange sky
grade.TintColor = Color3.fromRGB(250, 243, 231)  -- near-neutral (was heavily warm)
grade.Parent = Lighting

local sunRays = Instance.new("SunRaysEffect")
sunRays.Name = "TribesSunRays"
sunRays.Intensity = 0.12
sunRays.Spread = 1.0
sunRays.Parent = Lighting

local depth = Instance.new("DepthOfFieldEffect")
depth.Name = "TribesDepth"
depth.FarIntensity = 0.14
depth.FocusDistance = 260
depth.InFocusRadius = 200
depth.NearIntensity = 0
depth.Parent = Lighting

local terrain = workspace:FindFirstChildOfClass("Terrain")
if terrain then
	local previousClouds = terrain:FindFirstChild("TribesClouds")
	if previousClouds then
		previousClouds:Destroy()
	end

	-- Streaky, warm-lit sunset clouds drifting over the ridgelines.
	local clouds = Instance.new("Clouds")
	clouds.Name = "TribesClouds"
	clouds.Cover = 0.62
	clouds.Density = 0.34
	clouds.Color = Color3.fromRGB(255, 206, 168)
	clouds.Parent = terrain
end

SoundService.AmbientReverb = Enum.ReverbType.Plain
SoundService.DistanceFactor = 3.33
SoundService.DopplerScale = 1.15

print("[WorldEnvironment] warm Tribes sunset atmosphere active")
