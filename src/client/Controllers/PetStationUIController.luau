local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local PetStationUIController = {}

local LOCAL_PLAYER = Players.LocalPlayer
local PROMPT_NAME = "PetStationPrompt"

local screenGui: ScreenGui? = nil
local choosePetPage: Frame? = nil
local levelUpPage: Frame? = nil
local chooseTabButton: TextButton? = nil
local levelTabButton: TextButton? = nil

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

local function setActiveTab(tabName: string)
	if not choosePetPage or not levelUpPage or not chooseTabButton or not levelTabButton then
		return
	end

	local isChoosingPet = tabName == "ChoosePet"
	choosePetPage.Visible = isChoosingPet
	levelUpPage.Visible = not isChoosingPet

	chooseTabButton.BackgroundColor3 = if isChoosingPet then Color3.fromRGB(74, 144, 226) else Color3.fromRGB(42, 49, 60)
	levelTabButton.BackgroundColor3 = if isChoosingPet then Color3.fromRGB(42, 49, 60) else Color3.fromRGB(74, 144, 226)
end

local function buildGui()
	if screenGui then
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
	mainFrame.Size = UDim2.fromOffset(520, 340)
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

	createTextLabel(
		choosePetPage,
		"Your available pets will appear here.",
		UDim2.new(1, -32, 0, 32),
		UDim2.fromOffset(16, 16)
	)

	createTextLabel(
		choosePetPage,
		"Starter Slime",
		UDim2.new(1, -32, 0, 48),
		UDim2.fromOffset(16, 72)
	)

	createTextLabel(
		levelUpPage,
		"Select a pet to spend resources and increase its HP and damage.",
		UDim2.new(1, -32, 0, 48),
		UDim2.fromOffset(16, 16)
	)

	createTextLabel(
		levelUpPage,
		"Starter Slime: HP 100 / Damage 12",
		UDim2.new(1, -32, 0, 48),
		UDim2.fromOffset(16, 80)
	)

	chooseTabButton.Activated:Connect(function()
		setActiveTab("ChoosePet")
	end)

	levelTabButton.Activated:Connect(function()
		setActiveTab("LevelUpPet")
	end)

	setActiveTab("ChoosePet")
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
