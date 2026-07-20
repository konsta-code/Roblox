-- BaseSystemConstants.lua
-- Generator-, Inventarstations- und Base-Turret-Werte.

local Constants = {}

Constants.GENERATOR_TAG = "PowerGenerator"
Constants.INVENTORY_STATION_TAG = "InventoryStation"
Constants.BASE_TURRET_TAG = "BaseTurret"

Constants.GENERATOR_MAX_HEALTH = 700
Constants.GENERATOR_REPAIR_AMOUNT = 175
Constants.INVENTORY_ACCESS_TIME = 12
Constants.INVENTORY_USE_COOLDOWN = 0.75

Constants.TURRET_RANGE = 125
Constants.TURRET_DAMAGE = 12
Constants.TURRET_FIRE_INTERVAL = 0.3
Constants.TURRET_UPDATE_INTERVAL = 0.1

return Constants
