local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetDefinitions"))

local PetStationUIController = {}

local LOCAL_PLAYER = Players.LocalPlayer
local PROMPT_NAME = "PetStationPrompt"
local SELECT_PET_REMOTE_NAME = "SelectPet"

local screenGui: ScreenGui? = nil
local choosePetPage: Frame? = nil
local levelUpPage: Frame? = nil
local chooseTabButton: TextButton? = nil
local levelTabButton: TextButton? = nil
local selectedPetId = "StarterSlime"
local selectPetRemote: RemoteEvent? = nil
local buildGui: () -> ()
local setActiveTab: (string) -> ()

local function getSelectPetRemote(): RemoteEvent
	if selectPetRemote then
		return selectPetRemote
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local petRemotes = remotes:WaitForChild("Pets")
	selectPetRemote = petRemotes:WaitForChild(SELECT_PET_REMOTE_NAME) :: RemoteEvent
	return selectPetRemote
end

local function getSortedPetEntries()
	local entries = {}

	for petId, definition in PetDefinitions do
		table.insert(entries, {
			PetId = petId,
			Definition = definition,
		})
	end

	table.sort(entries, function(left, right)
		local leftOrder = left.Definition.Order or 999
		local rightOrder = right.Definition.Order or 999
		if leftOrder == rightOrder then
			return left.PetId < right.PetId
		end

		return leftOrder < rightOrder
	end)

	return entries
end

