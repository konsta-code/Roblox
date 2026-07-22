-- FlagMarkers.client.lua
-- Ablageort: StarterPlayerScripts
--
-- Weltmarker über beiden Flaggen (BillboardGui, durch Wände sichtbar):
-- Teamfarbe, Status und Live-Distanz. Ohne die Marker weiß in CTF niemand,
-- wohin er skien soll - mit ihnen liest sich die Map auf einen Blick:
--   "⚑ RED"            Flagge steht an der Basis
--   "⚑ RED · GETRAGEN" ein Gegner/Mitspieler trägt sie gerade
--   "⚑ RED · LIEGT!"   gedroppt, holbar
-- Findet die Flaggen über den CollectionService-Tag "CTFFlag" (CTFManager
-- vergibt ihn beim Erstellen); der Marker hängt an der Flagge selbst und
-- überlebt damit das Reparenting beim Aufheben/Tragen.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FLAG_TAG = "CTFFlag"
local player = Players.LocalPlayer
local teamPingEvent = ReplicatedStorage:WaitForChild("TeamPing") :: RemoteEvent

-- home = Position beim Erstellen (CTFManager spawnt die Flagge exakt auf dem
-- Stand). Nötig, um "an der Basis" von "gedroppt" zu unterscheiden - beide
-- Zustände sind verankert und liegen in workspace, nur die Position verrät es.
type Marker = { gui: BillboardGui, label: TextLabel, flag: BasePart, home: Vector3 }
local markers: { [BasePart]: Marker } = {}

local function attachMarker(flag: Instance)
	if not flag:IsA("BasePart") or markers[flag] then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "FlagMarker"
	gui.Size = UDim2.fromOffset(210, 38)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 1000
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(7, 11, 17)
	label.BackgroundTransparency = 0.42
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 14
	label.TextColor3 = flag.Color
	label.TextStrokeColor3 = Color3.fromRGB(8, 10, 14)
	label.TextStrokeTransparency = 0.25
	label.Text = ""
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = flag.Color
	stroke.Transparency = 0.5
	stroke.Thickness = 1
	stroke.Parent = label

	gui.Parent = flag
	markers[flag] = { gui = gui, label = label, flag = flag, home = flag.Position }
end

local function detachMarker(flag: Instance)
	local marker = markers[flag :: BasePart]
	if marker then
		marker.gui:Destroy()
		markers[flag :: BasePart] = nil
	end
end

CollectionService:GetInstanceAddedSignal(FLAG_TAG):Connect(attachMarker)
CollectionService:GetInstanceRemovedSignal(FLAG_TAG):Connect(detachMarker)
for _, flag in CollectionService:GetTagged(FLAG_TAG) do
	attachMarker(flag)
end

