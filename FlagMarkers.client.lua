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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FLAG_TAG = "CTFFlag"
local player = Players.LocalPlayer

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
	gui.Size = UDim2.fromOffset(190, 42)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 1200
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 16
	label.TextColor3 = flag.Color
	label.TextStrokeColor3 = Color3.fromRGB(8, 10, 14)
	label.TextStrokeTransparency = 0.25
	label.Text = ""
	label.Parent = gui

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
