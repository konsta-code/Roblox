-- CameraShake.client.lua
-- Ablageort: StarterPlayer/StarterPlayerScripts
--
-- Trauma-basierter Kamera-Shake fuers Wucht-Feedback:
--   * kraeftig beim Getroffen-werden (skaliert mit Schaden)
--   * kraeftig beim Weggepuntet-werden (Knockback ueber MovementImpulse)
--   * kleiner Punch, wenn man selbst einen Treffer landet
-- Additiver, abklingender CFrame-Offset NACH dem Kamera-Update (RenderPriority
-- Camera + 1), damit die First-Person-Kamera nicht dauerhaft verzogen wird.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local damageFeedback = ReplicatedStorage:WaitForChild("DamageFeedback")
local movementImpulse = ReplicatedStorage:WaitForChild("MovementImpulse")

local MAX_ANGLE = math.rad(5)
local MAX_OFFSET = 0.55
local DECAY = 1.7 -- Trauma pro Sekunde

local trauma = 0
local function addTrauma(amount: number)
	trauma = math.clamp(trauma + amount, 0, 1)
end

-- DamageFeedback-Signatur (CombatService): (amount, isKill, kind, sourcePos?, award?)
damageFeedback.OnClientEvent:Connect(function(amount, _isKill, kind)
	if kind == "Taken" and typeof(amount) == "number" then
		addTrauma(math.clamp(amount / 90, 0.18, 0.7))
	elseif kind == "Hit" then
		addTrauma(0.07)
	end
end)

-- Weggepuntet werden (Knockback / Disc-Jump) laeuft ueber MovementImpulse.
movementImpulse.OnClientEvent:Connect(function(impulse)
	if typeof(impulse) == "Vector3" and impulse.Magnitude == impulse.Magnitude then
		addTrauma(math.clamp(impulse.Magnitude / 130, 0.1, 0.6))
	end
end)

-- Explosions-Wumms: JEDER nahe Einschlag schuettelt, nicht nur eigene Treffer.
-- Abstand ab Kamera (funktioniert auch tot/Spectate), quadratischer Falloff.
-- Tuning: EXPLOSION_TRAUMA = Staerke im Epizentrum, FALLOFF_MULT = ab
-- radius*MULT ist nichts mehr zu spueren. Das Event legt CombatService zur
-- Laufzeit an (nicht in default.project.json), daher WaitForChild mit Timeout
-- statt ewig zu haengen, falls ein alter Server-Snapshot laeuft.
local EXPLOSION_TRAUMA = 0.42
local EXPLOSION_FALLOFF_MULT = 3.5

task.spawn(function()
	local explosionFeedback = ReplicatedStorage:WaitForChild("ExplosionFeedback", 30)
	if not explosionFeedback or not explosionFeedback:IsA("RemoteEvent") then
		return
	end
	explosionFeedback.OnClientEvent:Connect(function(position, radius)
		if typeof(position) ~= "Vector3" or typeof(radius) ~= "number" or radius <= 0 then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local distance = (camera.CFrame.Position - position).Magnitude
		local falloff = 1 - math.clamp(distance / (radius * EXPLOSION_FALLOFF_MULT), 0, 1)
		if falloff > 0 then
			addTrauma(EXPLOSION_TRAUMA * falloff * falloff)
		end
	end)
end)

RunService:BindToRenderStep("CameraShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if trauma <= 0 then
		return
	end
	trauma = math.max(0, trauma - dt * DECAY)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local shake = trauma * trauma -- quadratisch = knackiger Ausklang
	local seed = os.clock() * 42
	local rx = math.noise(seed, 0.0) * MAX_ANGLE * shake
	local ry = math.noise(0.0, seed) * MAX_ANGLE * shake
	local rz = math.noise(seed, seed) * MAX_ANGLE * 0.6 * shake
	local ox = math.noise(seed, 11.3) * MAX_OFFSET * shake
	local oy = math.noise(11.3, seed) * MAX_OFFSET * shake
	camera.CFrame = camera.CFrame * CFrame.new(ox, oy, 0) * CFrame.Angles(rx, ry, rz)
end)
