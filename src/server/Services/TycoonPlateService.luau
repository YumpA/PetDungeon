local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

type CurrencyService = {
	Spend: (player: Player, amount: number) -> boolean,
}

type PlateConfig = {
	Price: number?,
	NextModel: Model?,
	NextModelName: string?,
	CurrentModel: Instance?,
	CurrentModelName: string?,
	BuildParent: Instance?,
	BuildParentName: string?,
	OwnerUserId: number?,
	DisableAfterPurchase: boolean?,
}

local TycoonPlateService = {}

local PLATE_TAG = "TycoonPlate"
local TEMPLATE_FOLDER_NAME = "TycoonModels"
local OWNER_ATTRIBUTE_NAME = "OwnerUserId"
local TOUCH_RATE_LIMIT_SECONDS = 0.75

local currencyService: CurrencyService? = nil
local plateConnections: { [BasePart]: RBXScriptConnection } = {}
local lastTouchByPlate: { [BasePart]: { [number]: number } } = {}
local disabledPlates: { [BasePart]: boolean } = {}
local started = false

local function getPlayerFromTouchedPart(touchedPart: BasePart): Player?
	local character = touchedPart:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function findModelTemplate(modelName: string?): Model?
	if not modelName or modelName == "" then
		return nil
	end

	local templateFolder = ServerStorage:FindFirstChild(TEMPLATE_FOLDER_NAME)
	if not templateFolder then
		warn(`Missing ServerStorage.{TEMPLATE_FOLDER_NAME}; cannot buy tycoon model "{modelName}".`)
		return nil
	end

	local template = templateFolder:FindFirstChild(modelName)
	if template and template:IsA("Model") then
		return template
	end

	warn(`Missing Model template ServerStorage.{TEMPLATE_FOLDER_NAME}.{modelName}.`)
	return nil
end

local function getNumberAttribute(instance: Instance, attributeName: string): number?
	local value = instance:GetAttribute(attributeName)
	if typeof(value) == "number" then
		return value
	end

	return nil
end

local function getStringAttribute(instance: Instance, attributeName: string): string?
	local value = instance:GetAttribute(attributeName)
	if typeof(value) == "string" then
		return value
	end

	return nil
end

local function getBooleanAttribute(instance: Instance, attributeName: string): boolean?
	local value = instance:GetAttribute(attributeName)
	if typeof(value) == "boolean" then
		return value
	end

	return nil
end

local function getConfigFromAttributes(plate: BasePart): PlateConfig
	return {
		Price = getNumberAttribute(plate, "Price"),
		NextModelName = getStringAttribute(plate, "NextModelName"),
		CurrentModelName = getStringAttribute(plate, "CurrentModelName"),
		BuildParentName = getStringAttribute(plate, "BuildParentName"),
		OwnerUserId = getNumberAttribute(plate, OWNER_ATTRIBUTE_NAME),
		DisableAfterPurchase = getBooleanAttribute(plate, "DisableAfterPurchase"),
	}
end

local function resolveBuildParent(plate: BasePart, config: PlateConfig): Instance
	if config.BuildParent then
		return config.BuildParent
	end

	if config.BuildParentName and config.BuildParentName ~= "" then
		local namedParent = workspace:FindFirstChild(config.BuildParentName, true)
		if namedParent then
			return namedParent
		end
	end

	return plate.Parent or workspace
end

local function resolveCurrentModel(buildParent: Instance, config: PlateConfig): Instance?
	if config.CurrentModel then
		return config.CurrentModel
	end

	if config.CurrentModelName and config.CurrentModelName ~= "" then
		return buildParent:FindFirstChild(config.CurrentModelName)
	end

	return nil
end

local function resolveNextModel(config: PlateConfig): Model?
	if config.NextModel then
		return config.NextModel
	end

	return findModelTemplate(config.NextModelName)
end

local function findOwnerUserId(instance: Instance?): number?
	local currentInstance = instance
	while currentInstance do
		local ownerUserId = getNumberAttribute(currentInstance, OWNER_ATTRIBUTE_NAME)
		if ownerUserId then
			return ownerUserId
		end

		currentInstance = currentInstance.Parent
	end

	return nil
