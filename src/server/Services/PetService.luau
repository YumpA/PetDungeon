local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local PetDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetDefinitions"))

type PetDefinition = {
	DisplayName: string,
	MaxHP: number,
	Damage: number,
	Order: number?,
	Color: Color3?,
	FollowOffset: Vector3?,
}

type PetState = {
	PetId: string,
	Owner: Player,
	Model: Model,
	HP: number,
	MaxHP: number,
	Damage: number,
	FollowOffset: Vector3,
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
local REMOTES_FOLDER_NAME = "Remotes"
local PET_REMOTES_FOLDER_NAME = "Pets"
local SELECT_PET_REMOTE_NAME = "SelectPet"
local ENEMIES_FOLDER_NAME = "Enemies"
local ENEMY_TAG = "Enemy"
local ENEMY_HP_ATTRIBUTE_NAME = "HP"
local PET_FOLLOW_ATTACHMENT_NAME = "PetFollowAttachment"
local PET_ATTACK_TARGET_ATTACHMENT_NAME = "PetAttackTargetAttachment"
local PET_FOLLOW_POSITION_NAME = "PetFollowPosition"
local PET_FOLLOW_ORIENTATION_NAME = "PetFollowOrientation"
local ATTACK_SEARCH_RADIUS = 55
local ATTACK_RANGE = 4
local ATTACK_COOLDOWN_SECONDS = 1
local ATTACK_LOOP_WAIT_SECONDS = 0.25
local MOVE_TO_ENEMY_TIMEOUT_SECONDS = 3

local activePets: { [Player]: PetState } = {}
local selectedPetIds: { [Player]: string } = {}
local attackLoopIds: { [Player]: number } = {}
local started = false

local function getPetRemotesFolder(): Folder
	local remotesFolder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = REMOTES_FOLDER_NAME
		remotesFolder.Parent = ReplicatedStorage
	end

	local petRemotesFolder = remotesFolder:FindFirstChild(PET_REMOTES_FOLDER_NAME)
	if petRemotesFolder and petRemotesFolder:IsA("Folder") then
		return petRemotesFolder
	end

	local newPetRemotesFolder = Instance.new("Folder")
	newPetRemotesFolder.Name = PET_REMOTES_FOLDER_NAME
	newPetRemotesFolder.Parent = remotesFolder
	return newPetRemotesFolder
end

local function getSelectPetRemote(): RemoteEvent
	local petRemotesFolder = getPetRemotesFolder()
	local existingRemote = petRemotesFolder:FindFirstChild(SELECT_PET_REMOTE_NAME)
	if existingRemote and existingRemote:IsA("RemoteEvent") then
		return existingRemote
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = SELECT_PET_REMOTE_NAME
	remote.Parent = petRemotesFolder
	return remote
end

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
	body.Color = definition.Color or Color3.fromRGB(80, 220, 120)
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

local function getCharacterRootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
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

	local oldFollowAttachment = rootPart:FindFirstChild(PET_FOLLOW_ATTACHMENT_NAME)
	if oldFollowAttachment then
		oldFollowAttachment:Destroy()
	end

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = PET_FOLLOW_ATTACHMENT_NAME
	targetAttachment.Position = followOffset
	targetAttachment.Parent = rootPart

	local petAttachment = Instance.new("Attachment")
	petAttachment.Name = "PetAttachment"
	petAttachment.Parent = petPart

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Name = PET_FOLLOW_POSITION_NAME
	alignPosition.Attachment0 = petAttachment
	alignPosition.Attachment1 = targetAttachment
	alignPosition.MaxForce = 30000
	alignPosition.Responsiveness = 18
	alignPosition.Parent = petPart

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = PET_FOLLOW_ORIENTATION_NAME
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

local function getEnemyRootPart(enemy: Model): BasePart?
	local primaryPart = enemy.PrimaryPart
	if primaryPart then
		return primaryPart
	end

	local humanoidRootPart = enemy:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		enemy.PrimaryPart = humanoidRootPart
		return humanoidRootPart
	end

	local firstPart = enemy:FindFirstChildWhichIsA("BasePart", true)
	if firstPart then
		enemy.PrimaryPart = firstPart
	end

	return firstPart
end

local function isEnemyAlive(enemy: Model): boolean
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.Health > 0
	end

	local hp = enemy:GetAttribute(ENEMY_HP_ATTRIBUTE_NAME)
	return typeof(hp) == "number" and hp > 0
end

local function getEnemyCandidates(): { Model }
	local candidates = {}
	local added: { [Model]: boolean } = {}

	local enemiesFolder = Workspace:FindFirstChild(ENEMIES_FOLDER_NAME)
	if enemiesFolder then
		for _, descendant in enemiesFolder:GetDescendants() do
			if descendant:IsA("Model") and not added[descendant] then
				table.insert(candidates, descendant)
				added[descendant] = true
			end
		end
	end

	for _, instance in CollectionService:GetTagged(ENEMY_TAG) do
		local enemy = if instance:IsA("Model") then instance else instance:FindFirstAncestorOfClass("Model")
		if enemy and not added[enemy] then
			table.insert(candidates, enemy)
			added[enemy] = true
		end
	end

	return candidates
end

local function findNearestEnemy(state: PetState): Model?
	local ownerRootPart = getCharacterRootPart(state.Owner)
	if not ownerRootPart then
		return nil
	end

	local nearestEnemy = nil
	local nearestDistance = ATTACK_SEARCH_RADIUS

	for _, enemy in getEnemyCandidates() do
		if isEnemyAlive(enemy) then
			local enemyRootPart = getEnemyRootPart(enemy)
			if enemyRootPart then
				local distance = (enemyRootPart.Position - ownerRootPart.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestEnemy = enemy
				end
			end
		end
	end

	return nearestEnemy
end

local function setPetTargetAttachment(state: PetState, targetAttachment: Attachment): boolean
	local petPart = findPrimaryPart(state.Model)
	if not petPart then
		return false
	end

	local alignPosition = petPart:FindFirstChild(PET_FOLLOW_POSITION_NAME)
	local alignOrientation = petPart:FindFirstChild(PET_FOLLOW_ORIENTATION_NAME)
	if not alignPosition or not alignPosition:IsA("AlignPosition") then
		return false
	end

	alignPosition.Attachment1 = targetAttachment

	if alignOrientation and alignOrientation:IsA("AlignOrientation") then
		alignOrientation.Attachment1 = targetAttachment
	end

	return true
end

local function moveToEnemy(state: PetState, enemy: Model): boolean
	local enemyRootPart = getEnemyRootPart(enemy)
	local petPart = findPrimaryPart(state.Model)
	if not enemyRootPart or not petPart then
		return false
	end

	local targetAttachment = enemyRootPart:FindFirstChild(PET_ATTACK_TARGET_ATTACHMENT_NAME)
	if not targetAttachment or not targetAttachment:IsA("Attachment") then
		targetAttachment = Instance.new("Attachment")
		targetAttachment.Name = PET_ATTACK_TARGET_ATTACHMENT_NAME
		targetAttachment.Parent = enemyRootPart
	end

	if not setPetTargetAttachment(state, targetAttachment) then
		return false
	end

	local startTime = os.clock()
	while os.clock() - startTime < MOVE_TO_ENEMY_TIMEOUT_SECONDS do
		if activePets[state.Owner] ~= state or not state.Model.Parent or not isEnemyAlive(enemy) then
			return false
		end

		if (petPart.Position - enemyRootPart.Position).Magnitude <= ATTACK_RANGE then
			return true
		end

		task.wait(ATTACK_LOOP_WAIT_SECONDS)
	end

	return false
end

local function attack(state: PetState, enemy: Model): boolean
	if activePets[state.Owner] ~= state or not isEnemyAlive(enemy) then
		return false
	end

	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(state.Damage)
		return true
	end

	local hp = enemy:GetAttribute(ENEMY_HP_ATTRIBUTE_NAME)
	if typeof(hp) ~= "number" then
		return false
	end

	local newHp = math.max(0, hp - state.Damage)
	enemy:SetAttribute(ENEMY_HP_ATTRIBUTE_NAME, newHp)
	if newHp == 0 then
		enemy:Destroy()
	end

	return true
end

local function returnToOwner(state: PetState): boolean
	local ownerRootPart = getCharacterRootPart(state.Owner)
	if not ownerRootPart then
		return false
	end

	local followAttachment = ownerRootPart:FindFirstChild(PET_FOLLOW_ATTACHMENT_NAME)
	if not followAttachment or not followAttachment:IsA("Attachment") then
		followAttachment = Instance.new("Attachment")
		followAttachment.Name = PET_FOLLOW_ATTACHMENT_NAME
		followAttachment.Position = state.FollowOffset
		followAttachment.Parent = ownerRootPart
	end

	return setPetTargetAttachment(state, followAttachment)
end

local function startAttackLoop(player: Player, state: PetState)
	attackLoopIds[player] = (attackLoopIds[player] or 0) + 1
	local loopId = attackLoopIds[player]

	task.spawn(function()
		while activePets[player] == state and attackLoopIds[player] == loopId do
			local enemy = findNearestEnemy(state)
			if enemy then
				if moveToEnemy(state, enemy) then
					attack(state, enemy)
					task.wait(ATTACK_COOLDOWN_SECONDS)
				end
			elseif not enemy then
				returnToOwner(state)
			end
                
			task.wait(ATTACK_LOOP_WAIT_SECONDS)
		end
	end)
end

local function destroyPet(player: Player)
	attackLoopIds[player] = (attackLoopIds[player] or 0) + 1

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
		FollowOffset = followOffset,
	}

	startAttackLoop(player, activePets[player])

	return model
end

function PetService.SelectPet(player: Player, petId: string): boolean
	if typeof(petId) ~= "string" or not PetDefinitions[petId] then
		return false
	end

	selectedPetIds[player] = petId
	return PetService.GivePet(player, petId) ~= nil
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
			PetService.GivePet(player, selectedPetIds[player] or DEFAULT_PET_ID)
		end)
	end)

	if player.Character then
		task.defer(function()
			PetService.GivePet(player, selectedPetIds[player] or DEFAULT_PET_ID)
		end)
	end
end

function PetService.Start()
	if started then
		return
	end

	started = true

	getSelectPetRemote().OnServerEvent:Connect(function(player, petId)
		PetService.SelectPet(player, petId)
	end)

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		destroyPet(player)
		selectedPetIds[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return PetService