-- Statustext + Distanz. Drosselung auf ~7 Updates/s reicht völlig und hält
-- den RenderStep frei; bei 2 Flaggen ohnehin trivial billig.
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.15 then
		return
	end
	accumulator = 0

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	for flag, marker in markers do
		if not flag.Parent then
			continue -- Removed-Signal räumt gleich auf
		end

		local teamName = string.upper(string.gsub(flag.Name, "Flag$", ""))
		local replicatedState = flag:GetAttribute("FlagState")
		if typeof(replicatedState) == "string" then
			local status = ""
			if replicatedState == "Carried" then
				local carrierName = flag:GetAttribute("CarrierName")
				status = if carrierName == player.Name then "DU TRAEGST SIE" else "GETRAGEN"
				marker.label.BackgroundTransparency = 0.2
				marker.label.TextColor3 = flag.Color
				marker.label.TextTransparency = 0
			elseif replicatedState == "Dropped" then
				local returnTime = flag:GetAttribute("ReturnTime")
				status = string.format("LIEGT - %ds", if typeof(returnTime) == "number" then returnTime else 0)
				marker.label.BackgroundTransparency = 0.08
				marker.label.TextColor3 = Color3.fromRGB(255, 205, 92)
				marker.label.TextTransparency = 0.08 + math.abs(math.sin(os.clock() * 4.5)) * 0.2
			else
				marker.label.BackgroundTransparency = 0.42
				marker.label.TextColor3 = flag.Color
				marker.label.TextTransparency = 0
			end

			local distanceText = ""
			if root and root:IsA("BasePart") then
				distanceText = string.format("  %dm", math.floor((flag.Position - root.Position).Magnitude / 3.57))
			end
			marker.label.Text = if status == ""
				then string.format("FLAG %s%s", teamName, distanceText)
				else string.format("FLAG %s // %s%s", teamName, status, distanceText)
			continue
		end
		local status: string
		local carrierModel = flag.Parent
		if carrierModel and carrierModel:IsA("Model") and Players:GetPlayerFromCharacter(carrierModel) then
			local carrier = Players:GetPlayerFromCharacter(carrierModel)
			status = if carrier == player then "DU TRÄGST SIE" else "GETRAGEN"
		elseif (flag.Position - marker.home).Magnitude > 6 then
			status = "LIEGT!"
		else
			status = ""
		end

		local distanceText = ""
		if root and root:IsA("BasePart") then
			distanceText = string.format("  %dm", math.floor((flag.Position - root.Position).Magnitude / 3.57))
		end

		marker.label.Text = if status == ""
			then string.format("⚑ %s%s", teamName, distanceText)
			else string.format("⚑ %s · %s%s", teamName, status, distanceText)
	end
end)

-- === TACTICAL RADAR ===
-- Statische Nordausrichtung: X ist Basis-zu-Basis, Z ist Nord/Sued. Alle
-- Marker werden aus bereits replizierten Weltpositionen berechnet; Gegner
-- bleiben verborgen, damit das Radar kein Wallhack wird.

local radarGui = Instance.new("ScreenGui")
radarGui.Name = "TitanTacticalRadar"
radarGui.ResetOnSpawn = false
radarGui.IgnoreGuiInset = true
radarGui.DisplayOrder = 3
radarGui.Parent = player:WaitForChild("PlayerGui")

local radar = Instance.new("Frame")
radar.Name = "Radar"
radar.Size = UDim2.fromOffset(220, 154)
radar.AnchorPoint = Vector2.new(1, 1)
radar.Position = UDim2.new(1, -20, 1, -82)
radar.BackgroundColor3 = Color3.fromRGB(6, 11, 17)
radar.BackgroundTransparency = 0.14
radar.BorderSizePixel = 0
radar.Parent = radarGui
local radarCorner = Instance.new("UICorner")
radarCorner.CornerRadius = UDim.new(0, 9)
radarCorner.Parent = radar
local radarStroke = Instance.new("UIStroke")
radarStroke.Color = Color3.fromRGB(78, 110, 142)
radarStroke.Transparency = 0.38
radarStroke.Thickness = 1
radarStroke.Parent = radar

local radarHeader = Instance.new("TextLabel")
radarHeader.Size = UDim2.new(1, -12, 0, 25)
radarHeader.Position = UDim2.fromOffset(6, 1)
radarHeader.BackgroundTransparency = 1
radarHeader.Font = Enum.Font.GothamBlack
radarHeader.Text = "TITAN TACTICAL RADAR   [M]"
radarHeader.TextColor3 = Color3.fromRGB(183, 207, 230)
radarHeader.TextSize = 10
radarHeader.TextXAlignment = Enum.TextXAlignment.Left
radarHeader.Parent = radar

local radarMap = Instance.new("Frame")
radarMap.Name = "Map"
radarMap.Size = UDim2.new(1, -12, 1, -33)
radarMap.Position = UDim2.fromOffset(6, 27)
radarMap.BackgroundColor3 = Color3.fromRGB(13, 23, 34)
radarMap.BackgroundTransparency = 0.1
radarMap.BorderSizePixel = 0
radarMap.ClipsDescendants = true
radarMap.Parent = radar
local mapCorner = Instance.new("UICorner")
mapCorner.CornerRadius = UDim.new(0, 6)
mapCorner.Parent = radarMap

