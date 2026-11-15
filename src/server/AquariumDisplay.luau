--!strict
-- Draws what is in a player's tank for everyone on the server: ripening shells (ripe ones glow) and
-- displayed pearls in a grid on the tank floor, plus the owner's name on the sign. Visual only.
-- Tank models are built in Studio: Workspace.Aquariums.<Plot>.{Floor, Contents, Sign.SignGui.OwnerLabel}.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PearlLooks = require(ReplicatedStorage.Shared.PearlLooks)
local Types = require(ReplicatedStorage.Shared.Types)

local COLUMNS = 10
local ROWS = 4 -- COLUMNS * ROWS covers the largest aquarium (Economy.AQUARIUM_MAX_SLOTS)
local SHELL_WIDTH = 1.5
local PEARL_SIZE = 1.1
local STAND_SIZE = Vector3.new(0.4, 1.3, 1.3)
local STAND_COLOR = Color3.fromRGB(255, 238, 244)
local RIPE_GLOW = Color3.fromRGB(255, 240, 170)
local RIPE_LIGHT_RANGE = 6
local PEARL_LIGHT_RANGE = 5
local SPARKLE_RATE = 3
local FREE_TEXT = "Free tank"

local AquariumDisplay = {}

local function shellTemplates(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return if assets then assets:FindFirstChild("Shells") else nil
end

-- Front row first (the tank's -Z side faces the island centre), left to right.
local function cellCFrame(floor: BasePart, index: number): CFrame
	local column = (index - 1) % COLUMNS
	local row = (index - 1) // COLUMNS
	local cellX = floor.Size.X / COLUMNS
	local cellZ = floor.Size.Z / ROWS
	local x = -floor.Size.X / 2 + cellX * (column + 0.5)
	local z = -floor.Size.Z / 2 + cellZ * (row + 0.5)
	return floor.CFrame * CFrame.new(x, floor.Size.Y / 2, z)
end

local function settle(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

local function addSparkles(parent: BasePart, color: Color3 | ColorSequence)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = if typeof(color) == "Color3" then ColorSequence.new(color) else color
	sparkles.LightEmission = 1
	sparkles.Rate = SPARKLE_RATE
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(0.3, 0.8)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Parent = parent
end

local function addLight(parent: BasePart, color: Color3, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Parent = parent
end

local function makeShell(tier: Types.ShellTierId, ripe: boolean, at: CFrame): Model?
	local templates = shellTemplates()
	local template = if templates then templates:FindFirstChild(tier) else nil
	if not template or not template:IsA("Model") then
		warn(`AquariumDisplay: ReplicatedStorage.Assets.Shells.{tier} is missing`)
		return nil
	end
	local model = template:Clone()
	model:ScaleTo(model:GetScale() * SHELL_WIDTH / model:GetExtentsSize().X)
	settle(model)
	model:PivotTo(at * CFrame.new(0, model:GetExtentsSize().Y / 2, 0))
	local root = model.PrimaryPart
	if ripe and root then
		addLight(root, RIPE_GLOW, RIPE_LIGHT_RANGE)
		addSparkles(root, RIPE_GLOW)
	end
	return model
end

local function makePearl(rarity: Types.PearlRarityId, at: CFrame): Model
	local look = PearlLooks.of(rarity)
	local model = Instance.new("Model")
	local stand = Instance.new("Part")
	stand.Shape = Enum.PartType.Cylinder
	stand.Size = STAND_SIZE
	stand.Color = STAND_COLOR
	stand.CFrame = at * CFrame.new(0, STAND_SIZE.X / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	stand.Parent = model
	local pearl = Instance.new("Part")
	pearl.Shape = Enum.PartType.Ball
	pearl.Size = Vector3.one * PEARL_SIZE
	pearl.Color = look.color
	pearl.Material = Enum.Material.SmoothPlastic
	pearl.Reflectance = 0.15
	pearl.CFrame = at * CFrame.new(0, STAND_SIZE.X + PEARL_SIZE / 2, 0)
	pearl.Parent = model
	settle(model)
	addLight(pearl, look.glow, PEARL_LIGHT_RANGE)
	if look.rainbow then
		addSparkles(pearl, PearlLooks.RAINBOW)
	end
	return model
end

function AquariumDisplay.render(plot: Model, data: Types.PlayerData, now: number)
	local floor = plot:FindFirstChild("Floor")
	local contents = plot:FindFirstChild("Contents")
	if not floor or not floor:IsA("BasePart") or not contents then
		warn(`AquariumDisplay: {plot:GetFullName()} needs a Floor part and a Contents folder`)
		return
	end
	contents:ClearAllChildren()
	local index = 0
	for _, shell in data.aquarium.shells do
		index += 1
		local model = makeShell(shell.tier, shell.readyAt <= now, cellCFrame(floor, index))
		if model then
			model.Parent = contents
		end
	end
	for _, id in data.aquarium.displayedPearls do
		local pearl = data.pearls[id]
		if pearl then
			index += 1
			makePearl(pearl.rarity, cellCFrame(floor, index)).Parent = contents
		end
	end
end

function AquariumDisplay.clear(plot: Model)
	local contents = plot:FindFirstChild("Contents")
	if contents then
		contents:ClearAllChildren()
	end
end

-- nil frees the tank's sign.
function AquariumDisplay.setOwner(plot: Model, ownerName: string?)
	local sign = plot:FindFirstChild("Sign")
	local gui = if sign then sign:FindFirstChild("SignGui") else nil
	local label = if gui then gui:FindFirstChild("OwnerLabel") else nil
	if label and label:IsA("TextLabel") then
		label.Text = if ownerName then `{ownerName}'s tank` else FREE_TEXT
	end
end

return AquariumDisplay
