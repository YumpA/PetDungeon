local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local PetDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetDefinitions"))

type PetDefinition = {
	DisplayName: string,
	MaxHP: number,
	Damage: number,
	FollowOffset: Vector3?,
}

type PetState = {
	PetId: string,
	Owner: Player,
	Model: Model,
	HP: number,
	MaxHP: number,
	Damage: number,
}

local PetService = {}

local DEFAULT_PET_ID = "StarterSlime"
local PET_MODELS_FOLDER_NAME = "PetModels"
local ACTIVE_PETS_FOLDER_NAME = "ActivePets"
local OWNER_ATTRIBUTE_NAME = "OwnerUserId"
local PET_ID_ATTRIBUTE_NAME = "PetId"
local PET_HP_ATTRIBUTE_NAME = "HP"
local PET_MAX_HP_ATTRIBUTE_NAME = "MaxHP"
local PET_DAMAGE_ATTRIBUTE_NAME = "Damage"

local activePets: { [Player]: PetState } = {}
local started = false

local function getActivePetsFolder(): Folder
	local folder = Workspace:FindFirstChild(ACTIVE_PETS_FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = ACTIVE_PETS_FOLDER_NAME
	newFolder.Parent = Workspace
	return newFolder
end

local function createFallbackPetModel(definition: PetDefinition): Model
	local model = Instance.new("Model")
	model.Name = definition.DisplayName

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2, 2, 2)
	body.Color = Color3.fromRGB(80, 220, 120)
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model

	model.PrimaryPart = body
	return model
end

local function getPetTemplate(petId: string): Model?
	local petModels = ServerStorage:FindFirstChild(PET_MODELS_FOLDER_NAME)
	if not petModels then
		return nil
	end

	local template = petModels:FindFirstChild(petId)
	if template and template:IsA("Model") then
		return template
	end

	return nil
end

local function findPrimaryPart(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local firstPart = model:FindFirstChildWhichIsA("BasePart", true)
	if firstPart then
		model.PrimaryPart = firstPart
	end

	return firstPart
end

local function preparePetPhysics(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end
end

local function attachPetToCharacter(model: Model, character: Model, followOffset: Vector3)
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	local petPart = findPrimaryPart(model)
	if not petPart then
		warn(`Pet model "{model.Name}" has no BasePart to follow the player.`)
		return false
	end

	local oldFollowAttachment = rootPart:FindFirstChild("PetFollowAttachment")
	if oldFollowAttachment then
		oldFollowAttachment:Destroy()
	end

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "PetFollowAttachment"
	targetAttachment.Position = followOffset
	targetAttachment.Parent = rootPart

	local petAttachment = Instance.new("Attachment")
	petAttachment.Name = "PetAttachment"
	petAttachment.Parent = petPart

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Name = "PetFollowPosition"
	alignPosition.Attachment0 = petAttachment
	alignPosition.Attachment1 = targetAttachment
	alignPosition.MaxForce = 30000
	alignPosition.Responsiveness = 18
	alignPosition.Parent = petPart

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "PetFollowOrientation"
	alignOrientation.Attachment0 = petAttachment
	alignOrientation.Attachment1 = targetAttachment
	alignOrientation.MaxTorque = 30000
	alignOrientation.Responsiveness = 18
	alignOrientation.Parent = petPart

	model:PivotTo(rootPart.CFrame * CFrame.new(followOffset))
	return true
end

local function setPetAttributes(model: Model, player: Player, petId: string, hp: number, maxHp: number, damage: number)
	model:SetAttribute(OWNER_ATTRIBUTE_NAME, player.UserId)
	model:SetAttribute(PET_ID_ATTRIBUTE_NAME, petId)
	model:SetAttribute(PET_HP_ATTRIBUTE_NAME, hp)
	model:SetAttribute(PET_MAX_HP_ATTRIBUTE_NAME, maxHp)
	model:SetAttribute(PET_DAMAGE_ATTRIBUTE_NAME, damage)
end

local function destroyPet(player: Player)
	local state = activePets[player]
	if not state then
		return
	end

	if state.Model then
		state.Model:Destroy()
	end

	activePets[player] = nil
end

function PetService.GivePet(player: Player, petId: string?): Model?
	local resolvedPetId = petId or DEFAULT_PET_ID
	local definition = PetDefinitions[resolvedPetId] :: PetDefinition?
	if not definition then
		warn(`Unknown pet id "{resolvedPetId}".`)
		return nil
	end

	local character = player.Character
	if not character then
		return nil
	end

	destroyPet(player)

	local template = getPetTemplate(resolvedPetId)
	local model = if template then template:Clone() else createFallbackPetModel(definition)
	model.Name = `{player.Name}_{resolvedPetId}`

	local maxHp = definition.MaxHP
	local damage = definition.Damage
	local followOffset = definition.FollowOffset or Vector3.new(3, 1.5, 2)

	setPetAttributes(model, player, resolvedPetId, maxHp, maxHp, damage)
	preparePetPhysics(model)
	model.Parent = getActivePetsFolder()

	if not attachPetToCharacter(model, character, followOffset) then
		model:Destroy()
		return nil
	end

	activePets[player] = {
		PetId = resolvedPetId,
		Owner = player,
		Model = model,
		HP = maxHp,
		MaxHP = maxHp,
		Damage = damage,
	}

	return model
end

function PetService.GetPetStats(player: Player)
	local state = activePets[player]
	if not state then
		return nil
	end

	return {
		PetId = state.PetId,
		HP = state.HP,
		MaxHP = state.MaxHP,
		Damage = state.Damage,
	}
end

function PetService.DamagePet(player: Player, amount: number): boolean
	local state = activePets[player]
	if not state or amount <= 0 then
		return false
	end

	state.HP = math.max(0, state.HP - amount)
	state.Model:SetAttribute(PET_HP_ATTRIBUTE_NAME, state.HP)

	if state.HP == 0 then
		state.Model:Destroy()
		activePets[player] = nil
	end

	return true
end

local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			PetService.GivePet(player, DEFAULT_PET_ID)
		end)
	end)

	if player.Character then
		task.defer(function()
			PetService.GivePet(player, DEFAULT_PET_ID)
		end)
	end
end

function PetService.Start()
	if started then
		return
	end

	started = true

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(destroyPet)

	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return PetService
