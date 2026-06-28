local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyService = {}

local REMOTES_FOLDER_NAME = "Remotes"
local PARTY_REMOTES_FOLDER_NAME = "Parties"
local CREATE_PARTY_REMOTE_NAME = "CreateParty"
local JOIN_PARTY_REMOTE_NAME = "JoinParty"
local LEAVE_PARTY_REMOTE_NAME = "LeaveParty"
local PARTY_STATE_CHANGED_REMOTE_NAME = "PartyStateChanged"
local GET_PARTY_STATE_FUNCTION_NAME = "GetPartyState"
local MAX_PARTY_SIZE = 4

type Party = {
	Leader: Player,
	Members: { Player },
}

local partiesByLeader: { [Player]: Party } = {}
local partyByPlayer: { [Player]: Party } = {}
local started = false

local function getPartyRemotesFolder(): Folder
	local remotesFolder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = REMOTES_FOLDER_NAME
		remotesFolder.Parent = ReplicatedStorage
	end

	local partyRemotesFolder = remotesFolder:FindFirstChild(PARTY_REMOTES_FOLDER_NAME)
	if partyRemotesFolder and partyRemotesFolder:IsA("Folder") then
		return partyRemotesFolder
	end

	local newPartyRemotesFolder = Instance.new("Folder")
	newPartyRemotesFolder.Name = PARTY_REMOTES_FOLDER_NAME
	newPartyRemotesFolder.Parent = remotesFolder
	return newPartyRemotesFolder
end

local function getRemoteEvent(remoteName: string): RemoteEvent
	local partyRemotesFolder = getPartyRemotesFolder()
	local existingRemote = partyRemotesFolder:FindFirstChild(remoteName)
	if existingRemote and existingRemote:IsA("RemoteEvent") then
		return existingRemote
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = remoteName
	remote.Parent = partyRemotesFolder
	return remote
end

local function getRemoteFunction(remoteName: string): RemoteFunction
	local partyRemotesFolder = getPartyRemotesFolder()
	local existingRemote = partyRemotesFolder:FindFirstChild(remoteName)
	if existingRemote and existingRemote:IsA("RemoteFunction") then
		return existingRemote
	end

	local remote = Instance.new("RemoteFunction")
	remote.Name = remoteName
	remote.Parent = partyRemotesFolder
	return remote
end

local function getStateChangedRemote(): RemoteEvent
	return getRemoteEvent(PARTY_STATE_CHANGED_REMOTE_NAME)
end

local function getPlayerSummary(player: Player)
	return {
		UserId = player.UserId,
		Name = player.Name,
		DisplayName = player.DisplayName,
	}
end

local function buildSnapshot()
	local parties = {}

	for leader, party in partiesByLeader do
		local members = {}
		for _, member in party.Members do
			table.insert(members, getPlayerSummary(member))
		end

		table.insert(parties, {
			LeaderUserId = leader.UserId,
			LeaderName = leader.Name,
			LeaderDisplayName = leader.DisplayName,
			Members = members,
			MemberCount = #members,
			MaxMembers = MAX_PARTY_SIZE,
		})
	end

	table.sort(parties, function(left, right)
		return left.LeaderName < right.LeaderName
	end)

	return parties
end

local function broadcastPartyState()
	getStateChangedRemote():FireAllClients(buildSnapshot())
end

local function removeMemberFromParty(player: Player, party: Party)
	for index, member in party.Members do
		if member == player then
			table.remove(party.Members, index)
			break
		end
	end

	partyByPlayer[player] = nil
end

function PartyService.CreateParty(player: Player): boolean
	if partyByPlayer[player] then
		return false
	end

	local party = {
		Leader = player,
		Members = { player },
	}

	partiesByLeader[player] = party
	partyByPlayer[player] = party
	broadcastPartyState()
	return true
end

function PartyService.JoinParty(player: Player, leaderUserId: number): boolean
	if partyByPlayer[player] or typeof(leaderUserId) ~= "number" then
		return false
	end

	local leader = Players:GetPlayerByUserId(leaderUserId)
	if not leader then
		return false
	end

	local party = partiesByLeader[leader]
	if not party or #party.Members >= MAX_PARTY_SIZE then
		return false
	end

	table.insert(party.Members, player)
	partyByPlayer[player] = party
	broadcastPartyState()
	return true
end

function PartyService.LeaveParty(player: Player): boolean
	local party = partyByPlayer[player]
	if not party then
		return false
	end

	if party.Leader == player then
		for _, member in party.Members do
			partyByPlayer[member] = nil
		end

		partiesByLeader[player] = nil
	else
		removeMemberFromParty(player, party)
	end

	broadcastPartyState()
	return true
end

function PartyService.GetTeleportPlayers(requestingPlayer: Player): ({ Player }?, string?)
	local party = partyByPlayer[requestingPlayer]
	if not party then
		return { requestingPlayer }, nil
	end

	if party.Leader ~= requestingPlayer then
		return nil, "Only the group leader can start a dungeon."
	end

	local players = {}
	for _, member in party.Members do
		if member.Parent == Players then
			table.insert(players, member)
		end
	end

	if #players == 0 then
		return nil, "No valid players in group."
	end

	return players, nil
end

function PartyService.Start()
	if started then
		return
	end

	started = true

	getRemoteEvent(CREATE_PARTY_REMOTE_NAME).OnServerEvent:Connect(function(player)
		PartyService.CreateParty(player)
	end)

	getRemoteEvent(JOIN_PARTY_REMOTE_NAME).OnServerEvent:Connect(function(player, leaderUserId)
		PartyService.JoinParty(player, leaderUserId)
	end)

	getRemoteEvent(LEAVE_PARTY_REMOTE_NAME).OnServerEvent:Connect(function(player)
		PartyService.LeaveParty(player)
	end)

	getRemoteFunction(GET_PARTY_STATE_FUNCTION_NAME).OnServerInvoke = function()
		return buildSnapshot()
	end

	Players.PlayerRemoving:Connect(function(player)
		PartyService.LeaveParty(player)
	end)

	task.defer(broadcastPartyState)
end

return PartyService
