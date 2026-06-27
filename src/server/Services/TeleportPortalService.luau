local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local DungeonDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DungeonDefinitions"))

local TeleportPortalService = {}

local PORTAL_MODEL_NAME = "DungeonPortal"
local PORTAL_PART_NAME = "PortalPart"
local PROMPT_NAME = "DungeonPortalPrompt"
local PROMPT_ACTION_TEXT = "Dungeons"
local PROMPT_OBJECT_TEXT = "Portal"
local PROMPT_DISTANCE = 12
local REMOTES_FOLDER_NAME = "Remotes"
local TELEPORT_REMOTES_FOLDER_NAME = "Teleport"
local REQUEST_TELEPORT_REMOTE_NAME = "RequestTeleport"
local TELEPORT_RATE_LIMIT_SECONDS = 3

local lastTeleportRequestByPlayer: { [Player]: number } = {}
local started = false

local function getTeleportRemotesFolder(): Folder
	local remotesFolder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = REMOTES_FOLDER_NAME
		remotesFolder.Parent = ReplicatedStorage
	end

	local teleportRemotesFolder = remotesFolder:FindFirstChild(TELEPORT_REMOTES_FOLDER_NAME)
	if teleportRemotesFolder and teleportRemotesFolder:IsA("Folder") then
		return teleportRemotesFolder
	end

	local newTeleportRemotesFolder = Instance.new("Folder")
	newTeleportRemotesFolder.Name = TELEPORT_REMOTES_FOLDER_NAME
	newTeleportRemotesFolder.Parent = remotesFolder
	return newTeleportRemotesFolder
end

local function getRequestTeleportRemote(): RemoteEvent
	local teleportRemotesFolder = getTeleportRemotesFolder()
	local existingRemote = teleportRemotesFolder:FindFirstChild(REQUEST_TELEPORT_REMOTE_NAME)
	if existingRemote and existingRemote:IsA("RemoteEvent") then
		return existingRemote
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = REQUEST_TELEPORT_REMOTE_NAME
	remote.Parent = teleportRemotesFolder
	return remote
end

local function getOrCreatePortal(): Model
	local existingPortal = Workspace:FindFirstChild(PORTAL_MODEL_NAME)
	if existingPortal and existingPortal:IsA("Model") then
		return existingPortal
	end

	local portal = Instance.new("Model")
	portal.Name = PORTAL_MODEL_NAME
	portal.Parent = Workspace

	local portalPart = Instance.new("Part")
	portalPart.Name = PORTAL_PART_NAME
	portalPart.Anchored = true
	portalPart.CanCollide = false
	portalPart.Size = Vector3.new(8, 10, 2)
	portalPart.Position = Vector3.new(0, 5, 0)
	portalPart.Color = Color3.fromRGB(90, 80, 230)
	portalPart.Material = Enum.Material.Neon
	portalPart.Parent = portal

	portal.PrimaryPart = portalPart
	return portal
end

local function findPortalPart(portal: Model): BasePart?
	local primaryPart = portal.PrimaryPart
	if primaryPart then
		return primaryPart
	end

	local namedPart = portal:FindFirstChild(PORTAL_PART_NAME)
	if namedPart and namedPart:IsA("BasePart") then
		portal.PrimaryPart = namedPart
		return namedPart
	end

	local firstPart = portal:FindFirstChildWhichIsA("BasePart", true)
	if firstPart then
		portal.PrimaryPart = firstPart
	end

	return firstPart
end

local function createPrompt(portalPart: BasePart)
	local existingPrompt = portalPart:FindFirstChild(PROMPT_NAME)
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
	prompt.Parent = portalPart
end

local function isRateLimited(player: Player): boolean
	local now = os.clock()
	local lastRequest = lastTeleportRequestByPlayer[player]
	if lastRequest and now - lastRequest < TELEPORT_RATE_LIMIT_SECONDS then
		return true
	end

	lastTeleportRequestByPlayer[player] = now
	return false
end

function TeleportPortalService.TeleportPlayerToDungeon(player: Player, dungeonId: string): boolean
	if typeof(dungeonId) ~= "string" or isRateLimited(player) then
		return false
	end

	local definition = DungeonDefinitions[dungeonId]
	if not definition then
		return false
	end

	local placeId = definition.PlaceId
	if typeof(placeId) ~= "number" or placeId <= 0 then
		warn(`Dungeon "{dungeonId}" does not have a valid PlaceId. Set it in Shared.DungeonDefinitions.`)
		return false
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData({
		DungeonId = dungeonId,
		FromPlaceId = game.PlaceId,
	})

	local success, result = pcall(function()
		return TeleportService:TeleportAsync(placeId, { player }, teleportOptions)
	end)

	if not success then
		warn(`Failed to teleport {player.Name} to "{dungeonId}": {result}`)
		return false
	end

	return true
end

function TeleportPortalService.Start()
	if started then
		return
	end

	started = true

	local portal = getOrCreatePortal()
	local portalPart = findPortalPart(portal)
	if portalPart then
		createPrompt(portalPart)
	end

	getRequestTeleportRemote().OnServerEvent:Connect(function(player, dungeonId)
		TeleportPortalService.TeleportPlayerToDungeon(player, dungeonId)
	end)
end

return TeleportPortalService
