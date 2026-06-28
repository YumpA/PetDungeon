local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

type PetService = {
	DamagePet: (player: Player, amount: number) -> boolean,
}

type NpcController = {
	Model: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	PatrolCenter: Vector3,
	NextPatrolAt: number,
	LastAttackAt: number,
	LoopId: number,
}

local HostileNpcService = {}

local ENEMIES_FOLDER_NAME = "Enemies"
local ENEMY_TAG = "Enemy"
local PATROL_AREA_PART_NAME = "PatrolArea"
local ENEMY_HP_ATTRIBUTE_NAME = "HP"
local DEFAULT_PATROL_RADIUS = 24
local DEFAULT_SPOT_RADIUS = 45
local DEFAULT_ATTACK_RANGE = 5
local DEFAULT_ATTACK_DAMAGE = 10
local DEFAULT_ATTACK_COOLDOWN_SECONDS = 1.5
local DEFAULT_PATROL_WAIT_SECONDS = 2
local DEFAULT_THINK_WAIT_SECONDS = 0.2
local DEFAULT_LEASH_RADIUS = 70

local random = Random.new()
local petService: PetService? = nil
local controllers: { [Model]: NpcController } = {}
local loopIds: { [Model]: number } = {}
local started = false

local function getNumberAttribute(instance: Instance, attributeName: string, fallback: number): number
	local value = instance:GetAttribute(attributeName)
	if typeof(value) == "number" then
		return value
	end

	return fallback
end

local function getVector3Attribute(instance: Instance, attributeName: string): Vector3?
	local value = instance:GetAttribute(attributeName)
	if typeof(value) == "Vector3" then
		return value
	end

	return nil
end