for index, zScale in { 0.12, 0.26, 0.5, 0.74, 0.88 } do
	local lane = Instance.new("Frame")
	lane.Name = "Lane" .. index
	lane.Size = UDim2.new(1, -12, 0, index == 3 and 2 or 1)
	lane.Position = UDim2.new(0, 6, 0, math.floor((154 - 33) * zScale))
	lane.BackgroundColor3 = if index == 3 then Color3.fromRGB(76, 154, 190) else Color3.fromRGB(67, 92, 116)
	lane.BackgroundTransparency = if index == 3 then 0.35 else 0.62
	lane.BorderSizePixel = 0
	lane.Parent = radarMap
end

for _, xScale in { 0.25, 0.5, 0.75 } do
	local grid = Instance.new("Frame")
	grid.Size = UDim2.new(0, 1, 1, -8)
	grid.Position = UDim2.new(xScale, 0, 0, 4)
	grid.BackgroundColor3 = Color3.fromRGB(64, 82, 102)
	grid.BackgroundTransparency = 0.76
	grid.BorderSizePixel = 0
	grid.Parent = radarMap
end

local function radarBaseLabel(text: string, xScale: number, color: Color3)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(42, 16)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(xScale, 0.5)
	label.BackgroundColor3 = color
	label.BackgroundTransparency = 0.42
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = Color3.fromRGB(245, 248, 252)
	label.TextSize = 9
	label.Parent = radarMap
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end

radarBaseLabel("RED", 0.13, Color3.fromRGB(195, 62, 60))
radarBaseLabel("BLUE", 0.87, Color3.fromRGB(58, 112, 205))

local function worldToRadar(position: Vector3): UDim2
	local x = math.clamp((position.X + 770) / 1540, 0.02, 0.98)
	local y = math.clamp((position.Z + 520) / 1040, 0.04, 0.96)
	return UDim2.fromScale(x, y)
end

local radarPlayerDots: { [Player]: GuiObject } = {}
local function createRadarPlayerDot(target: Player)
	if radarPlayerDots[target] then
		return
	end
	if target == player then
		local arrow = Instance.new("TextLabel")
		arrow.Name = "LocalPlayer"
		arrow.Size = UDim2.fromOffset(18, 18)
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.BackgroundTransparency = 1
		arrow.Font = Enum.Font.GothamBlack
		arrow.Text = "^"
		arrow.TextColor3 = Color3.fromRGB(255, 255, 255)
		arrow.TextSize = 16
		arrow.TextStrokeTransparency = 0.3
		arrow.ZIndex = 5
		arrow.Parent = radarMap
		radarPlayerDots[target] = arrow
	else
		local dot = Instance.new("Frame")
		dot.Name = "Ally"
		dot.Size = UDim2.fromOffset(7, 7)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = target.Team and target.Team.TeamColor.Color or Color3.fromRGB(105, 205, 255)
		dot.BorderSizePixel = 0
		dot.ZIndex = 4
		dot.Visible = false
		dot.Parent = radarMap
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot
		radarPlayerDots[target] = dot
	end
end

local function removeRadarPlayerDot(target: Player)
	local dot = radarPlayerDots[target]
	if dot then
		dot:Destroy()
		radarPlayerDots[target] = nil
	end
end

Players.PlayerAdded:Connect(createRadarPlayerDot)
Players.PlayerRemoving:Connect(removeRadarPlayerDot)
for _, target in Players:GetPlayers() do
	createRadarPlayerDot(target)
end

local radarBotDots: { [Model]: Frame } = {}
local function createRadarBotDot(instance: Instance)
	if not instance:IsA("Model") or radarBotDots[instance] then return end
	local dot = Instance.new("Frame")
	dot.Name = "Bot"
	dot.Size = UDim2.fromOffset(7, 7)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = instance:GetAttribute("BotTeam") == "Red"
		and Color3.fromRGB(220, 70, 65) or Color3.fromRGB(65, 135, 235)
	dot.BorderSizePixel = 0
	dot.Rotation = 45
	dot.ZIndex = 4
	dot.Visible = false
	dot.Parent = radarMap
	radarBotDots[instance] = dot
