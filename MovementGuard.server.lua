-- MovementGuard.server.lua
-- A final server-side sanity boundary. Normal skiing and disc jumps fit well
-- below this limit; malformed or exploit-created velocities do not.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Modules.MovementConstants)
local accumulator = 0

local function isFinite(vector: Vector3): boolean
	return vector.X == vector.X and vector.Y == vector.Y and vector.Z == vector.Z
end

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.1 then return end
	accumulator = 0

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local velocity = root.AssemblyLinearVelocity
			if not isFinite(velocity) then
				root.AssemblyLinearVelocity = Vector3.zero
			elseif velocity.Magnitude > Constants.SERVER_MAX_LINEAR_SPEED then
				root.AssemblyLinearVelocity = velocity.Unit * Constants.SERVER_MAX_LINEAR_SPEED
			end
		end
	end
end)
