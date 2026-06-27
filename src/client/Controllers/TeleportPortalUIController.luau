local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DungeonDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DungeonDefinitions"))

local TeleportPortalUIController = {}

local LOCAL_PLAYER = Players.LocalPlayer
local PROMPT_NAME = "DungeonPortalPrompt"
local REQUEST_TELEPORT_REMOTE_NAME = "RequestTeleport"

local screenGui: ScreenGui? = nil
local mapList: ScrollingFrame? = nil
local requestTeleportRemote: RemoteEvent? = nil

local function getRequestTeleportRemote(): RemoteEvent
	if requestTeleportRemote then
		return requestTeleportRemote
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local teleportRemotes = remotes:WaitForChild("Teleport")
	requestTeleportRemote = teleportRemotes:WaitForChild(REQUEST_TELEPORT_REMOTE_NAME) :: RemoteEvent
	return requestTeleportRemote
end

local function getSortedDungeonEntries()
	local entries = {}

	for dungeonId, definition in DungeonDefinitions do
		table.insert(entries, {
			DungeonId = dungeonId,
			Definition = definition,
		})
	end

	table.sort(entries, function(left, right)
		local leftOrder = left.Definition.Order or 999
		local rightOrder = right.Definition.Order or 999
		if leftOrder == rightOrder then
			return left.DungeonId < right.DungeonId
		end

		return leftOrder < rightOrder
	end)

	return entries
end

local function createMapRow(parent: Instance, dungeonId: string, definition)
	local row = Instance.new("Frame")
	row.BackgroundColor3 = Color3.fromRGB(40, 47, 58)
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -8, 0, 78)
	row.Parent = parent

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = definition.DisplayName or dungeonId
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 17
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Position = UDim2.fromOffset(16, 10)
	nameLabel.Size = UDim2.new(1, -150, 0, 24)
	nameLabel.Parent = row

	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Font = Enum.Font.Gotham
	descriptionLabel.Text = definition.Description or dungeonId
	descriptionLabel.TextColor3 = Color3.fromRGB(190, 199, 211)
	descriptionLabel.TextSize = 14
	descriptionLabel.TextWrapped = true
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.Position = UDim2.fromOffset(16, 38)
	descriptionLabel.Size = UDim2.new(1, -150, 0, 30)
	descriptionLabel.Parent = row

	local teleportButton = Instance.new("TextButton")
	teleportButton.AutoButtonColor = true
	teleportButton.BackgroundColor3 = Color3.fromRGB(90, 80, 230)
	teleportButton.BorderSizePixel = 0
	teleportButton.Font = Enum.Font.GothamBold
	teleportButton.Text = "Teleport"
	teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	teleportButton.TextSize = 14
	teleportButton.Position = UDim2.new(1, -116, 0, 21)
	teleportButton.Size = UDim2.fromOffset(96, 36)
	teleportButton.Parent = row

	teleportButton.Activated:Connect(function()
		getRequestTeleportRemote():FireServer(dungeonId)
	end)

	return row
end

local function populateMaps()
	if not mapList then
		return
	end

	for _, child in mapList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for index, entry in ipairs(getSortedDungeonEntries()) do
		local row = createMapRow(mapList, entry.DungeonId, entry.Definition)
		row.LayoutOrder = index
	end
end

local function buildGui()
	if screenGui then
		populateMaps()
		return
	end

	local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DungeonPortalGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local mainFrame = Instance.new("Frame")
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 38)
	mainFrame.BorderSizePixel = 0
	mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	mainFrame.Size = UDim2.fromOffset(500, 320)
	mainFrame.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "Choose Dungeon"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(24, 18)
	title.Size = UDim2.new(1, -48, 0, 32)
	title.Parent = mainFrame

	mapList = Instance.new("ScrollingFrame")
	mapList.BackgroundColor3 = Color3.fromRGB(32, 38, 48)
	mapList.BorderSizePixel = 0
	mapList.CanvasSize = UDim2.fromOffset(0, 0)
	mapList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	mapList.ScrollBarThickness = 6
	mapList.Position = UDim2.fromOffset(24, 68)
	mapList.Size = UDim2.new(1, -48, 1, -92)
	mapList.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = mapList

	populateMaps()
end

local function setGuiVisible(isVisible: boolean)
	buildGui()

	if screenGui then
		screenGui.Enabled = isVisible
	end
end

function TeleportPortalUIController.Start()
	buildGui()

	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt.Name == PROMPT_NAME then
			setGuiVisible(true)
		end
	end)

	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt.Name == PROMPT_NAME then
			setGuiVisible(false)
		end
	end)
end

return TeleportPortalUIController