end

local function removeRadarBotDot(instance: Instance)
	if not instance:IsA("Model") then return end
	local dot = radarBotDots[instance]
	if dot then
		dot:Destroy()
		radarBotDots[instance] = nil
	end
end

CollectionService:GetInstanceAddedSignal("CTFBot"):Connect(createRadarBotDot)
CollectionService:GetInstanceRemovedSignal("CTFBot"):Connect(removeRadarBotDot)
for _, instance in CollectionService:GetTagged("CTFBot") do
	createRadarBotDot(instance)
end

type ObjectiveDot = { dot: Frame, part: BasePart }
local radarFlagDots: { [BasePart]: ObjectiveDot } = {}
local radarGeneratorDots: { [BasePart]: ObjectiveDot } = {}

local function makeObjectiveDot(part: Instance, registry: { [BasePart]: ObjectiveDot }, size: number, square: boolean)
	if not part:IsA("BasePart") or registry[part] then
		return
	end
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(size, size)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = part.Color
	dot.BorderSizePixel = 0
	dot.ZIndex = 3
	dot.Parent = radarMap
	if not square then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot
	end
	registry[part] = { dot = dot, part = part }
end

local function removeObjectiveDot(part: Instance, registry: { [BasePart]: ObjectiveDot })
	local entry = registry[part :: BasePart]
	if entry then
		entry.dot:Destroy()
		registry[part :: BasePart] = nil
	end
end

CollectionService:GetInstanceAddedSignal("CTFFlag"):Connect(function(part)
	makeObjectiveDot(part, radarFlagDots, 9, false)
end)
CollectionService:GetInstanceRemovedSignal("CTFFlag"):Connect(function(part)
	removeObjectiveDot(part, radarFlagDots)
end)
CollectionService:GetInstanceAddedSignal("PowerGenerator"):Connect(function(part)
	makeObjectiveDot(part, radarGeneratorDots, 7, true)
end)
CollectionService:GetInstanceRemovedSignal("PowerGenerator"):Connect(function(part)
	removeObjectiveDot(part, radarGeneratorDots)
end)
for _, part in CollectionService:GetTagged("CTFFlag") do
	makeObjectiveDot(part, radarFlagDots, 9, false)
end
for _, part in CollectionService:GetTagged("PowerGenerator") do
	makeObjectiveDot(part, radarGeneratorDots, 7, true)
end

local radarVisible = true
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.M then
		radarVisible = not radarVisible
		radar.Visible = radarVisible
	end
end)

local radarAccumulator = 0
local radarSightParams = RaycastParams.new()
radarSightParams.FilterType = Enum.RaycastFilterType.Exclude

local function hasBotLineOfSight(bot: Model, targetRoot: BasePart): boolean
	local camera = workspace.CurrentCamera
	local localCharacter = player.Character
	local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
	local origin = if camera then camera.CFrame.Position
		elseif localRoot and localRoot:IsA("BasePart") then localRoot.Position
		else nil
	if not origin then return false end
	local offset = targetRoot.Position - origin
	if offset.Magnitude <= 0.1 then return true end
	radarSightParams.FilterDescendantsInstances = if localCharacter then { localCharacter } else {}
	local result = workspace:Raycast(origin, offset, radarSightParams)
	return result ~= nil and result.Instance:IsDescendantOf(bot)
end

