--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config

require(Shared.Types)
require(Config.Economy)
require(Config.Zones)
require(Config.Pearls)
require(Config.Shells)
require(Config.Pets)
require(Config.Eggs)
require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

Remotes.init()

print("ready")
