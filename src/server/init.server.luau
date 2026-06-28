local Server = script.Parent
local Services = Server:WaitForChild("Services")

local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local HostileNpcService = require(Services:WaitForChild("HostileNpcService"))
local PetService = require(Services:WaitForChild("PetService"))
local PetStationService = require(Services:WaitForChild("PetStationService"))
local TeleportPortalService = require(Services:WaitForChild("TeleportPortalService"))
local TycoonPlateService = require(Services:WaitForChild("TycoonPlateService"))

CurrencyService.Start()
PetService.Start()
HostileNpcService.Start(PetService)
PetStationService.Start()
TeleportPortalService.Start()
TycoonPlateService.Start(CurrencyService)