RunService.RenderStepped:Connect(function(dt)
	radarAccumulator += dt
	if radarAccumulator < 0.08 then
		return
	end
	radarAccumulator = 0
	if not radarVisible then
		return
	end

	for target, dot in radarPlayerDots do
		local character = target.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local isAlly = player.Team ~= nil and target.Team == player.Team
		local spotted = false
		if target ~= player and not isAlly and player.Team then
			local spottedUntil = target:GetAttribute("SpottedUntil_" .. player.Team.Name)
			spotted = typeof(spottedUntil) == "number" and spottedUntil > workspace:GetServerTimeNow()
		end
		local visible = root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0
			and (target == player or isAlly or spotted)
		dot.Visible = visible
		if visible and root and root:IsA("BasePart") then
			dot.Position = worldToRadar(root.Position)
			if target == player and dot:IsA("TextLabel") then
				local look = root.CFrame.LookVector
				dot.Rotation = math.deg(math.atan2(look.X, -look.Z))
			elseif dot:IsA("Frame") then
				local carrying = character:FindFirstChild("RedFlag") or character:FindFirstChild("BlueFlag")
				local dotSize = if carrying then 11 elseif spotted then 8 else 7
				dot.Size = UDim2.fromOffset(dotSize, dotSize)
				dot.BackgroundColor3 = if spotted and not isAlly
					then Color3.fromRGB(255, 89, 76)
					else target.Team and target.Team.TeamColor.Color or Color3.fromRGB(105, 205, 255)
			end
		end
	end

	local localRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for bot, dot in radarBotDots do
		local root = bot:FindFirstChild("HumanoidRootPart")
		local humanoid = bot:FindFirstChildOfClass("Humanoid")
		local botTeam = bot:GetAttribute("BotTeam")
		local isAlly = player.Team ~= nil and botTeam == player.Team.Name
		local nearby = localRoot and localRoot:IsA("BasePart") and root and root:IsA("BasePart")
			and (root.Position - localRoot.Position).Magnitude <= 220
		local visuallyConfirmed = nearby and root and root:IsA("BasePart") and hasBotLineOfSight(bot, root)
		local carrying = bot:FindFirstChild("RedFlag") or bot:FindFirstChild("BlueFlag")
		local visible = root and root:IsA("BasePart") and humanoid and humanoid.Health > 0
			and (isAlly or visuallyConfirmed or carrying ~= nil)
		dot.Visible = visible == true
		if visible and root and root:IsA("BasePart") then
			dot.Position = worldToRadar(root.Position)
			dot.Size = UDim2.fromOffset(carrying and 11 or 7, carrying and 11 or 7)
			dot.BackgroundColor3 = if botTeam == "Red"
				then Color3.fromRGB(220, 70, 65) else Color3.fromRGB(65, 135, 235)
		end
	end

	for _, entry in radarFlagDots do
		if entry.part.Parent then
			entry.dot.Position = worldToRadar(entry.part.Position)
			entry.dot.BackgroundColor3 = entry.part.Color
			entry.dot.Rotation = (entry.dot.Rotation + 18) % 360
		end
	end
	for _, entry in radarGeneratorDots do
		if entry.part.Parent then
			entry.dot.Position = worldToRadar(entry.part.Position)
			entry.dot.BackgroundColor3 = entry.part:GetAttribute("Powered") == false
				and Color3.fromRGB(255, 75, 68) or entry.part.Color
		end
	end
end)

-- === TEAM PINGS ===
local activeTeamPings: { { worldPart: BasePart, radarDot: Frame } } = {}
local defaultRadarHeader = radarHeader.Text
local pingHeaderSequence = 0

local function sendTeamPing()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = player.Character and { player.Character } or {}
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1200, params)
	local position = result and result.Position or (ray.Origin + ray.Direction * 600)
	teamPingEvent:FireServer(position)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.V or input.UserInputType == Enum.UserInputType.MouseButton3 then
		sendTeamPing()
	end
end)

