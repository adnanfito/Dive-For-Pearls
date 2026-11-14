--!strict
-- Studio-only test tools. In live servers init returns before creating anything, and the hook is a
-- BindableEvent in ServerStorage, which clients can neither see nor fire.
-- Give every player test Coins from the Command Bar (Server view): game.ServerStorage.DevGiveCoins:Fire()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(ServerScriptService.Server.Services.DataService)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local GIVE_COINS_NAME = "DevGiveCoins"

local DevService = {}

local function giveTestCoins()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			data.coins += Economy.DEV_TEST_COINS
			print(`DevService: gave {player.Name} {Economy.DEV_TEST_COINS} test Coins, now {data.coins}`)
		else
			warn(`DevService: {player.Name} has no loaded data, no Coins given`)
		end
	end
end

function DevService.init()
	if not RunService:IsStudio() then
		return
	end
	local giveCoins = Instance.new("BindableEvent")
	giveCoins.Name = GIVE_COINS_NAME
	giveCoins.Event:Connect(giveTestCoins)
	giveCoins.Parent = ServerStorage
end

return DevService
