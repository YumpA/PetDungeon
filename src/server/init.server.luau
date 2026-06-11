local Server = script.Parent
local Services = Server:WaitForChild("Services")

local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local TycoonPlateService = require(Services:WaitForChild("TycoonPlateService"))

CurrencyService.Start()
TycoonPlateService.Start(CurrencyService)