local function getRootPart(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		model.PrimaryPart = humanoidRootPart
		return humanoidRootPart
	end

	local firstPart = model:FindFirstChildWhichIsA("BasePart", true)
	if firstPart then
		model.PrimaryPart = firstPart
	end

	return firstPart
end

local function getPatrolAreaPart(model: Model): BasePart?
	local area = model:FindFirstChild(PATROL_AREA_PART_NAME)
	if area and area:IsA("BasePart") then
		return area
	end

	local parent = model.Parent
	if parent then
		local siblingArea = parent:FindFirstChild(`{model.Name}{PATROL_AREA_PART_NAME}`)
		if siblingArea and siblingArea:IsA("BasePart") then
			return siblingArea
		end
	end

	return nil
end

local function getPatrolCenter(model: Model, rootPart: BasePart): Vector3
	local configuredCenter = getVector3Attribute(model, "PatrolCenter")
	if configuredCenter then
		return configuredCenter
	end

	local patrolArea = getPatrolAreaPart(model)
	if patrolArea then
		return patrolArea.Position
	end

	return rootPart.Position
end

local function getRandomPatrolPoint(controller: NpcController): Vector3
	local patrolArea = getPatrolAreaPart(controller.Model)
	if patrolArea then
		local halfSize = patrolArea.Size * 0.5
		local localOffset = Vector3.new(
			random:NextNumber(-halfSize.X, halfSize.X),
			0,
			random:NextNumber(-halfSize.Z, halfSize.Z)
		)

		return (patrolArea.CFrame * CFrame.new(localOffset)).Position
	end

	local radius = getNumberAttribute(controller.Model, "PatrolRadius", DEFAULT_PATROL_RADIUS)
	local angle = random:NextNumber(0, math.pi * 2)
	local distance = random:NextNumber(0, radius)

	return controller.PatrolCenter + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function isNpcAlive(model: Model, humanoid: Humanoid): boolean
	if humanoid.Health <= 0 then
		return false
	end

	local hp = model:GetAttribute(ENEMY_HP_ATTRIBUTE_NAME)
	return typeof(hp) ~= "number" or hp > 0
end

local function getPlayerRootAndHumanoid(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return nil, nil
	end

	return rootPart, humanoid
end

local function canSeeCharacter(controller: NpcController, character: Model, targetRootPart: BasePart): boolean
	local origin = controller.RootPart.Position
	local direction = targetRootPart.Position - origin
	if direction.Magnitude <= 0 then
		return true
	end

	local filterInstances: { Instance } = { controller.Model }
	local activePetsFolder = Workspace:FindFirstChild("ActivePets")
	if activePetsFolder then
		table.insert(filterInstances, activePetsFolder)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filterInstances
	params.IgnoreWater = true

	local result = Workspace:Raycast(origin, direction, params)
	return not result or result.Instance:IsDescendantOf(character)
end

local function findTargetPlayer(controller: NpcController): Player?
	local spotRadius = getNumberAttribute(controller.Model, "SpotRadius", DEFAULT_SPOT_RADIUS)
	local leashRadius = getNumberAttribute(controller.Model, "LeashRadius", DEFAULT_LEASH_RADIUS)
	local nearestPlayer = nil
	local nearestDistance = spotRadius

	for _, player in Players:GetPlayers() do
		local rootPart = getPlayerRootAndHumanoid(player)
		if rootPart then
			local distanceFromNpc = (rootPart.Position - controller.RootPart.Position).Magnitude
			local distanceFromPatrol = (rootPart.Position - controller.PatrolCenter).Magnitude
			if distanceFromNpc <= nearestDistance and distanceFromPatrol <= leashRadius then
				local character = player.Character
				if character and canSeeCharacter(controller, character, rootPart) then
					nearestDistance = distanceFromNpc
					nearestPlayer = player
				end
			end
		end
	end

	return nearestPlayer
end

local function attackPlayer(controller: NpcController, player: Player)
	local now = os.clock()
	local cooldown = getNumberAttribute(controller.Model, "AttackCooldown", DEFAULT_ATTACK_COOLDOWN_SECONDS)
	if now - controller.LastAttackAt < cooldown then
		return
	end

	local rootPart, humanoid = getPlayerRootAndHumanoid(player)
	if not rootPart or not humanoid then
		return
	end

	local attackRange = getNumberAttribute(controller.Model, "AttackRange", DEFAULT_ATTACK_RANGE)
	if (rootPart.Position - controller.RootPart.Position).Magnitude > attackRange then
		return
	end

	controller.LastAttackAt = now

	local playerDamage = getNumberAttribute(controller.Model, "AttackDamage", DEFAULT_ATTACK_DAMAGE)
	local petDamage = getNumberAttribute(controller.Model, "PetAttackDamage", playerDamage)

	humanoid:TakeDamage(playerDamage)
	if petService and petDamage > 0 then
		petService.DamagePet(player, petDamage)
	end
end

local function patrol(controller: NpcController)
	local now = os.clock()
	if now < controller.NextPatrolAt then
		return
	end

	controller.Humanoid:MoveTo(getRandomPatrolPoint(controller))
	controller.NextPatrolAt = now + getNumberAttribute(controller.Model, "PatrolWait", DEFAULT_PATROL_WAIT_SECONDS)
end

local function runNpcLoop(controller: NpcController)
	task.spawn(function()
		while controllers[controller.Model] == controller and controller.LoopId == loopIds[controller.Model] do
			if not controller.Model.Parent or not isNpcAlive(controller.Model, controller.Humanoid) then
				controllers[controller.Model] = nil
				return
			end

			local targetPlayer = findTargetPlayer(controller)
			if targetPlayer then
				local targetRootPart = getPlayerRootAndHumanoid(targetPlayer)
				if targetRootPart then
					controller.Humanoid:MoveTo(targetRootPart.Position)
					attackPlayer(controller, targetPlayer)
				end
			else
				patrol(controller)
			end

			task.wait(DEFAULT_THINK_WAIT_SECONDS)
		end
	end)
end

function HostileNpcService.BindNpc(model: Model)
	if controllers[model] then
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootPart = getRootPart(model)
	if not humanoid or not rootPart then
		return
	end

	pcall(function()
		rootPart:SetNetworkOwner(nil)
	end)

	loopIds[model] = (loopIds[model] or 0) + 1
	local controller = {
		Model = model,
		Humanoid = humanoid,
		RootPart = rootPart,
		PatrolCenter = getPatrolCenter(model, rootPart),
		NextPatrolAt = 0,
		LastAttackAt = 0,
		LoopId = loopIds[model],
	}

	controllers[model] = controller
	runNpcLoop(controller)
end

local function bindEnemyDescendant(instance: Instance)
	if instance:IsA("Model") then
		HostileNpcService.BindNpc(instance)
	end
end

function HostileNpcService.Start(service: PetService)
	if started then
		return
	end

	started = true
	petService = service

	local enemiesFolder = Workspace:FindFirstChild(ENEMIES_FOLDER_NAME)
	if enemiesFolder then
		for _, descendant in enemiesFolder:GetDescendants() do
			bindEnemyDescendant(descendant)
		end

		enemiesFolder.DescendantAdded:Connect(bindEnemyDescendant)
	end

	for _, instance in CollectionService:GetTagged(ENEMY_TAG) do
		local model = if instance:IsA("Model") then instance else instance:FindFirstAncestorOfClass("Model")
		if model then
			HostileNpcService.BindNpc(model)
		end
	end

	CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(function(instance)
		local model = if instance:IsA("Model") then instance else instance:FindFirstAncestorOfClass("Model")
		if model then
			HostileNpcService.BindNpc(model)
		end
	end)
end

return HostileNpcService
