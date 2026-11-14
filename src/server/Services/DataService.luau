--!strict
-- Owns player saves and is the only module that touches DataStores (through ProfileStore, which
-- handles the session lock, autosave and BindToClose). Other services read and change data through
-- DataService.get; changes made without yielding in between are saved together.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local ProfileStore = require(ServerScriptService.Vendor.ProfileStore)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerData = Types.PlayerData
type Profile = ProfileStore.Profile<any>
type LoadedCallback = (player: Player, data: PlayerData) -> ()

-- Studio gets its own store so playtests never touch live saves.
local STORE_NAME = if RunService:IsStudio() then "PlayerData_Studio" else "PlayerData"
local KEY_PREFIX = "Player_"

local KICK_LOAD_FAILED = "We could not load your save. Please join again!"
local KICK_SAVE_BROKEN = "Something went wrong with your save. Please join again!"
local KICK_NEWER_SAVE = "The game just updated. Please join again!"
local KICK_SESSION_ENDED = "You joined from another server. See you there!"

-- No template: a brand-new profile starts as an empty table, which PlayerData.load turns into
-- default data. ProfileStore's Reconcile is never used, so only migrations change the shape.
local store = ProfileStore.New(STORE_NAME)
local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { LoadedCallback } = {}

local DataService = {}

local function kick(player: Player, message: string)
	if player.Parent == Players then
		player:Kick(message)
	end
end

local function reportLoad(player: Player, result: PlayerData.LoadResult)
	if not result.ok then
		warn(`DataService: rejected save for {player.Name} ({player.UserId}), {result.reason}: {result.detail}`)
		return
	end
	for _, fix in result.fixes do
		warn(`DataService: repaired save for {player.Name} ({player.UserId}): {fix}`)
	end
	for _, problem in result.warnings do
		warn(`DataService: save problem for {player.Name} ({player.UserId}): {problem}`)
	end
end

local function activate(player: Player, profile: Profile, data: PlayerData)
	profile.Data = data
	profile:AddUserId(player.UserId)
	-- Stamped on every save, so after a crash the offline time counts from the last save that landed.
	profile.OnSave:Connect(function()
		data.lastOnlineAt = os.time()
	end)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		kick(player, KICK_SESSION_ENDED)
	end)
	profiles[player] = profile
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function loadPlayer(player: Player)
	local profile = store:StartSessionAsync(
		`{KEY_PREFIX}{player.UserId}`,
		{
			Cancel = function()
				return player.Parent ~= Players
			end,
		} :: any
	)
	if profile == nil then
		-- The player left, the server is closing, or the save stayed locked or unreachable.
		kick(player, KICK_LOAD_FAILED)
		return
	end
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	local result = PlayerData.load(profile.Data, os.time())
	reportLoad(player, result)
	if not result.ok then
		-- load never changes profile.Data, so ending the session writes the save back unchanged.
		profile:EndSession()
		kick(player, if result.reason == "Newer" then KICK_NEWER_SAVE else KICK_SAVE_BROKEN)
		return
	end
	activate(player, profile, result.data)
end

local function releasePlayer(player: Player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
	end
end

-- nil until the save is loaded, and again once the session ends.
function DataService.get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile and profile:IsActive() then profile.Data else nil
end

-- Register before init so no player is missed.
function DataService.onLoaded(callback: LoadedCallback)
	table.insert(loadedCallbacks, callback)
end

function DataService.init()
	ProfileStore.OnError:Connect(function(message, storeName, profileKey)
		warn(`DataService: ProfileStore error in {storeName}/{profileKey}: {message}`)
	end)
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(releasePlayer)
	-- Players who joined before this script ran (common in Studio playtests).
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
end

return DataService
