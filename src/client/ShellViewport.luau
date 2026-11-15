--!strict
-- Shows a clam or a pearl inside a ViewportFrame: still clams on aquarium cards, and the opening
-- moment where the lid swings up and the pearl rises out. Visual only: the server already picked
-- the pearl. Clam models (ReplicatedStorage.Assets.Shells.<tier>) have a Lid model pivoting on its
-- Hinge, built in Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PearlLooks = require(Shared:WaitForChild("PearlLooks"))
local Types = require(Shared:WaitForChild("Types"))

local CAMERA_FOV = 30
local CAMERA_HEIGHT = 0.55 -- of the clam width, above it
local CAMERA_AIM_HEIGHT = 0.1 -- of the clam width, so a risen pearl stays in view
local CAMERA_DISTANCE = 1.5 -- clam widths in front of it
local LID_OPEN_DEGREES = -60
local OPEN_INFO = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local RISE_INFO = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RISE_DELAY_SECONDS = 0.35
local PEARL_SIZE = 0.32 -- of the clam width
local PEARL_RISE = 0.28 -- of the clam width, how high the pearl floats above the clam

local ShellViewport = {}

local function templateFor(tier: Types.ShellTierId): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local shells = if assets then assets:FindFirstChild("Shells") else nil
	local template = if shells then shells:FindFirstChild(tier) else nil
	return if template and template:IsA("Model") then template else nil
end

local function reset(viewport: ViewportFrame): Camera
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = CAMERA_FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return camera
end

-- Faces the clam's front (+Z in the model) toward the camera, which looks down at it a little.
local function placeClam(viewport: ViewportFrame, tier: Types.ShellTierId, width: number): Model?
	local camera = reset(viewport)
	local template = templateFor(tier)
	if not template then
		return nil
	end
	local clam = template:Clone()
	clam:PivotTo(CFrame.Angles(0, math.pi, 0))
	clam.Parent = viewport
	local eye = Vector3.new(0, width * CAMERA_HEIGHT, -width * CAMERA_DISTANCE)
	camera.CFrame = CFrame.lookAt(eye, Vector3.new(0, width * CAMERA_AIM_HEIGHT, 0))
	return clam
end

function ShellViewport.showShell(viewport: ViewportFrame, tier: Types.ShellTierId)
	local template = templateFor(tier)
	placeClam(viewport, tier, if template then template:GetExtentsSize().X else 1)
end

local function makePearl(rarity: Types.PearlRarityId, size: number, at: Vector3): Part
	local look = PearlLooks.of(rarity)
	local pearl = Instance.new("Part")
	pearl.Shape = Enum.PartType.Ball
	pearl.Size = Vector3.one * size
	pearl.Color = look.color
	pearl.Material = Enum.Material.SmoothPlastic
	pearl.Reflectance = 0.2
	pearl.CFrame = CFrame.new(at)
	return pearl
end

-- A pearl alone, for looking at one already owned.
function ShellViewport.showPearl(viewport: ViewportFrame, rarity: Types.PearlRarityId)
	local camera = reset(viewport)
	makePearl(rarity, 1, Vector3.zero).Parent = viewport
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, -3.4), Vector3.zero)
end

local function swingLid(lid: Model)
	local closed = lid:GetPivot()
	local progress = Instance.new("NumberValue")
	progress.Changed:Connect(function(value)
		lid:PivotTo(closed * CFrame.Angles(math.rad(LID_OPEN_DEGREES * value), 0, 0))
	end)
	local tween = TweenService:Create(progress, OPEN_INFO, { Value = 1 })
	tween.Completed:Once(function()
		progress:Destroy()
	end)
	tween:Play()
end

-- The lid opens, then the pearl rises out of the clam.
function ShellViewport.openWithPearl(viewport: ViewportFrame, tier: Types.ShellTierId, rarity: Types.PearlRarityId)
	local template = templateFor(tier)
	local width = if template then template:GetExtentsSize().X else 1
	local clam = placeClam(viewport, tier, width)
	local inside = Vector3.zero
	local pearl = makePearl(rarity, width * PEARL_SIZE, inside)
	pearl.Parent = viewport
	local lid = if clam then clam:FindFirstChild("Lid") else nil
	if lid and lid:IsA("Model") then
		swingLid(lid)
	end
	task.delay(RISE_DELAY_SECONDS, function()
		if pearl.Parent then
			local risen = CFrame.new(inside + Vector3.new(0, width * PEARL_RISE, 0))
			TweenService:Create(pearl, RISE_INFO, { CFrame = risen }):Play()
		end
	end)
end

return ShellViewport
