-- CaptureAnnouncer.client.lua
-- Ablageort: StarterPlayerScripts
--
-- Großes Mitten-Banner, wenn ein Spieler die Flagge cappt. Der Score-Zähler
-- im HUD ändert sich sonst nur stumm - Captures sind DAS Ereignis in CTF und
-- verdienen einen Moment. Hört auf dasselbe CTFScoreUpdate wie das HUD;
-- Score-Resets (ohne Spielername) lösen bewusst keine Ansage aus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local scoreEvent = ReplicatedStorage:WaitForChild("CTFScoreUpdate")
local matchStateEvent = ReplicatedStorage:WaitForChild("MatchStateChanged")

local TEAM_COLORS: { [string]: Color3 } = {
	Red = Color3.fromRGB(255, 110, 100),
	Blue = Color3.fromRGB(110, 160, 255),
}

local gui = Instance.new("ScreenGui")
gui.Name = "CaptureAnnouncer"
gui.ResetOnSpawn = false
gui.DisplayOrder = 25
gui.Parent = player:WaitForChild("PlayerGui")

local objectiveTone = Instance.new("Sound")
objectiveTone.Name = "ObjectiveTone"
objectiveTone.SoundId = "rbxasset://sounds/electronicpingshort.wav"
objectiveTone.Volume = 0.58
objectiveTone.Parent = SoundService

local function playObjectiveTone(pitch: number)
	objectiveTone:Stop()
	objectiveTone.PlaybackSpeed = pitch
	objectiveTone.TimePosition = 0
	objectiveTone:Play()
end

local banner = Instance.new("TextLabel")
banner.Size = UDim2.fromOffset(640, 54)
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 244)
banner.BackgroundColor3 = Color3.fromRGB(10, 13, 19)
banner.BackgroundTransparency = 1
banner.BorderSizePixel = 0
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 26
banner.TextTransparency = 1
banner.TextStrokeColor3 = Color3.fromRGB(8, 10, 14)
banner.TextStrokeTransparency = 1
banner.Text = ""
banner.Parent = gui

local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 10)
bannerCorner.Parent = banner

local bannerScale = Instance.new("UIScale")
bannerScale.Scale = 1
bannerScale.Parent = banner

local hideThread: thread? = nil

local function announce(text: string, color: Color3)
	banner.Text = text
	banner.TextColor3 = color

	if hideThread then
		task.cancel(hideThread)
		hideThread = nil
	end

	banner.BackgroundTransparency = 0.25
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.4
	bannerScale.Scale = 0.84
	TweenService:Create(bannerScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	hideThread = task.spawn(function()
		task.wait(2.8)
		local fade = TweenService:Create(banner, TweenInfo.new(0.6), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		fade:Play()
		hideThread = nil
	end)
end

scoreEvent.OnClientEvent:Connect(function(teamName: string, _newScore: number, scoringPlayerName: string?)
	if typeof(scoringPlayerName) ~= "string" or scoringPlayerName == "" then
		return -- Score-Reset / Anzeige-Sync, kein echtes Capture
	end
	local color = TEAM_COLORS[teamName] or Color3.fromRGB(235, 242, 252)
	local isMe = scoringPlayerName == player.DisplayName or scoringPlayerName == player.Name
	playObjectiveTone(1.32)
	announce(
		if isMe
			then string.format("⚑ FLAGGE GECAPPT! STARK, %s!", string.upper(scoringPlayerName))
			else string.format("⚑ %s CAPPT FÜR %s!", string.upper(scoringPlayerName), string.upper(teamName)),
		color
	)
end)

-- CTFManager schreibt zuerst die Eventdaten und zuletzt eine steigende
-- Seriennummer. Dadurch kommen alle Clients ohne zusaetzlichen RemoteEvent
-- deterministisch und serverautoritaer zur gleichen Objective-Ansage.
local lastFlagEventSerial = ReplicatedStorage:GetAttribute("FlagEventSerial")
if typeof(lastFlagEventSerial) ~= "number" then
	lastFlagEventSerial = 0
end

ReplicatedStorage:GetAttributeChangedSignal("FlagEventSerial"):Connect(function()
	local serial = ReplicatedStorage:GetAttribute("FlagEventSerial")
	if typeof(serial) ~= "number" or serial <= lastFlagEventSerial then
		return
	end
	lastFlagEventSerial = serial

	local kind = ReplicatedStorage:GetAttribute("FlagEventKind")
	local flagTeam = ReplicatedStorage:GetAttribute("FlagEventTeam")
	local actorName = ReplicatedStorage:GetAttribute("FlagEventPlayer")
	if typeof(kind) ~= "string" or typeof(flagTeam) ~= "string" then
		return
	end

	local localTeam = player.Team and player.Team.Name or ""
	local isOurFlag = flagTeam == localTeam
	local teamColor = TEAM_COLORS[flagTeam] or Color3.fromRGB(235, 242, 252)
	local actorIsMe = typeof(actorName) == "string" and actorName == player.Name
	local text: string
	local color: Color3
	local pitch: number

	if kind == "Taken" then
		if actorIsMe then
			text = "DU HAST DIE FEINDLICHE FLAGGE!"
			color = Color3.fromRGB(112, 244, 185)
			pitch = 1.25
		elseif isOurFlag then
			text = "EURE FLAGGE WURDE GESTOHLEN!"
			color = Color3.fromRGB(255, 92, 86)
			pitch = 0.72
		else
			text = string.format("FEINDLICHE FLAGGE GENOMMEN // %s", string.upper(tostring(actorName)))
			color = teamColor
			pitch = 1.08
		end
	elseif kind == "Dropped" then
		text = if isOurFlag then "EURE FLAGGE LIEGT - ZURUECKHOLEN!" else "FEINDLICHE FLAGGE LIEGT - SICHERN!"
		color = Color3.fromRGB(255, 205, 92)
		pitch = 0.88
	elseif kind == "Returned" then
		text = if isOurFlag then "EURE FLAGGE IST ZURUECK" else "FEINDLICHE FLAGGE ZURUECKGEKEHRT"
		color = if isOurFlag then Color3.fromRGB(112, 244, 185) else teamColor
		pitch = if isOurFlag then 1.18 else 0.92
	else
		return
	end

	playObjectiveTone(pitch)
	announce(text, color)
end)

local previousMatchPhase = ReplicatedStorage:GetAttribute("MatchPhase")
matchStateEvent.OnClientEvent:Connect(function(phase: string)
	if phase == previousMatchPhase then
		return
	end
	previousMatchPhase = phase
	if phase == "Overtime" then
		playObjectiveTone(0.68)
		announce("OVERTIME // NAECHSTER CAPTURE GEWINNT", Color3.fromRGB(255, 184, 66))
	end
end)
