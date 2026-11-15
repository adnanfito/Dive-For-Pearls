--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config

require(Shared.Types)
require(Config.Economy)
require(Config.Zones)
require(Config.Pearls)
require(Config.Shells)
require(Config.Pets)
require(Config.Eggs)
require(Config.Onboarding)
require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local Services = ServerScriptService.Server.Services
local AquariumService = require(Services.AquariumService)
local DataService = require(Services.DataService)
local DevService = require(Services.DevService)
local DiveService = require(Services.DiveService)
local PressureService = require(Services.PressureService)
local ShellService = require(Services.ShellService)

Remotes.init()
-- Services that listen for loaded data start before DataService loads anyone.
PressureService.init()
ShellService.init()
DiveService.init()
AquariumService.init()
DataService.init()
DevService.init()

print("ready")
