--!strict
-- Client-only ambience in the dive zones: fish swim in loose circles around their group, and the
-- screen tint deepens as the camera goes down (GDD "Visual dan UX": deep water gets darker).
-- Reads Workspace.DiveZones.<zoneId>.{Surface, Scenery.Fish}, built in Studio.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioController = require("./AudioController")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))

local ZONES_FOLDER_NAME = "DiveZones"
local SURFACE_NAME = "Surface"
local FISH_FOLDER_NAME = "Fish"
local WAIT_SECONDS = 10
local TINT_NAME = "ColorCorrection"
local DEEP_TINT = Color3.fromRGB(125, 180, 255)
local DEEP_BRIGHTNESS_DROP = 0.12
local FISH_SPEED = 0.35 -- radians per second around the group centre
local FISH_BOB = 0.8
local FISH_MIN_RADIUS = 6
local FISH_RADIUS_STEP = 1.5 -- each fish in a school circles a little wider than the last

type Swimmer = { center: Vector3, radius: number, angle: number, height: number, direction: number }

local AmbientController = {}

-- Not weak-keyed: Instance keys in weak tables can be collected while the instance still exists.
local swimmers: { [Model]: Swimmer } = {}

-- Fish of one group share a centre and direction so they move as a school.
local function learnSchool(fishFolder: Instance)
	local groups: { [number]: { Model } } = {}
	for _, fish in fishFolder:GetChildren() do
		local group = fish:GetAttribute("Group")
		if fish:IsA("Model") and typeof(group) == "number" and not swimmers[fish] then
			groups[group] = groups[group] or {}
			table.insert(groups[group], fish)
		end
	end
	for group, members in groups do
		local sum = Vector3.zero
		for _, fish in members do
			sum += fish:GetPivot().Position
		end
		local center = sum / #members
		for index, fish in members do
			local offset = fish:GetPivot().Position - center
			swimmers[fish] = {
				center = center,
				radius = FISH_MIN_RADIUS + index * FISH_RADIUS_STEP,
				angle = math.atan2(offset.Z, offset.X),
				height = offset.Y,
				direction = if group % 2 == 0 then 1 else -1,
			}
		end
	end
end

local function swim(now: number)
	for fish, s in swimmers do
		if not fish.Parent then
			swimmers[fish] = nil
		else
			local angle = s.angle + now * FISH_SPEED * s.direction
			local position = s.center
				+ Vector3.new(
					math.cos(angle) * s.radius,
					s.height + math.sin(now + s.angle) * FISH_BOB,
					math.sin(angle) * s.radius
				)
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * s.direction
			fish:PivotTo(CFrame.lookAt(position, position + tangent))
		end
	end
end

-- 0 at a zone's surface to 1 at its bottom while the camera is inside a zone, otherwise nil.
local function cameraDepthFraction(zones: Instance): number?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local position = camera.CFrame.Position
	for _, zone in zones:GetChildren() do
		local surface = zone:FindFirstChild(SURFACE_NAME)
		if surface and surface:IsA("BasePart") then
			local offset = position - surface.Position
			local half = surface.Size / 2
			if math.abs(offset.X) <= half.X and math.abs(offset.Z) <= half.Z and offset.Y < 0 then
				return math.clamp(-offset.Y / Economy.ZONE_HEIGHT_STUDS, 0, 1)
			end
		end
	end
	return nil
end

function AmbientController.init()
	local zones = Workspace:WaitForChild(ZONES_FOLDER_NAME, WAIT_SECONDS)
	local tint = Lighting:FindFirstChild(TINT_NAME)
	if not zones or not tint or not tint:IsA("ColorCorrectionEffect") then
		warn("AmbientController: Workspace.DiveZones or Lighting.ColorCorrection is missing; no ambience")
		return
	end
	local baseTint = tint.TintColor
	local baseBrightness = tint.Brightness

	-- Streaming can add fish later, so new ones are picked up as they arrive.
	local function watch(instance: Instance)
		if instance.Name ~= FISH_FOLDER_NAME or not instance:IsA("Folder") then
			return
		end
		learnSchool(instance)
		instance.ChildAdded:Connect(function()
			learnSchool(instance)
		end)
	end
	for _, descendant in zones:GetDescendants() do
		watch(descendant)
	end
	zones.DescendantAdded:Connect(watch)

	RunService.RenderStepped:Connect(function()
		swim(os.clock())
		local fraction = cameraDepthFraction(zones)
		AudioController.setUnderwater(fraction ~= nil)
		tint.TintColor = if fraction then baseTint:Lerp(DEEP_TINT, fraction) else baseTint
		tint.Brightness = if fraction then baseBrightness - DEEP_BRIGHTNESS_DROP * fraction else baseBrightness
	end)
end

return AmbientController
