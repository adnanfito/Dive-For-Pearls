--!strict
-- While the server says the player is inside the Pressure Chamber, the character floats and swims
-- in the water column with bubbles, so AFK time looks alive. Visual only: depth gain stays on the
-- server, and the diver can still walk out through the door.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require("../Effects")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local CHAMBER_NAME = "PressureChamber"
local ZONE_NAME = "Zone"
local WAIT_SECONDS = 10
local BOB_HEIGHT = 0.8
-- High enough above the tank floor that the Humanoid stops snapping its feet to the floor.
local FLOAT_ABOVE_ZONE_CENTER = 2.5
local BOB_SPEED = 1.6
local FLOAT_RESPONSIVENESS = 6
local FLOAT_FORCE_FACTOR = 4 -- times the character's weight, so it can hold the height
local EFFECT_NAME = "ChamberFloat"
local BUBBLE_RATE = 6

type Float = {
	character: Model,
	instances: { Instance },
	align: AlignPosition,
	track: AnimationTrack?,
}

local PressureFloatController = {}

-- The default Animate script carries a swim animation; R6 rigs have none and just float.
local function playSwim(character: Model, humanoid: Humanoid): AnimationTrack?
	local animate = character:FindFirstChild("Animate")
	local swim = if animate then animate:FindFirstChild("swim") else nil
	local animation = if swim then swim:FindFirstChildOfClass("Animation") else nil
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animation or not animator then
		return nil
	end
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play()
	return track
end

local function startFloat(zone: BasePart): Float?
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not character or not humanoid or not root or not root:IsA("BasePart") then
		return nil
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = EFFECT_NAME
	attachment.Parent = root
	-- Holds only the height, so walking still moves the diver sideways and out of the door.
	local align = Instance.new("AlignPosition")
	align.Name = EFFECT_NAME
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	align.MaxAxesForce = Vector3.new(0, root.AssemblyMass * Workspace.Gravity * FLOAT_FORCE_FACTOR, 0)
	align.Responsiveness = FLOAT_RESPONSIVENESS
	align.Position = Vector3.new(root.Position.X, zone.Position.Y + FLOAT_ABOVE_ZONE_CENTER, root.Position.Z)
	align.Parent = root
	-- A small hop breaks the floor contact so the float can take over.
	humanoid.Jump = true
	local head = character:FindFirstChild("Head")
	local bubbles = Effects.bubbles(if head and head:IsA("BasePart") then head else root, EFFECT_NAME, BUBBLE_RATE)
	return {
		character = character,
		instances = { attachment, align, bubbles },
		align = align,
		track = playSwim(character, humanoid),
	}
end

local function stopFloat(float: Float)
	if float.track then
		float.track:Stop()
	end
	for _, instance in float.instances do
		instance:Destroy()
	end
end

function PressureFloatController.init()
	local chamber = Workspace:WaitForChild(CHAMBER_NAME, WAIT_SECONDS)
	local zone = if chamber then chamber:WaitForChild(ZONE_NAME, WAIT_SECONDS) else nil
	if not zone or not zone:IsA("BasePart") then
		warn(`PressureFloatController: Workspace.{CHAMBER_NAME}.{ZONE_NAME} is missing; no chamber float`)
		return
	end
	local float: Float? = nil

	Remotes.getEvent("PressureUpdate").OnClientEvent:Connect(function(state: Types.PressureState)
		local current = float
		if current and (not state.inside or current.character ~= Players.LocalPlayer.Character) then
			stopFloat(current)
			float = nil
		end
		if state.inside and not float then
			float = startFloat(zone)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local current = float
		local root = if current then current.character:FindFirstChild("HumanoidRootPart") else nil
		if not current or not root or not root:IsA("BasePart") then
			return
		end
		local bob = math.sin(os.clock() * BOB_SPEED) * BOB_HEIGHT
		current.align.Position =
			Vector3.new(root.Position.X, zone.Position.Y + FLOAT_ABOVE_ZONE_CENTER + bob, root.Position.Z)
	end)
end

return PressureFloatController
