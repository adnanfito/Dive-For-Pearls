--!strict
-- Draws the shells the server spawned for this diver (only this player sees them) and asks the
-- server to collect one when the diver swims close. The server checks distance and ownership.
-- Shell looks come from ReplicatedStorage.Assets.Shells.<tier> (models built in Studio).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioController = require("./AudioController")
local Gui = require("../Gui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local FOLDER_NAME = "MyShells"
local ASSET_WAIT_SECONDS = 10
local FALLBACK_SIZE = 2
local BOB_HEIGHT = 0.35
local BOB_SPEED = 2
local SPIN_SPEED = 0.8
local POP_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local POP_SCALE = 0.05
local BURST_COUNT = 14
-- Tiers that also get the sparkly chime when collected.
local SPECIAL_TIERS: { [string]: boolean } = { Glowing = true, Rare = true, Giant = true }
-- Light and sparkle per tier; Common gets a soft light only so it is still easy to spot.
type Glow = { color: Color3, brightness: number, range: number, sparkles: number }
local GLOWS: { [string]: Glow } = {
	Common = { color = Color3.fromRGB(255, 245, 230), brightness = 0.8, range = 6, sparkles = 0 },
	Glowing = { color = Color3.fromRGB(110, 230, 255), brightness = 2, range = 10, sparkles = 3 },
	Rare = { color = Color3.fromRGB(190, 120, 255), brightness = 2.5, range = 12, sparkles = 5 },
	Giant = { color = Color3.fromRGB(255, 205, 60), brightness = 3, range = 16, sparkles = 9 },
}

type Drawn = { shell: Types.DiveShell, model: Model, phase: number }

local ShellController = {}

local function fallbackModel(): Model
	local model = Instance.new("Model")
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * FALLBACK_SIZE
	part.Anchored = true
	part.CanCollide = false
	part.Parent = model
	model.PrimaryPart = part
	return model
end

local function addGlow(model: Model, glow: Glow)
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = glow.color
	light.Brightness = glow.brightness
	light.Range = glow.range
	light.Parent = anchor
	if glow.sparkles > 0 then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(glow.color)
		sparkles.LightEmission = 1
		sparkles.Rate = glow.sparkles
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Parent = anchor
	end
end

local function makeShell(shell: Types.DiveShell, templates: Instance?, folder: Folder): Model
	local template = if templates then templates:FindFirstChild(shell.tier) else nil
	local model = if template and template:IsA("Model") then template:Clone() else fallbackModel()
	model.Name = `Shell{shell.id}`
	model:PivotTo(CFrame.new(shell.position))
	addGlow(model, GLOWS[shell.tier] or GLOWS.Common)
	model.Parent = folder
	return model
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

local function animate(drawn: { [number]: Drawn }, now: number)
	for _, entry in drawn do
		local t = now + entry.phase
		local bob = CFrame.new(0, math.sin(t * BOB_SPEED) * BOB_HEIGHT, 0)
		entry.model:PivotTo(CFrame.new(entry.shell.position) * bob * CFrame.Angles(0, t * SPIN_SPEED, 0))
	end
end

-- Shrinks the shell away with a sparkle burst instead of making it vanish in one frame.
local function pop(model: Model)
	local sparkles = model:FindFirstChildWhichIsA("ParticleEmitter", true)
	if sparkles then
		sparkles:Emit(BURST_COUNT)
	end
	local value = Instance.new("NumberValue")
	value.Value = model:GetScale()
	value.Changed:Connect(function(scale)
		model:ScaleTo(math.max(scale, POP_SCALE))
	end)
	local tween = TweenService:Create(value, POP_INFO, { Value = POP_SCALE })
	tween.Completed:Once(function()
		value:Destroy()
		model:Destroy()
	end)
	tween:Play()
end

function ShellController.init()
	local collectShell = Remotes.getFunction("CollectShell")
	local assets = ReplicatedStorage:WaitForChild("Assets", ASSET_WAIT_SECONDS)
	local templates = if assets then assets:WaitForChild("Shells", ASSET_WAIT_SECONDS) else nil
	if not templates then
		warn("ShellController: ReplicatedStorage.Assets.Shells is missing; shells use plain balls")
	end
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
			drawn[shell.id] = { shell = shell, model = makeShell(shell, templates, folder), phase = shell.id }
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
			pop(entry.model)
		end
		if result.ok then
			AudioController.play(if SPECIAL_TIERS[entry.shell.tier] then "CollectRare" else "Collect")
		end
	end

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		animate(drawn, now)
		local root = Gui.localRoot()
		if pending or bagFull or not root or now < retryAt then
			return
		end
		local entry = nearestInReach(drawn, root.Position)
		if entry then
			task.spawn(collect, entry)
		end
	end)
end

return ShellController
