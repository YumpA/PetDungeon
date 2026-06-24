local Server = script.Parent
local Services = Server:WaitForChild("Services")

local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local PetService = require(Services:WaitForChild("PetService"))
local PetStationService = require(Services:WaitForChild("PetStationService"))
local TycoonPlateService = require(Services:WaitForChild("TycoonPlateService"))

CurrencyService.Start()
PetService.Start()
PetStationService.Start()
TycoonPlateService.Start(CurrencyService)
