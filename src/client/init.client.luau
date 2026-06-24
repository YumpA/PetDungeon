local Client = script.Parent
local Controllers = Client:WaitForChild("Controllers")

local PetStationUIController = require(Controllers:WaitForChild("PetStationUIController"))

PetStationUIController.Start()
