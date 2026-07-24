-- MapMenu.client.lua
-- Ablageort: StarterPlayer/StarterPlayerScripts
--
-- PostMatch-Screen: erscheint am Rundenende (MatchPhase == "PostMatch") und zeigt
--   1) das Sieger-Podium (Top 3 nach RoundScore, aus ReplicatedStorage-Attributen)
--   2) das Map-Voting fuer die naechste Runde (Klick feuert MapVote:FireServer)
-- Ausserhalb von PostMatch ist der Screen unsichtbar. Kein freies Umschalten mehr.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local MapPool = require(ReplicatedStorage.Modules.MapPoolConstants)
local mapVote = ReplicatedStorage:WaitForChild("MapVote")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local THEME_COLOR = {
	grass = Color3.fromRGB(96, 150, 60),
	snow = Color3.fromRGB(150, 190, 220),
	desert = Color3.fromRGB(210, 170, 100),
}
local MEDAL = { "🥇", "🥈", "🥉" }

local function corner(inst: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

-- ============================================================
-- GUI-AUFBAU (versteckt)
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "MatchEndScreen"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 30
gui.Enabled = false
gui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 0.45
dim.BorderSizePixel = 0
dim.Parent = gui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(480, 560)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(16, 19, 24)
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Parent = gui
corner(panel, 16)
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 18)
pad.PaddingBottom = UDim.new(0, 18)
pad.PaddingLeft = UDim.new(0, 20)
pad.PaddingRight = UDim.new(0, 20)
pad.Parent = panel
local stack = Instance.new("UIListLayout")
stack.Padding = UDim.new(0, 10)
stack.SortOrder = Enum.SortOrder.LayoutOrder
stack.Parent = panel

local function label(text: string, size: number, color: Color3, order: number, height: number)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, height)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.LayoutOrder = order
	l.Parent = panel
	return l
end

local titleLabel = label("RUNDE VORBEI", 26, Color3.fromRGB(240, 244, 250), 1, 32)
local winnerLabel = label("", 16, Color3.fromRGB(112, 244, 185), 2, 22)
local countdownLabel = label("", 13, Color3.fromRGB(150, 158, 168), 3, 18)

-- Podium
local podium = Instance.new("Frame")
podium.Size = UDim2.new(1, 0, 0, 132)
podium.BackgroundTransparency = 1
podium.LayoutOrder = 4
podium.Parent = panel
local podiumStack = Instance.new("UIListLayout")
podiumStack.Padding = UDim.new(0, 6)
podiumStack.SortOrder = Enum.SortOrder.LayoutOrder
podiumStack.Parent = podium

local podiumRows = {}
for placeIndex = 1, 3 do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.BackgroundColor3 = if placeIndex == 1 then Color3.fromRGB(44, 40, 24) else Color3.fromRGB(28, 32, 39)
	row.BorderSizePixel = 0
	row.LayoutOrder = placeIndex
	row.Parent = podium
	corner(row, 8)

	local medal = Instance.new("TextLabel")
	medal.Size = UDim2.fromOffset(40, 38)
	medal.BackgroundTransparency = 1
	medal.Text = MEDAL[placeIndex]
	medal.TextSize = 20
	medal.Font = Enum.Font.GothamBold
	medal.Parent = row

	local nameL = Instance.new("TextLabel")
	nameL.Size = UDim2.new(1, -140, 1, 0)
	nameL.Position = UDim2.fromOffset(44, 0)
	nameL.BackgroundTransparency = 1
	nameL.Font = Enum.Font.GothamBold
	nameL.TextSize = 15
	nameL.TextColor3 = if placeIndex == 1 then Color3.fromRGB(255, 214, 120) else Color3.fromRGB(232, 236, 242)
	nameL.TextXAlignment = Enum.TextXAlignment.Left
	nameL.Text = "—"
	nameL.Parent = row

	local scoreL = Instance.new("TextLabel")
	scoreL.Size = UDim2.fromOffset(90, 38)
	scoreL.Position = UDim2.new(1, -94, 0, 0)
	scoreL.BackgroundTransparency = 1
	scoreL.Font = Enum.Font.Gotham
	scoreL.TextSize = 14
	scoreL.TextColor3 = Color3.fromRGB(180, 186, 196)
	scoreL.TextXAlignment = Enum.TextXAlignment.Right
	scoreL.Text = ""
	scoreL.Parent = row

	podiumRows[placeIndex] = { name = nameL, score = scoreL }
end

label("NÄCHSTE MAP WÄHLEN", 15, Color3.fromRGB(200, 206, 214), 5, 22)

-- Map-Voting-Buttons (2 Spalten)
local voteArea = Instance.new("Frame")
voteArea.Size = UDim2.new(1, 0, 0, 200)
voteArea.BackgroundTransparency = 1
voteArea.LayoutOrder = 6
voteArea.Parent = panel
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.5, -5, 0, 58)
grid.CellPadding = UDim2.fromOffset(10, 10)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = voteArea

local selectedId: string? = nil
local buttonsById = {}