teamPingEvent.OnClientEvent:Connect(function(
	senderName: string,
	position: Vector3,
	kind: string,
	expiresAt: number
)
	if typeof(senderName) ~= "string" or typeof(position) ~= "Vector3"
		or typeof(kind) ~= "string" or typeof(expiresAt) ~= "number" then
		return
	end

	while #activeTeamPings >= 6 do
		local oldest = table.remove(activeTeamPings, 1)
		oldest.worldPart:Destroy()
		oldest.radarDot:Destroy()
	end

	local color = player.Team and player.Team.TeamColor.Color or Color3.fromRGB(105, 220, 255)
	local worldPart = Instance.new("Part")
	worldPart.Name = "TeamPing"
	worldPart.Size = Vector3.new(0.6, 0.6, 0.6)
	worldPart.Position = position
	worldPart.Anchored = true
	worldPart.CanCollide = false
	worldPart.CanTouch = false
	worldPart.CanQuery = false
	worldPart.Transparency = 1
	worldPart.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PingMarker"
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 1000
	billboard.Parent = worldPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(7, 13, 20)
	label.BackgroundTransparency = 0.18
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.Text = string.format("PING // %s // %s", string.upper(senderName), kind)
	label.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
	label.TextSize = 14
	label.TextStrokeColor3 = Color3.fromRGB(3, 6, 9)
	label.TextStrokeTransparency = 0.35
	label.Parent = billboard
	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 7)
	labelCorner.Parent = label
	local scale = Instance.new("UIScale")
	scale.Parent = label
	scale.Scale = 0.72
	TweenService:Create(scale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local beam = Instance.new("Part")
	beam.Name = "PingBeam"
	beam.Size = Vector3.new(0.35, 18, 0.35)
	beam.CFrame = CFrame.new(position + Vector3.new(0, 9, 0))
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.2
	beam.Parent = worldPart

	local radarDot = Instance.new("Frame")
	radarDot.Name = "TeamPing"
	radarDot.Size = UDim2.fromOffset(10, 10)
	radarDot.AnchorPoint = Vector2.new(0.5, 0.5)
	radarDot.Position = worldToRadar(position)
	radarDot.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3)
	radarDot.BorderSizePixel = 0
	radarDot.Rotation = 45
	radarDot.ZIndex = 7
	radarDot.Parent = radarMap
	local dotScale = Instance.new("UIScale")
	dotScale.Parent = radarDot
	TweenService:Create(dotScale, TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Scale = 1.65,
	}):Play()

	local ping = { worldPart = worldPart, radarDot = radarDot }
	table.insert(activeTeamPings, ping)
	pingHeaderSequence += 1
	local headerSequence = pingHeaderSequence
	radarHeader.Text = string.format("%s // %s", string.upper(senderName), kind)
	radarHeader.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3)

	local tone = Instance.new("Sound")
	tone.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	tone.Volume = 0.42
	tone.PlaybackSpeed = 1.42
	tone.Parent = SoundService
	tone:Play()
	Debris:AddItem(tone, 2)

	local lifetime = math.max(0.1, expiresAt - workspace:GetServerTimeNow())
	task.delay(math.min(1.8, lifetime), function()
		if headerSequence == pingHeaderSequence then
			radarHeader.Text = defaultRadarHeader
			radarHeader.TextColor3 = Color3.fromRGB(183, 207, 230)
		end
	end)
	task.delay(lifetime, function()
		local index = table.find(activeTeamPings, ping)
		if index then
			table.remove(activeTeamPings, index)
		end
		worldPart:Destroy()
		radarDot:Destroy()
	end)
end)

-- === TEAM IFF ===
-- Freundmarker sind durch die riesige Arena sichtbar; Gegner erhalten bewusst
-- keinen Marker durch Waende. Ein einziges gedrosseltes Update versorgt Name,
-- Klasse, Distanz, Flaggenstatus und Lebensbalken.

type AllyMarker = {
	gui: BillboardGui,
	label: TextLabel,
	fill: Frame,
	target: Player,
	humanoid: Humanoid,
	root: BasePart,
}

local allyMarkers: { [Player]: AllyMarker } = {}

local function removeAllyMarker(target: Player)
	local marker = allyMarkers[target]
	if marker then
		marker.gui:Destroy()
		allyMarkers[target] = nil
	end
end

