-- ChaingunConstants.lua
-- Ablageort: ReplicatedStorage/Modules/ChaingunConstants

local Constants = {}

Constants.MAX_RANGE = 300              -- Studs, maximale Reichweite
Constants.DAMAGE_PER_HIT = 9           -- Schaden pro Treffer

Constants.MIN_FIRE_INTERVAL = 0.09     -- Sekunden zwischen Schüssen bei voller Drehzahl (~11/s)
Constants.MAX_FIRE_INTERVAL = 0.35     -- Sekunden zwischen Schüssen beim Anlaufen
Constants.SPIN_UP_TIME = 0.9           -- Sekunden bis volle Feuerrate erreicht ist
Constants.SPREAD_ANGLE = 2.5           -- Grad, zufällige Streuung pro Schuss

Constants.HEAT_MAX = 100
Constants.HEAT_PER_SHOT = 6
Constants.HEAT_COOLDOWN_RATE = 35      -- Abkühlung pro Sekunde, wenn nicht gefeuert wird
Constants.OVERHEAT_LOCKOUT = 2.0       -- Sekunden Zwangspause nach Overheat

return Constants
