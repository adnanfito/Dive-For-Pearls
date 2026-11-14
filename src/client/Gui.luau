--!strict
-- Lookups for the ScreenGuis built in Studio (StarterGui), shared by the controllers.
local Players = game:GetService("Players")

local WAIT_SECONDS = 10

local Gui = {}

function Gui.waitFor(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, WAIT_SECONDS)
	assert(child, `Gui: {parent:GetFullName()}.{name} is missing`)
	return child
end

function Gui.screen(name: string): ScreenGui
	local playerGui = Gui.waitFor(Players.LocalPlayer, "PlayerGui")
	return Gui.waitFor(playerGui, name) :: ScreenGui
end

-- nil while the local character is dead or not spawned yet.
function Gui.localRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

return Gui
