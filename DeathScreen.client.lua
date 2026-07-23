-- DeathScreen.client.lua
-- Ablageort: StarterPlayerScripts
--
-- Beim Tod: dunkle Vignette + "GEFALLEN" + Respawn-Countdown, verschwindet
-- automatisch beim nächsten Spawn. Ersetzt den bisherigen kommentarlosen
-- Schnitt und gibt dem Klassenwechsel-Moment Raum (Hinweis auf L, weil die
-- vorgemerkte Klasse genau jetzt greift).

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "DeathScreen"
gui.ResetOnSpawn = false
gui.DisplayOrder = 40
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local vignette = Instance.new("Frame")
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundColor3 = Color3.fromRGB(8, 4, 6)
vignette.BackgroundTransparency = 0.35
vignette.BorderSizePixel = 0
vignette.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 64)
title.Position = UDim2.new(0, 0, 0.36, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 44
title.TextColor3 = Color3.fromRGB(255, 96, 88)
title.TextStrokeColor3 = Color3.fromRGB(10, 6, 8)
title.TextStrokeTransparency = 0.4
title.Text = "GEFALLEN"
title.Parent = vignette

local countdown = Instance.new("TextLabel")
countdown.Size = UDim2.new(1, 0, 0, 30)
countdown.Position = UDim2.new(0, 0, 0.36, 66)
countdown.BackgroundTransparency = 1
countdown.Font = Enum.Font.GothamBold
countdown.TextSize = 19
countdown.TextColor3 = Color3.fromRGB(226, 233, 244)
countdown.Text = ""
countdown.Parent = vignette

local recap = Instance.new("TextLabel")
recap.Size = UDim2.new(1, 0, 0, 34)
recap.Position = UDim2.new(0, 0, 0.36, 98)
recap.BackgroundTransparency = 1
recap.Font = Enum.Font.GothamBold
recap.TextSize = 16
recap.TextColor3 = Color3.fromRGB(255, 196, 116)
recap.Text = "KAMPFDATEN WERDEN GELADEN ..."
recap.Parent = vignette

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, 0, 0, 22)
hint.Position = UDim2.new(0, 0, 0.36, 138)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 14
hint.TextColor3 = Color3.fromRGB(160, 172, 190)
hint.Text = "[L]  Klasse für den nächsten Spawn wählen"
hint.Parent = vignette

local countdownThread: thread? = nil

local function updateDeathRecap()
	local killerName = player:GetAttribute("LastKillerName")
	local weapon = player:GetAttribute("LastDeathWeapon")
	local distance = player:GetAttribute("LastDeathDistance")
	local killerUserId = player:GetAttribute("LastKillerUserId")
	recap.Text = string.format(
		"ELIMINIERT VON %s  //  %s%s",
		string.upper(typeof(killerName) == "string" and killerName or "UMGEBUNG"),
		string.upper(typeof(weapon) == "string" and weapon or "UMGEBUNG"),
		typeof(distance) == "number" and distance > 0 and string.format("  //  %dm", distance) or ""
	)

	if typeof(killerUserId) == "number" and killerUserId > 0 then
		local killer = Players:GetPlayerByUserId(killerUserId)
		local killerHumanoid = killer and killer.Character and killer.Character:FindFirstChildOfClass("Humanoid")
		local camera = workspace.CurrentCamera
		if killerHumanoid and killerHumanoid.Health > 0 and camera then
			player.CameraMode = Enum.CameraMode.Classic
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = killerHumanoid
		end
	end
end

local function onDied()
	if countdownThread then
		task.cancel(countdownThread)
	end
	gui.Enabled = true
	local camera = workspace.CurrentCamera
	if camera then camera.FieldOfView = 70 end
	player:SetAttribute("WeaponZoomFov", nil)
	recap.Text = "KAMPFDATEN WERDEN GELADEN ..."
	task.delay(0.15, function()
		if gui.Enabled then
			updateDeathRecap()
		end
	end)
	countdownThread = task.spawn(function()
		local remaining = Players.RespawnTime
		while remaining > 0 do
			countdown.Text = string.format("Respawn in %.0f ...", math.max(1, math.ceil(remaining)))
			task.wait(0.25)
			remaining -= 0.25
		end
		countdown.Text = "Respawn ..."
		countdownThread = nil
	end)
end

local function bindCharacter(character: Model)
	-- Neuer Charakter = wieder im Spiel: Overlay weg.
	gui.Enabled = false
	if countdownThread then
		task.cancel(countdownThread)
		countdownThread = nil
	end

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end
	humanoid.Died:Connect(onDied)
end

player:GetAttributeChangedSignal("LastDeathTime"):Connect(function()
	if gui.Enabled then
		updateDeathRecap()
	end
end)

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	bindCharacter(player.Character)
end
