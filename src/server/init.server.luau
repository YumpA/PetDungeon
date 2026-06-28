local Server = script.Parent
local Services = Server:WaitForChild("Services")

local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local PetService = require(Services:WaitForChild("PetService"))
local PetStationService = require(Services:WaitForChild("PetStationService"))
local TeleportPortalService = require(Services:WaitForChild("TeleportPortalService"))
local TycoonPlateService = require(Services:WaitForChild("TycoonPlateService"))

CurrencyService.Start()
PartyService.Start()
PetService.Start()
PetStationService.Start()
TeleportPortalService.Start(PartyService)
TycoonPlateService.Start(CurrencyService)
