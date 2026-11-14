--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

require(Shared:WaitForChild("Types"))
require(Config:WaitForChild("Economy"))
require(Config:WaitForChild("Zones"))
require(Config:WaitForChild("Pearls"))
require(Config:WaitForChild("Shells"))
require(Config:WaitForChild("Pets"))
require(Config:WaitForChild("Eggs"))
require(Shared:WaitForChild("Formulas"))
require(Shared:WaitForChild("Remotes"))
local Controllers = script.Parent.Controllers
local DiveController = require(Controllers.DiveController)
local LiftController = require(Controllers.LiftController)
local PressureController = require(Controllers.PressureController)
local ShellController = require(Controllers.ShellController)

PressureController.init()
LiftController.init()
DiveController.init()
ShellController.init()

print("ready")