local function attachAllyMarker(target: Player, character: Model)
	if target == player then
		return
	end
	removeAllyMarker(target)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 6)
		local humanoid = character:WaitForChild("Humanoid", 6)
		if target.Character ~= character or not root or not root:IsA("BasePart")
			or not humanoid or not humanoid:IsA("Humanoid") then
			return
		end

		local gui = Instance.new("BillboardGui")
		gui.Name = "TeamIFF"
		gui.Size = UDim2.fromOffset(220, 32)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 4.7, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 800
		gui.ResetOnSpawn = false
		gui.Enabled = false
		gui.Parent = root

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 25)
		label.BackgroundColor3 = Color3.fromRGB(6, 12, 19)
		label.BackgroundTransparency = 0.38
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamBold
		label.Text = ""
		label.TextColor3 = Color3.fromRGB(185, 225, 255)
		label.TextSize = 11
		label.TextStrokeColor3 = Color3.fromRGB(3, 6, 10)
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
		local labelCorner = Instance.new("UICorner")
		labelCorner.CornerRadius = UDim.new(0, 6)
		labelCorner.Parent = label

		local healthTrack = Instance.new("Frame")
		healthTrack.Size = UDim2.new(0.64, 0, 0, 5)
		healthTrack.AnchorPoint = Vector2.new(0.5, 0)
		healthTrack.Position = UDim2.new(0.5, 0, 0, 28)
		healthTrack.BackgroundColor3 = Color3.fromRGB(15, 23, 31)
		healthTrack.BackgroundTransparency = 0.15
		healthTrack.BorderSizePixel = 0
		healthTrack.ClipsDescendants = true
		healthTrack.Parent = gui
		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = healthTrack

		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = target.Team and target.Team.TeamColor.Color or Color3.fromRGB(105, 205, 255)
		fill.BorderSizePixel = 0
		fill.Parent = healthTrack
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		allyMarkers[target] = {
			gui = gui,
			label = label,
			fill = fill,
			target = target,
			humanoid = humanoid,
			root = root,
		}
	end)
end

local function setupAllyTarget(target: Player)
	if target == player then
		return
	end
	target.CharacterAdded:Connect(function(character)
		attachAllyMarker(target, character)
	end)
	target.CharacterRemoving:Connect(function()
		removeAllyMarker(target)
	end)
	if target.Character then
		attachAllyMarker(target, target.Character)
	end
end

Players.PlayerAdded:Connect(setupAllyTarget)
Players.PlayerRemoving:Connect(removeAllyMarker)
for _, target in Players:GetPlayers() do
	setupAllyTarget(target)
end

local allyAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	allyAccumulator += dt
	if allyAccumulator < 0.12 then
		return
	end
	allyAccumulator = 0

	local localCharacter = player.Character
	local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
	for target, marker in allyMarkers do
		local sameTeam = player.Team ~= nil and target.Team == player.Team
		local alive = marker.humanoid.Health > 0 and marker.root.Parent ~= nil
		marker.gui.Enabled = sameTeam and alive
		if not sameTeam or not alive then
			continue
		end

		local ratio = math.clamp(marker.humanoid.Health / math.max(1, marker.humanoid.MaxHealth), 0, 1)
		marker.fill.Size = UDim2.fromScale(ratio, 1)
		marker.fill.BackgroundColor3 = target.Team and target.Team.TeamColor.Color or Color3.fromRGB(105, 205, 255)

		local distanceText = ""
		if localRoot and localRoot:IsA("BasePart") then
			distanceText = string.format(" // %dm", math.floor((marker.root.Position - localRoot.Position).Magnitude / 3.57))
		end
		local loadout = target:GetAttribute("Loadout")
		local classText = if typeof(loadout) == "string" then string.upper(loadout) else "TRIBES"
		local carryingFlag = marker.root.Parent and (
			marker.root.Parent:FindFirstChild("RedFlag") ~= nil
			or marker.root.Parent:FindFirstChild("BlueFlag") ~= nil
		)
		marker.label.Text = string.format(
			"%s%s // %s%s",
			carryingFlag and "[FLAG] " or "[ALLY] ",
			string.upper(target.DisplayName),
			classText,
			distanceText
		)
	end
end)
