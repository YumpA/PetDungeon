local PetStationService = {}

local STATION_NAME = "PetStation"
local PROMPT_NAME = "PetStationPrompt"
local PROMPT_ACTION_TEXT = "Pets"
local PROMPT_OBJECT_TEXT = "Pet Station"
local PROMPT_DISTANCE = 10

local started = false

local function createStationPart(): BasePart
	local existingStation = workspace:FindFirstChild(STATION_NAME)
	if existingStation and existingStation:IsA("BasePart") then
		return existingStation
	end

	local station = Instance.new("Part")
	station.Name = STATION_NAME
	station.Anchored = true
	station.Size = Vector3.new(5, 1, 5)
	station.Position = Vector3.new(80, 0.5, 47)
	station.Color = Color3.fromRGB(74, 144, 226)
	station.Material = Enum.Material.Neon
	station.Parent = workspace

	return station
end

local function createPrompt(station: BasePart)
	local existingPrompt = station:FindFirstChild(PROMPT_NAME)
	if existingPrompt and existingPrompt:IsA("ProximityPrompt") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = PROMPT_ACTION_TEXT
	prompt.ObjectText = PROMPT_OBJECT_TEXT
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = station
end

function PetStationService.Start()
	if started then
		return
	end

	started = true

	local station = createStationPart()
	createPrompt(station)
end

return PetStationService
