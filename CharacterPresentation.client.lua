-- Hide the local replicated armor/third-person gun when the camera is inside
-- the character. Other players always retain the full presentation.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local accumulator = 0

-- Production remains a first-person game. Studio playtests may zoom out so
-- artists can inspect the faction silhouette and its movement on the R15 rig.
if RunService:IsStudio() then
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 18
end

RunService.RenderStepped:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.08 then return end
	accumulator = 0
	local camera = workspace.CurrentCamera
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local presentation = character and character:FindFirstChild("CTFCharacterPresentation")
	if not camera or not head or not head:IsA("BasePart") or not presentation then return end
	local firstPerson = (camera.CFrame.Position - head.Position).Magnitude < 1.35
	for _, descendant in presentation:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = firstPerson and 1 or 0
		end
	end
end)
