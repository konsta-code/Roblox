-- SkiController.client.lua
-- Ablageort: StarterPlayerScripts/SkiController (LocalScript)
--
-- Client-treibt-Velocity-Controller: Humanoid bleibt für Rig/Animation/Health,
-- die eigentliche Bewegung läuft komplett über AssemblyLinearVelocity auf dem
-- RootPart. Roblox' Physik-Engine übernimmt weiterhin Kollisionsauflösung
-- gegen Wände/Rampen/Treppen - wir berechnen nur die gewünschte Velocity.
--
-- WalkSpeed wird in setupCharacter() auf 0 gesetzt, das neutralisiert das
-- Standard-PlayerModule (StarterPlayerScripts.PlayerModule.ControlModule),
-- ohne es anzufassen - siehe Kommentar dort für Details. Kein separater
-- Einbau-Schritt mehr nötig.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.MovementConstants)
local PlayerHudState = require(ReplicatedStorage.Modules.PlayerHudState)

local player = Players.LocalPlayer

local character: Model
local humanoid: Humanoid
local rootPart: BasePart

local State = {
	velocity = Vector3.zero,
	isGrounded = false,
	groundNormal = Vector3.yAxis,
	isSkiing = false,
	jetpackEnergy = Constants.JETPACK_MAX_ENERGY,
	lastThrustTime = 0,
}

local Input = {
	moveVector = Vector3.zero, -- kamera-relativ, XZ-Ebene
	jumpHeld = false,
	jetpackHeld = false,
}

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function setupCharacter(newCharacter: Model)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	-- Custom-Movement übernimmt die Kontrolle, Standard-Humanoid nur für
	-- Animation/Health/Kollisionsform behalten. WalkSpeed = 0 ist der
	-- eigentliche Trick gegen das Standard-PlayerModule (StarterPlayerScripts.
	-- PlayerModule.ControlModule): es läuft technisch weiter und ruft weiter
	-- Humanoid:Move() auf, aber bei WalkSpeed 0 hat das keine Wirkung mehr -
	-- nur noch dieser Controller bewegt den Character. Robuster als das
	-- ControlModule selbst zu löschen/umzubauen, und funktioniert identisch
	-- für Keyboard/Gamepad/Touch, ohne dass man jede Eingabemethode einzeln
	-- anfassen muss.
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	groundParams.FilterDescendantsInstances = { character }

	-- Reset bei Respawn, sonst startet man mit Velocity/Energie vom Tod
	State.velocity = Vector3.zero
	State.jetpackEnergy = Constants.JETPACK_MAX_ENERGY
end

setupCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(setupCharacter)

-- === Input ===

local function updateMoveVector()
	local cam = workspace.CurrentCamera
	if not cam then return end

	local forward = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	local right = cam.CFrame.RightVector * Vector3.new(1, 0, 1)
	local moveVector = Vector3.zero

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector += forward end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector -= forward end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector += right end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector -= right end

	Input.moveVector = moveVector.Magnitude > 0 and moveVector.Unit or Vector3.zero
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Space then
		Input.jumpHeld = true
		-- Einmaliger Impuls beim Drücken (nicht bei jedem Heartbeat solange
		-- gehalten) - sonst würde man dauerhaft nach oben beschleunigen.
		-- Nicht auslösen, während schon geskied wird: Space hält dann die
		-- Ski-Bedingung, soll aber keinen zusätzlichen Sprung auslösen.
		if State.isGrounded and not State.isSkiing then
			State.velocity = Vector3.new(State.velocity.X, Constants.JUMP_POWER, State.velocity.Z)
		end
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then Input.jetpackHeld = true end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then Input.jumpHeld = false end
	if input.KeyCode == Enum.KeyCode.LeftShift then Input.jetpackHeld = false end
end)

-- === Ground Detection ===

local function checkGround(): (boolean, Vector3)
	local result = workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -Constants.GROUND_CHECK_DISTANCE, 0),
		groundParams
	)
	if result then
		return true, result.Normal
	end
	return false, Vector3.yAxis
end

-- === Ski-Physik ===

