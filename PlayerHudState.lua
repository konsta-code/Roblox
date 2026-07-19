-- PlayerHudState.lua
-- Ablageort: ReplicatedStorage/Modules/PlayerHudState
--
-- Zwei separate LocalScripts (SkiController, HudController) können sich
-- nicht direkt sehen. Dieses Modul ist der gemeinsame Zwischenspeicher:
-- SkiController schreibt die Jetpack-Energie rein, HudController liest/
-- abonniert sie. Gleiches Muster bei Bedarf für weitere Werte erweiterbar.

local PlayerHudState = {}

local jetpackEnergyChanged = Instance.new("BindableEvent")
PlayerHudState.JetpackEnergyChanged = jetpackEnergyChanged.Event

local currentEnergy = 100

function PlayerHudState.SetJetpackEnergy(value: number)
	currentEnergy = value
	jetpackEnergyChanged:Fire(value)
end

function PlayerHudState.GetJetpackEnergy(): number
	return currentEnergy
end

return PlayerHudState