local function createTextLabel(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.Text = text
	label.TextColor3 = Color3.fromRGB(236, 240, 244)
	label.TextSize = 16
	label.TextWrapped = true
	label.Size = size
	label.Position = position
	label.Parent = parent
	return label
end

local function createTabButton(parent: Instance, text: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(42, 49, 60)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(236, 240, 244)
	button.TextSize = 15
	button.Size = UDim2.fromOffset(150, 38)
	button.Position = position
	button.Parent = parent
	return button
end

local function createPetRow(parent: Instance, petId: string, definition): Frame
	local row = Instance.new("Frame")
	row.BackgroundColor3 = Color3.fromRGB(40, 47, 58)
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -8, 0, 72)
	row.Parent = parent

	local swatch = Instance.new("Frame")
	swatch.BackgroundColor3 = definition.Color or Color3.fromRGB(80, 220, 120)
	swatch.BorderSizePixel = 0
	swatch.Position = UDim2.fromOffset(12, 12)
	swatch.Size = UDim2.fromOffset(48, 48)
	swatch.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = `{definition.DisplayName}  [{petId}]`
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 15
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Position = UDim2.fromOffset(76, 10)
	nameLabel.Size = UDim2.new(1, -210, 0, 24)
	nameLabel.Parent = row

	local statsLabel = Instance.new("TextLabel")
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.Text = `HP {definition.MaxHP} / Damage {definition.Damage}`
	statsLabel.TextColor3 = Color3.fromRGB(190, 199, 211)
	statsLabel.TextSize = 14
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.Position = UDim2.fromOffset(76, 38)
	statsLabel.Size = UDim2.new(1, -210, 0, 20)
	statsLabel.Parent = row

	local equipButton = Instance.new("TextButton")
	equipButton.AutoButtonColor = true
	equipButton.BackgroundColor3 = if selectedPetId == petId then Color3.fromRGB(66, 160, 92) else Color3.fromRGB(74, 144, 226)
	equipButton.BorderSizePixel = 0
	equipButton.Font = Enum.Font.GothamBold
	equipButton.Text = if selectedPetId == petId then "Equipped" else "Equip"
	equipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	equipButton.TextSize = 14
	equipButton.Position = UDim2.new(1, -110, 0, 18)
	equipButton.Size = UDim2.fromOffset(90, 36)
	equipButton.Parent = row

	equipButton.Activated:Connect(function()
		selectedPetId = petId
		getSelectPetRemote():FireServer(petId)
		buildGui()
	end)

	return row
end

local function populateChoosePetPage()
	if not choosePetPage then
		return
	end

	for _, child in choosePetPage:GetChildren() do
		child:Destroy()
	end

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.Position = UDim2.fromOffset(12, 12)
	list.Size = UDim2.new(1, -24, 1, -24)
	list.Parent = choosePetPage

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index, entry in ipairs(getSortedPetEntries()) do
		local row = createPetRow(list, entry.PetId, entry.Definition)
		row.LayoutOrder = index
	end
end

local function populateLevelUpPage()
	if not levelUpPage then
		return
	end

	for _, child in levelUpPage:GetChildren() do
		child:Destroy()
	end

	local selectedDefinition = PetDefinitions[selectedPetId]
	if not selectedDefinition then
		return
	end

	createTextLabel(
		levelUpPage,
		`Selected: {selectedDefinition.DisplayName} [{selectedPetId}]`,
		UDim2.new(1, -32, 0, 32),
		UDim2.fromOffset(16, 16)
	)

	createTextLabel(
		levelUpPage,
		`Current Stats: HP {selectedDefinition.MaxHP} / Damage {selectedDefinition.Damage}`,
		UDim2.new(1, -32, 0, 32),
		UDim2.fromOffset(16, 60)
	)
end

buildGui = function()
	if screenGui then
		populateChoosePetPage()
		populateLevelUpPage()
		return
	end

	local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PetStationGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local mainFrame = Instance.new("Frame")
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 38)
	mainFrame.BorderSizePixel = 0
	mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	mainFrame.Size = UDim2.fromOffset(560, 380)
	mainFrame.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "Pet Station"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(24, 16)
	title.Size = UDim2.new(1, -48, 0, 32)
	title.Parent = mainFrame

	chooseTabButton = createTabButton(mainFrame, "Choose a Pet", UDim2.fromOffset(24, 64))
	levelTabButton = createTabButton(mainFrame, "Level Up Pet", UDim2.fromOffset(184, 64))

	choosePetPage = Instance.new("Frame")
	choosePetPage.BackgroundColor3 = Color3.fromRGB(32, 38, 48)
	choosePetPage.BorderSizePixel = 0
	choosePetPage.Position = UDim2.fromOffset(24, 112)
	choosePetPage.Size = UDim2.new(1, -48, 1, -136)
	choosePetPage.Parent = mainFrame

	levelUpPage = Instance.new("Frame")
	levelUpPage.BackgroundColor3 = Color3.fromRGB(32, 38, 48)
	levelUpPage.BorderSizePixel = 0
	levelUpPage.Position = UDim2.fromOffset(24, 112)
	levelUpPage.Size = UDim2.new(1, -48, 1, -136)
	levelUpPage.Parent = mainFrame

	chooseTabButton.Activated:Connect(function()
		setActiveTab("ChoosePet")
	end)

	levelTabButton.Activated:Connect(function()
		setActiveTab("LevelUpPet")
	end)

	populateChoosePetPage()
	populateLevelUpPage()
	setActiveTab("ChoosePet")
end

setActiveTab = function(tabName: string)
	if not choosePetPage or not levelUpPage or not chooseTabButton or not levelTabButton then
		return
	end

	local isChoosingPet = tabName == "ChoosePet"
	choosePetPage.Visible = isChoosingPet
	levelUpPage.Visible = not isChoosingPet

	chooseTabButton.BackgroundColor3 = if isChoosingPet then Color3.fromRGB(74, 144, 226) else Color3.fromRGB(42, 49, 60)
	levelTabButton.BackgroundColor3 = if isChoosingPet then Color3.fromRGB(42, 49, 60) else Color3.fromRGB(74, 144, 226)
end

local function setGuiVisible(isVisible: boolean)
	buildGui()

	if screenGui then
		screenGui.Enabled = isVisible
	end
end

function PetStationUIController.Start()
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

return PetStationUIController
