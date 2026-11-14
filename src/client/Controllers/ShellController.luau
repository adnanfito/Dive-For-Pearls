--!strict
-- Draws the shells the server spawned for this diver (only this player sees them) and asks the
-- server to collect one when the diver swims close. The server checks distance and ownership.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Gui = require("../Gui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local FOLDER_NAME = "MyShells"
local SHELL_SIZE = 2
local BIG_SHELL_SIZE = 3.5
local ICON_SIZE = UDim2.fromScale(3, 3)
local ICON_OFFSET = Vector3.new(0, 2.5, 0)
-- Placeholder look per tier; an unknown tier falls back to Common's look.
local TIER_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(240, 230, 210),
	Glowing = Color3.fromRGB(120, 230, 255),
	Rare = Color3.fromRGB(200, 120, 255),
	Giant = Color3.fromRGB(255, 200, 60),
}
local BIG_TIERS: { [string]: boolean } = { Giant = true }

type Drawn = { shell: Types.DiveShell, part: BasePart }

local ShellController = {}

local function makePart(shell: Types.DiveShell, folder: Folder): BasePart
	local size = if BIG_TIERS[shell.tier] then BIG_SHELL_SIZE else SHELL_SIZE
	local part = Instance.new("Part")
	part.Name = `Shell{shell.id}`
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * size
	part.Position = shell.position
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Color = TIER_COLORS[shell.tier] or TIER_COLORS.Common
	part.Material = if shell.tier == "Common" then Enum.Material.SmoothPlastic else Enum.Material.Neon

	local icon = Instance.new("BillboardGui")
	icon.Size = ICON_SIZE
	icon.StudsOffset = ICON_OFFSET
	icon.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = "🐚"
	label.Parent = icon
	icon.Parent = part

	part.Parent = folder
	return part
end

local function nearestInReach(drawn: { [number]: Drawn }, position: Vector3): Drawn?
	local best: Drawn? = nil
	local bestDistance = Economy.SHELL_TOUCH_RADIUS_STUDS
	for _, entry in drawn do
		local distance = (entry.shell.position - position).Magnitude
		if distance <= bestDistance then
			best, bestDistance = entry, distance
		end
	end
	return best
end

function ShellController.init()
	local collectShell = Remotes.getFunction("CollectShell")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	local drawn: { [number]: Drawn } = {}
	local bagFull = false
	local pending = false
	local retryAt = 0

	Remotes.getEvent("DiveShells").OnClientEvent:Connect(function(shells: { Types.DiveShell })
		folder:ClearAllChildren()
		table.clear(drawn)
		for _, shell in shells do
			drawn[shell.id] = { shell = shell, part = makePart(shell, folder) }
		end
	end)
	Remotes.getEvent("DiveUpdate").OnClientEvent:Connect(function(state: Types.DiveState)
		bagFull = state.carried + state.bagCount >= Economy.SHELL_BAG_MAX
	end)

	local function collect(entry: Drawn)
		pending = true
		local result: Types.CollectResult = collectShell:InvokeServer(entry.shell.id)
		pending = false
		if not result.ok then
			-- Lag can make the server see the diver a little behind; try again shortly.
			retryAt = os.clock() + Economy.SHELL_COLLECT_COOLDOWN_SECONDS
		end
		-- Skip the removal if a new dive replaced this shell while the request was in flight.
		if (result.ok or result.reason == "Gone") and drawn[entry.shell.id] == entry then
			drawn[entry.shell.id] = nil
			entry.part:Destroy()
		end
	end

	RunService.Heartbeat:Connect(function()
		local root = Gui.localRoot()
		if pending or bagFull or not root or os.clock() < retryAt then
			return
		end
		local entry = nearestInReach(drawn, root.Position)
		if entry then
			task.spawn(collect, entry)
		end
	end)
end

return ShellController
