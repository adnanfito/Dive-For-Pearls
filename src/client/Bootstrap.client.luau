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
local PressureController = require(script.Parent.Controllers.PressureController)

PressureController.init()

print("ready")
