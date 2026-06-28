local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DungeonDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DungeonDefinitions"))

local TeleportPortalUIController = {}

local LOCAL_PLAYER = Players.LocalPlayer
local PROMPT_NAME = "DungeonPortalPrompt"
local REQUEST_TELEPORT_REMOTE_NAME = "RequestTeleport"
local CREATE_PARTY_REMOTE_NAME = "CreateParty"
local JOIN_PARTY_REMOTE_NAME = "JoinParty"
local LEAVE_PARTY_REMOTE_NAME = "LeaveParty"
local PARTY_STATE_CHANGED_REMOTE_NAME = "PartyStateChanged"
local GET_PARTY_STATE_FUNCTION_NAME = "GetPartyState"

local screenGui: ScreenGui? = nil
local partyList: ScrollingFrame? = nil
local mapList: ScrollingFrame? = nil
local requestTeleportRemote: RemoteEvent? = nil
local createPartyRemote: RemoteEvent? = nil
local joinPartyRemote: RemoteEvent? = nil
local leavePartyRemote: RemoteEvent? = nil
local getPartyStateFunction: RemoteFunction? = nil
local currentPartySnapshot = {}

local function getRequestTeleportRemote(): RemoteEvent
	if requestTeleportRemote then
		return requestTeleportRemote
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local teleportRemotes = remotes:WaitForChild("Teleport")
	requestTeleportRemote = teleportRemotes:WaitForChild(REQUEST_TELEPORT_REMOTE_NAME) :: RemoteEvent
	return requestTeleportRemote
end

local function getPartyRemote(remoteName: string): RemoteEvent
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local partyRemotes = remotes:WaitForChild("Parties")
	return partyRemotes:WaitForChild(remoteName) :: RemoteEvent
end

local function getCreatePartyRemote(): RemoteEvent
	if createPartyRemote then
		return createPartyRemote
	end

	createPartyRemote = getPartyRemote(CREATE_PARTY_REMOTE_NAME)
	return createPartyRemote
end

local function getJoinPartyRemote(): RemoteEvent
	if joinPartyRemote then
		return joinPartyRemote
	end

	joinPartyRemote = getPartyRemote(JOIN_PARTY_REMOTE_NAME)
	return joinPartyRemote
end

local function getLeavePartyRemote(): RemoteEvent
	if leavePartyRemote then
		return leavePartyRemote
	end

	leavePartyRemote = getPartyRemote(LEAVE_PARTY_REMOTE_NAME)
	return leavePartyRemote
end

local function getPartyStateRemoteFunction(): RemoteFunction
	if getPartyStateFunction then
		return getPartyStateFunction
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local partyRemotes = remotes:WaitForChild("Parties")
	getPartyStateFunction = partyRemotes:WaitForChild(GET_PARTY_STATE_FUNCTION_NAME) :: RemoteFunction
	return getPartyStateFunction
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

local function getLocalParty()
	for _, party in currentPartySnapshot do
		for _, member in party.Members do
			if member.UserId == LOCAL_PLAYER.UserId then
				return party
			end
		end
	end

	return nil
end

local function createPartyRow(parent: Instance, party)
	local row = Instance.new("Frame")
	row.BackgroundColor3 = Color3.fromRGB(40, 47, 58)
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -8, 0, 62)
	row.Parent = parent

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = `{party.LeaderDisplayName}'s Group`
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -120, 0, 22)
	title.Parent = row

	local memberNames = {}
	for _, member in party.Members do
		table.insert(memberNames, member.DisplayName)
	end

	local members = Instance.new("TextLabel")
	members.BackgroundTransparency = 1
	members.Font = Enum.Font.Gotham
	members.Text = `{table.concat(memberNames, ", ")} ({party.MemberCount}/{party.MaxMembers})`
	members.TextColor3 = Color3.fromRGB(190, 199, 211)
	members.TextSize = 13
	members.TextXAlignment = Enum.TextXAlignment.Left
	members.Position = UDim2.fromOffset(12, 32)
	members.Size = UDim2.new(1, -120, 0, 20)
	members.Parent = row

	local localParty = getLocalParty()
	local joinButton = Instance.new("TextButton")
	joinButton.AutoButtonColor = true
	joinButton.BackgroundColor3 = Color3.fromRGB(74, 144, 226)
	joinButton.BorderSizePixel = 0
	joinButton.Font = Enum.Font.GothamBold
	joinButton.Text = "Join"
	joinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	joinButton.TextSize = 13
	joinButton.Position = UDim2.new(1, -90, 0, 15)
	joinButton.Size = UDim2.fromOffset(72, 32)
	joinButton.Visible = not localParty and party.MemberCount < party.MaxMembers
	joinButton.Parent = row

	joinButton.Activated:Connect(function()
		getJoinPartyRemote():FireServer(party.LeaderUserId)
	end)

	return row
