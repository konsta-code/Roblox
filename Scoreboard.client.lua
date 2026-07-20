-- Scoreboard.client.lua
-- Ablageort: StarterPlayerScripts
--
-- Tab gedrückt halten zeigt das Match-Scoreboard (ersetzt Robloxens
-- Standard-Spielerliste): zwei Team-Spalten mit Team-Score, pro Spieler
-- Name, Klasse, Kills/Deaths/Captures. Liest ausschließlich replizierte
-- Daten (leaderstats, Loadout-Attribut, CTFScore_*-Attribute) - keine Remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Teams = game:GetService("Teams")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Standard-Spielerliste aus - unser Scoreboard übernimmt. SetCore kann beim
-- frühen Start noch nicht bereit sein, daher mit Wiederholung.
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		if ok then return end
		task.wait(0.5)
	end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "Scoreboard"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(900, 440)
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.45)
root.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
root.BackgroundTransparency = 0.14
root.BorderSizePixel = 0
root.Parent = gui

local rootCorner = Instance.new("UICorner")
rootCorner.CornerRadius = UDim.new(0, 12)
rootCorner.Parent = root

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(235, 242, 252)
title.Text = "CAPTURE THE FLAG"
title.Parent = root

type ColumnParts = { frame: Frame, header: TextLabel, list: Frame }

local function makeColumn(teamName: string, xScale: number, color: Color3): ColumnParts
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0.5, -24, 1, -64)
	frame.Position = UDim2.new(xScale, 16, 0, 48)
	frame.BackgroundColor3 = Color3.fromRGB(16, 21, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -16, 0, 34)
	header.Position = UDim2.fromOffset(8, 4)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 17
	header.TextColor3 = color
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = string.upper(teamName)
	header.Parent = frame

	local legend = Instance.new("TextLabel")
	legend.Size = UDim2.new(1, -16, 0, 16)
	legend.Position = UDim2.fromOffset(8, 38)
	legend.BackgroundTransparency = 1
	legend.Font = Enum.Font.Gotham
	legend.TextSize = 11
	legend.TextColor3 = Color3.fromRGB(150, 162, 178)
	legend.TextXAlignment = Enum.TextXAlignment.Left
	legend.Text = "SPIELER          KLASSE       PTS  CAP  K  A  D"
	legend.Parent = frame

	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, -16, 1, -62)
	list.Position = UDim2.fromOffset(8, 56)
	list.BackgroundTransparency = 1
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	return { frame = frame, header = header, list = list }
end

local columns: { [string]: ColumnParts } = {
	Red = makeColumn("Red", 0, Color3.fromRGB(255, 110, 100)),
	Blue = makeColumn("Blue", 0.5, Color3.fromRGB(110, 160, 255)),
}

local function statValue(p: Player, name: string): number
	local roundValue = p:GetAttribute("Round" .. name)
	if typeof(roundValue) == "number" then
		return roundValue
	end
	local leaderstats = p:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(name)
	return (stat and stat:IsA("IntValue")) and stat.Value or 0
end

type RowInfo = {
	player: Player,
	kills: number,
	deaths: number,
	captures: number,
	assists: number,
	score: number,
}

local function shortText(value: string, length: number): string
	return if #value > length then string.sub(value, 1, length - 1) .. "." else value
end

local function refresh()
	local phase = ReplicatedStorage:GetAttribute("MatchPhase")
	if phase == "Overtime" then
		title.Text = "OVERTIME // NEXT CAP WINS"
		title.TextColor3 = Color3.fromRGB(255, 190, 70)
	elseif phase == "PostMatch" then
		local mvp = ReplicatedStorage:GetAttribute("MatchMVP")
		title.Text = if typeof(mvp) == "string" then "MATCH RESULT // MVP " .. string.upper(mvp) else "MATCH RESULT"
		title.TextColor3 = Color3.fromRGB(112, 244, 185)
	else
		title.Text = "CAPTURE THE FLAG"
		title.TextColor3 = Color3.fromRGB(235, 242, 252)
	end
	for teamName, column in columns do
		local team = Teams:FindFirstChild(teamName)
		local score = ReplicatedStorage:GetAttribute("CTFScore_" .. teamName)
		column.header.Text = string.format(
			"%s   —   %d FLAGGEN",
			string.upper(teamName),
			typeof(score) == "number" and score or 0
		)

		-- Alte Zeilen wegwerfen und frisch aufbauen (2-Team-Scoreboard, die
		-- Spielerzahl ist klein - Einfachheit schlägt hier Wiederverwendung).
		for _, child in column.list:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		if not team then continue end

		local rows: { RowInfo } = {}
		for _, p in team:GetPlayers() do
			table.insert(rows, {
				player = p,
				kills = statValue(p, "Kills"),
				deaths = statValue(p, "Deaths"),
				captures = statValue(p, "Captures"),
				assists = statValue(p, "Assists"),
				score = statValue(p, "Score"),
			})
		end
		table.sort(rows, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			elseif a.captures ~= b.captures then
				return a.captures > b.captures
			end
			return a.kills > b.kills
		end)

		for order, info in rows do
			local loadout = info.player:GetAttribute("Loadout")
			local row = Instance.new("TextLabel")
			row.Size = UDim2.new(1, 0, 0, 24)
			row.BackgroundColor3 = Color3.fromRGB(24, 31, 43)
			row.BackgroundTransparency = info.player == player and 0.2 or 0.5
			row.BorderSizePixel = 0
			row.Font = Enum.Font.Gotham
			row.TextSize = 11
			row.TextColor3 = Color3.fromRGB(226, 233, 244)
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.LayoutOrder = order
			row.Text = string.format(
				" %-14s %-10s %4d  %2d %2d %2d %2d",
				shortText(info.player.DisplayName, 14),
				shortText(typeof(loadout) == "string" and string.upper(loadout) or "?", 10),
				info.score,
				info.captures,
				info.kills,
				info.assists,
				info.deaths
			)
			row.Parent = column.list

			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 4)
			rowCorner.Parent = row
		end
	end
end

-- Tab halten = anzeigen. Aktualisiert alle 0.5s solange sichtbar.
local refreshThread: thread? = nil

local function setVisible(visible: boolean)
	gui.Enabled = visible
	if refreshThread then
		task.cancel(refreshThread)
		refreshThread = nil
	end
	if visible then
		refresh()
		refreshThread = task.spawn(function()
			while true do
				task.wait(0.5)
				refresh()
			end
		end)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Tab then
		setVisible(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Tab then
		setVisible(false)
	end
end)
