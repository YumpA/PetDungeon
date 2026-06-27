local Client = script.Parent
local Controllers = Client:WaitForChild("Controllers")

local PetStationUIController = require(Controllers:WaitForChild("PetStationUIController"))
local TeleportPortalUIController = require(Controllers:WaitForChild("TeleportPortalUIController"))

PetStationUIController.Start()
TeleportPortalUIController.Start()