local function restyle()
	for id, btn in buttonsById do
		btn.BackgroundColor3 = if id == selectedId then Color3.fromRGB(46, 66, 54) else Color3.fromRGB(30, 35, 42)
	end
end

local function makeVoteButton(def, order: number)
	local btn = Instance.new("TextButton")
	btn.BackgroundColor3 = Color3.fromRGB(30, 35, 42)
	btn.AutoButtonColor = true
	btn.Text = ""
	btn.LayoutOrder = order
	btn.Parent = voteArea
	corner(btn, 8)

	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(0, 5, 1, -10)
	stripe.Position = UDim2.fromOffset(0, 5)
	stripe.BackgroundColor3 = THEME_COLOR[def.theme] or Color3.fromRGB(120, 120, 120)
	stripe.BorderSizePixel = 0
	stripe.Parent = btn
	corner(stripe, 3)

	local nameL = Instance.new("TextLabel")
	nameL.Size = UDim2.new(1, -22, 0, 20)
	nameL.Position = UDim2.fromOffset(14, 9)
	nameL.BackgroundTransparency = 1
	nameL.Text = def.name
	nameL.Font = Enum.Font.GothamBold
	nameL.TextSize = 14
	nameL.TextColor3 = Color3.fromRGB(240, 244, 250)
	nameL.TextXAlignment = Enum.TextXAlignment.Left
	nameL.Parent = btn

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -22, 0, 14)
	sub.Position = UDim2.fromOffset(14, 30)
	sub.BackgroundTransparency = 1
	sub.Text = string.upper(def.theme)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 11
	sub.TextColor3 = Color3.fromRGB(150, 158, 168)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Parent = btn

	btn.Activated:Connect(function()
		selectedId = def.id
		restyle()
		mapVote:FireServer(def.id)
	end)

	buttonsById[def.id] = btn
end

for index, def in MapPool.Pool do
	makeVoteButton(def, index)
end

-- ============================================================
-- REFRESH + SICHTBARKEIT
-- ============================================================
local function refreshPodium()
	for placeIndex = 1, 3 do
		local name = ReplicatedStorage:GetAttribute("MatchTop" .. placeIndex .. "Name")
		local score = ReplicatedStorage:GetAttribute("MatchTop" .. placeIndex .. "Score")
		local row = podiumRows[placeIndex]
		row.name.Text = if typeof(name) == "string" then name else "—"
		row.score.Text = if typeof(score) == "number" then string.format("%d Pkt", score) else ""
	end
end

local function refreshHeader()
	local winner = ReplicatedStorage:GetAttribute("MatchWinner")
	winnerLabel.Text = if winner == "Unentschieden"
		then "UNENTSCHIEDEN"
		elseif typeof(winner) == "string" then string.upper(winner) .. " GEWINNT"
		else ""
	local remaining = ReplicatedStorage:GetAttribute("MatchTimeRemaining")
	countdownLabel.Text = if typeof(remaining) == "number"
		then ("Nächste Runde in %ds"):format(math.max(0, remaining))
		else ""
end

-- Waehrend des PostMatch-Screens die Maus freigeben (das Spiel laeuft in
-- LockFirstPerson, sonst klebt der Cursor in der Mitte und Klicks bewegen/feuern
-- die Waffe) UND Combat-Input sperren -- ueber LoadoutMenuOpen, das alle Waffen
-- und Faehigkeiten bereits respektieren.
local MOUSE_BIND = "MatchEndMouseRelease"
local function setInteractive(on: boolean)
	if on then
		player.CameraMode = Enum.CameraMode.Classic
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		RunService:BindToRenderStep(MOUSE_BIND, Enum.RenderPriority.Camera.Value + 50, function()
			if gui.Enabled then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			end
		end)
	else
		RunService:UnbindFromRenderStep(MOUSE_BIND)
		GuiService.SelectedObject = nil
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
end

local mineOpen = false
local function updateVisibility()
	local isPost = ReplicatedStorage:GetAttribute("MatchPhase") == "PostMatch"
	if isPost == mineOpen then
		return
	end
	mineOpen = isPost
	gui.Enabled = isPost
	-- Nur beim tatsaechlichen PostMatch-Wechsel toggeln, damit wir dem
	-- Loadout-Menue (das dieselbe Flag in Warmup nutzt) nicht reinfunken.
	player:SetAttribute("LoadoutMenuOpen", isPost)
	setInteractive(isPost)
	if isPost then
		selectedId = nil
		restyle()
		refreshPodium()
		refreshHeader()
	end
end

ReplicatedStorage:GetAttributeChangedSignal("MatchPhase"):Connect(updateVisibility)
ReplicatedStorage:GetAttributeChangedSignal("MatchTimeRemaining"):Connect(refreshHeader)
ReplicatedStorage:GetAttributeChangedSignal("MatchWinner"):Connect(refreshHeader)
for placeIndex = 1, 3 do
	ReplicatedStorage:GetAttributeChangedSignal("MatchTop" .. placeIndex .. "Name"):Connect(refreshPodium)
	ReplicatedStorage:GetAttributeChangedSignal("MatchTop" .. placeIndex .. "Score"):Connect(refreshPodium)
end

updateVisibility()
