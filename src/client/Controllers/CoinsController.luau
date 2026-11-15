--!strict
-- The Coins counter (StarterGui.CoinsGui, built in Studio). It only shows what the server sends
-- (CoinsUpdate, and the chamber's PressureUpdate) and steps aside while diving, where the shell
-- card takes the same corner.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gui = require("../Gui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local BIG_GAIN = 10 -- gains at least this size also bounce the counter

local CoinsController = {}

function CoinsController.init()
	local pill = Gui.waitFor(Gui.screen("CoinsGui"), "Coins") :: GuiObject
	local label = Gui.waitFor(pill, "Label") :: TextLabel
	local plusTemplate = Gui.waitFor(pill, "PlusTemplate") :: TextLabel
	local shown: number? = nil

	local function set(coins: number)
		local whole = math.floor(coins)
		local gain = if shown then whole - shown else 0
		if gain >= 1 then
			Gui.floatText(plusTemplate, `+{Gui.withCommas(gain)}`)
		end
		if gain >= BIG_GAIN then
			Gui.bounce(pill)
		end
		label.Text = Gui.withCommas(whole)
		shown = whole
	end

	Remotes.getEvent("CoinsUpdate").OnClientEvent:Connect(set)
	Remotes.getEvent("PressureUpdate").OnClientEvent:Connect(function(state: Types.PressureState)
		set(state.coins)
	end)
	Remotes.getEvent("DiveUpdate").OnClientEvent:Connect(function(state: Types.DiveState)
		pill.Visible = not state.diving
	end)
end

return CoinsController