local function applySkiPhysics(dt: number)
	local slopeAngle = math.deg(math.acos(math.clamp(State.groundNormal:Dot(Vector3.yAxis), -1, 1)))
	local isSkiing = Input.jumpHeld and slopeAngle > Constants.SKI_MIN_SLOPE_ANGLE
	State.isSkiing = isSkiing

	-- Hangabtrieb entlang der Normalen - beschleunigt bergab, unabhängig von Input.
	-- Der horizontale Anteil der Normalen zeigt bereits hangabwärts (die Normale
	-- kippt vom Hang weg, also zur tieferen Seite); kein zusätzliches Minus nötig
	-- - das hatte hier vorher die Richtung umgedreht (bergauf statt bergab).
	local slopeForce = Vector3.new(State.groundNormal.X, 0, State.groundNormal.Z) * Constants.GRAVITY
	local horizontalVel = Vector3.new(State.velocity.X, 0, State.velocity.Z)

	if isSkiing then
		-- Momentum-erhaltend: Reibung ~0, Input steuert nur sanft mit, Slope/
		-- Gravitation dominieren. inputForce bleibt hier bewusst eine
		-- Beschleunigung (* dt), nicht die Zielgeschwindigkeit selbst.
		local inputForce = Input.moveVector * (Constants.WALK_SPEED * 0.6)
		horizontalVel = horizontalVel:Lerp(Vector3.zero, math.clamp(Constants.SKI_GROUND_FRICTION * dt, 0, 1))
		horizontalVel += slopeForce * dt + inputForce * dt
	else
		-- Laufen: velocity folgt direkt der Zielgeschwindigkeit (WALK_SPEED),
		-- friction bestimmt nur wie schnell sie das tut - vorher wurde
		-- WALK_SPEED wie eine Beschleunigung behandelt, was die
		-- Gleichgewichts-Geschwindigkeit auf WALK_SPEED/WALK_GROUND_FRICTION
		-- gedrückt hat (2 Studs/s statt 16).
		local desiredVel = Input.moveVector * Constants.WALK_SPEED
		horizontalVel = horizontalVel:Lerp(desiredVel, math.clamp(Constants.WALK_GROUND_FRICTION * dt, 0, 1))
		horizontalVel += slopeForce * dt
	end

	if horizontalVel.Magnitude > Constants.MAX_SKI_SPEED then
		horizontalVel = horizontalVel.Unit * Constants.MAX_SKI_SPEED
	end

	-- Y bleibt erhalten statt hart auf 0: sonst würde ein gerade erst
	-- ausgelöster Sprung sofort wieder verschluckt, weil der Boden-Raycast
	-- (GROUND_CHECK_DISTANCE = 3.5 Studs) in den ersten paar Frames nach dem
	-- Absprung noch trifft und isGrounded weiter true meldet. Nach unten
	-- (Y <= 0, normales Stehen/Landen) trotzdem kappen, sonst würde sich
	-- Fallgeschwindigkeit auf unebenem Boden unbemerkt aufsummieren.
	local newY = State.velocity.Y > 0 and State.velocity.Y or 0
	State.velocity = Vector3.new(horizontalVel.X, newY, horizontalVel.Z)
end

-- === Blickrichtung ===
-- AutoRotate ist aus (siehe setupCharacter), also übernimmt das hier komplett:
-- RootPart dreht sich auf die horizontale Kamera-Blickrichtung, Position
-- bleibt unangetastet - kollidiert nicht mit der velocity-getriebenen
-- Bewegung, weil nur die Rotation gesetzt wird, nicht die Position.

local function updateFacing()
	local cam = workspace.CurrentCamera
	if not cam then return end

	local look = cam.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.001 then return end

	rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + flatLook)
end

-- === Jetpack ===

local function applyJetpack(dt: number)
	local wantsThrust = Input.jetpackHeld and State.jetpackEnergy > 0

	if wantsThrust then
		State.velocity += Vector3.new(0, Constants.JETPACK_THRUST_FORCE * dt, 0)
		State.jetpackEnergy = math.max(0, State.jetpackEnergy - Constants.JETPACK_DRAIN_RATE * dt)
		State.lastThrustTime = os.clock()
	elseif os.clock() - State.lastThrustTime > Constants.JETPACK_REGEN_DELAY then
		State.jetpackEnergy = math.min(Constants.JETPACK_MAX_ENERGY, State.jetpackEnergy + Constants.JETPACK_REGEN_RATE * dt)
	end

	PlayerHudState.SetJetpackEnergy(State.jetpackEnergy)
end

-- === Main Loop ===

RunService.Heartbeat:Connect(function(dt)
	if not character.Parent or not rootPart.Parent then return end

	updateMoveVector()
	State.isGrounded, State.groundNormal = checkGround()

	if State.isGrounded and not Input.jetpackHeld then
		applySkiPhysics(dt)
	else
		-- Airborne: eigene Gravitation + reduzierte Luftkontrolle
		State.velocity += Vector3.new(0, -Constants.GRAVITY * dt, 0)
		State.velocity += Input.moveVector * (Constants.WALK_SPEED * 0.3) * dt
	end

	applyJetpack(dt)
	updateFacing()

	rootPart.AssemblyLinearVelocity = State.velocity
end)