end

local function resolveExistingOwnerUserId(
	plate: BasePart,
	buildParent: Instance,
	currentModel: Instance?,
	config: PlateConfig
): number?
	return config.OwnerUserId
		or findOwnerUserId(plate)
		or findOwnerUserId(currentModel)
		or findOwnerUserId(buildParent)
end

local function stampOwnerUserId(instance: Instance, ownerUserId: number)
	instance:SetAttribute(OWNER_ATTRIBUTE_NAME, ownerUserId)

	for _, descendant in instance:GetDescendants() do
		descendant:SetAttribute(OWNER_ATTRIBUTE_NAME, ownerUserId)
	end
end

local function bindTaggedPlateDescendants(instance: Instance)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") and CollectionService:HasTag(descendant, PLATE_TAG) then
			TycoonPlateService.BindPlate(descendant)
		end
	end
end

local function canUseOwner(player: Player, ownerUserId: number?): boolean
	return not ownerUserId or ownerUserId == player.UserId
end

local function isRateLimited(plate: BasePart, player: Player): boolean
	local now = os.clock()
	local touches = lastTouchByPlate[plate]
	if not touches then
		touches = {}
		lastTouchByPlate[plate] = touches
	end

	local lastTouch = touches[player.UserId]
	if lastTouch and now - lastTouch < TOUCH_RATE_LIMIT_SECONDS then
		return true
	end

	touches[player.UserId] = now
	return false
end

function TycoonPlateService.BuyPlate(player: Player, plate: BasePart, configOverride: PlateConfig?): boolean
	if disabledPlates[plate] or not currencyService then
		return false
	end

	local config = configOverride or getConfigFromAttributes(plate)
	local price = config.Price or 0
	if price < 0 then
		return false
	end

	local buildParent = resolveBuildParent(plate, config)
	local currentModel = resolveCurrentModel(buildParent, config)
	local existingOwnerUserId = resolveExistingOwnerUserId(plate, buildParent, currentModel, config)
	if not canUseOwner(player, existingOwnerUserId) then
		return false
	end

	local nextTemplate = resolveNextModel(config)
	if not nextTemplate then
		return false
	end

	if not currencyService.Spend(player, price) then
		return false
	end

	local ownerUserId = existingOwnerUserId or player.UserId
	local replacement = nextTemplate:Clone()
	if currentModel and currentModel:IsA("Model") then
		replacement:PivotTo(currentModel:GetPivot())
	elseif currentModel and currentModel:IsA("BasePart") then
		replacement:PivotTo(currentModel.CFrame)
	else
		replacement:PivotTo(plate.CFrame)
	end

	replacement.Parent = buildParent
	if currentModel then
		currentModel:Destroy()
	end

	plate:SetAttribute(OWNER_ATTRIBUTE_NAME, ownerUserId)
	if buildParent ~= workspace then
		buildParent:SetAttribute(OWNER_ATTRIBUTE_NAME, ownerUserId)
	end
	stampOwnerUserId(replacement, ownerUserId)
	bindTaggedPlateDescendants(replacement)

	if config.DisableAfterPurchase then
		disabledPlates[plate] = true
		plate.CanTouch = false
		plate.Transparency = 1
	end

	return true
end

function TycoonPlateService.BindPlate(plate: BasePart, config: PlateConfig?)
	if plateConnections[plate] then
		return
	end

	plateConnections[plate] = plate.Touched:Connect(function(touchedPart)
		local player = getPlayerFromTouchedPart(touchedPart)
		if not player or isRateLimited(plate, player) then
			return
		end

		TycoonPlateService.BuyPlate(player, plate, config)
	end)
end

function TycoonPlateService.Start(service: CurrencyService)
	if started then
		return
	end

	started = true
	currencyService = service

	for _, instance in CollectionService:GetTagged(PLATE_TAG) do
		if instance:IsA("BasePart") then
			TycoonPlateService.BindPlate(instance)
		end
	end

	CollectionService:GetInstanceAddedSignal(PLATE_TAG):Connect(function(instance)
		if instance:IsA("BasePart") then
			TycoonPlateService.BindPlate(instance)
		end
	end)
end

return TycoonPlateService