end

local function populateParties()
	if not partyList then
		return
	end

	for _, child in partyList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for index, party in ipairs(currentPartySnapshot) do
		local row = createPartyRow(partyList, party)
		row.LayoutOrder = index
	end
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
		populateParties()
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
	mainFrame.Size = UDim2.fromOffset(620, 520)
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

	local localPartyLabel = Instance.new("TextLabel")
	localPartyLabel.BackgroundTransparency = 1
	localPartyLabel.Font = Enum.Font.Gotham
	localPartyLabel.Text = "Create a group, join one, then the leader teleports everyone to a private dungeon server."
	localPartyLabel.TextColor3 = Color3.fromRGB(190, 199, 211)
	localPartyLabel.TextSize = 14
	localPartyLabel.TextWrapped = true
	localPartyLabel.TextXAlignment = Enum.TextXAlignment.Left
	localPartyLabel.Position = UDim2.fromOffset(24, 52)
	localPartyLabel.Size = UDim2.new(1, -48, 0, 38)
	localPartyLabel.Parent = mainFrame

	local createPartyButton = Instance.new("TextButton")
	createPartyButton.AutoButtonColor = true
	createPartyButton.BackgroundColor3 = Color3.fromRGB(74, 144, 226)
	createPartyButton.BorderSizePixel = 0
	createPartyButton.Font = Enum.Font.GothamBold
	createPartyButton.Text = "Create Group"
	createPartyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	createPartyButton.TextSize = 14
	createPartyButton.Position = UDim2.fromOffset(24, 96)
	createPartyButton.Size = UDim2.fromOffset(132, 34)
	createPartyButton.Parent = mainFrame

	local leavePartyButton = Instance.new("TextButton")
	leavePartyButton.AutoButtonColor = true
	leavePartyButton.BackgroundColor3 = Color3.fromRGB(170, 70, 76)
	leavePartyButton.BorderSizePixel = 0
	leavePartyButton.Font = Enum.Font.GothamBold
	leavePartyButton.Text = "Leave Group"
	leavePartyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	leavePartyButton.TextSize = 14
	leavePartyButton.Position = UDim2.fromOffset(166, 96)
	leavePartyButton.Size = UDim2.fromOffset(124, 34)
	leavePartyButton.Parent = mainFrame

	createPartyButton.Activated:Connect(function()
		getCreatePartyRemote():FireServer()
	end)

	leavePartyButton.Activated:Connect(function()
		getLeavePartyRemote():FireServer()
	end)

	partyList = Instance.new("ScrollingFrame")
	partyList.BackgroundColor3 = Color3.fromRGB(32, 38, 48)
	partyList.BorderSizePixel = 0
	partyList.CanvasSize = UDim2.fromOffset(0, 0)
	partyList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	partyList.ScrollBarThickness = 6
	partyList.Position = UDim2.fromOffset(24, 142)
	partyList.Size = UDim2.new(1, -48, 0, 144)
	partyList.Parent = mainFrame

	local partyLayout = Instance.new("UIListLayout")
	partyLayout.Padding = UDim.new(0, 8)
	partyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	partyLayout.Parent = partyList

	mapList = Instance.new("ScrollingFrame")
	mapList.BackgroundColor3 = Color3.fromRGB(32, 38, 48)
	mapList.BorderSizePixel = 0
	mapList.CanvasSize = UDim2.fromOffset(0, 0)
	mapList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	mapList.ScrollBarThickness = 6
	mapList.Position = UDim2.fromOffset(24, 304)
	mapList.Size = UDim2.new(1, -48, 1, -328)
	mapList.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = mapList

	populateParties()
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

	getPartyRemote(PARTY_STATE_CHANGED_REMOTE_NAME).OnClientEvent:Connect(function(snapshot)
		if typeof(snapshot) == "table" then
			currentPartySnapshot = snapshot
			populateParties()
		end
	end)

	local success, snapshot = pcall(function()
		return getPartyStateRemoteFunction():InvokeServer()
	end)

	if success and typeof(snapshot) == "table" then
		currentPartySnapshot = snapshot
		populateParties()
	end

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
