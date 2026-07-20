-- CaptureAnnouncer.client.lua
-- Ablageort: StarterPlayerScripts
--
-- Großes Mitten-Banner, wenn ein Spieler die Flagge cappt. Der Score-Zähler
-- im HUD ändert sich sonst nur stumm - Captures sind DAS Ereignis in CTF und
-- verdienen einen Moment. Hört auf dasselbe CTFScoreUpdate wie das HUD;
-- Score-Resets (ohne Spielername) lösen bewusst keine Ansage aus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local scoreEvent = ReplicatedStorage:WaitForChild("CTFScoreUpdate")

local TEAM_COLORS: { [string]: Color3 } = {
	Red = Color3.fromRGB(255, 110, 100),
	Blue = Color3.fromRGB(110, 160, 255),
}

local gui = Instance.new("ScreenGui")
gui.Name = "CaptureAnnouncer"
gui.ResetOnSpawn = false
gui.DisplayOrder = 25
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.Size = UDim2.fromOffset(640, 54)
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 150)
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
	announce(
		if isMe
			then string.format("⚑ FLAGGE GECAPPT! STARK, %s!", string.upper(scoringPlayerName))
			else string.format("⚑ %s CAPPT FÜR %s!", string.upper(scoringPlayerName), string.upper(teamName)),
		color
	)
end)
