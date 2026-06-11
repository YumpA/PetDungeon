local Players = game:GetService("Players")

local CurrencyService = {}

local STARTING_COINS = 250
local CURRENCY_NAME = "Coins"

local balances: { [Player]: number } = {}
local started = false

local function createLeaderstats(player: Player)
	local existingLeaderstats = player:FindFirstChild("leaderstats")
	if existingLeaderstats then
		return existingLeaderstats
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	return leaderstats
end

local function createCurrencyValue(leaderstats: Instance)
	local existingCurrency = leaderstats:FindFirstChild(CURRENCY_NAME)
	if existingCurrency and existingCurrency:IsA("IntValue") then
		return existingCurrency
	end

	local coins = Instance.new("IntValue")
	coins.Name = CURRENCY_NAME
	coins.Parent = leaderstats
	return coins
end

local function syncLeaderstat(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local currency = leaderstats:FindFirstChild(CURRENCY_NAME)
	if currency and currency:IsA("IntValue") then
		currency.Value = balances[player] or 0
	end
end

function CurrencyService.Start()
	if started then
		return
	end

	started = true

	Players.PlayerAdded:Connect(function(player)
		balances[player] = STARTING_COINS

		local leaderstats = createLeaderstats(player)
		local coins = createCurrencyValue(leaderstats)
		coins.Value = balances[player]
	end)

	Players.PlayerRemoving:Connect(function(player)
		balances[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		if balances[player] == nil then
			balances[player] = STARTING_COINS
			local leaderstats = createLeaderstats(player)
			local coins = createCurrencyValue(leaderstats)
			coins.Value = balances[player]
		end
	end
end

function CurrencyService.GetBalance(player: Player): number
	return balances[player] or 0
end

function CurrencyService.CanAfford(player: Player, amount: number): boolean
	return amount >= 0 and CurrencyService.GetBalance(player) >= amount
end

function CurrencyService.Add(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	balances[player] = CurrencyService.GetBalance(player) + amount
	syncLeaderstat(player)
end

function CurrencyService.Spend(player: Player, amount: number): boolean
	if amount < 0 or not CurrencyService.CanAfford(player, amount) then
		return false
	end

	balances[player] = CurrencyService.GetBalance(player) - amount
	syncLeaderstat(player)
	return true
end

return CurrencyService
