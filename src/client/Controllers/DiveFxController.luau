--!strict
-- How a dive feels, visual only: a bubble burst and a soft blue flash when the diver splashes in,
-- a bubble trail from the head, and tiny drifting specks around the camera so the water looks
-- alive. The flash frame lives in StarterGui.DiveFxGui (built in Studio).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Effects = require("../Effects")
local Gui = require("../Gui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local TRAIL_NAME = "DiveTrail"
local TRAIL_RATE = 5
local SPLASH_NAME = "DiveSplash"
local SPLASH_BUBBLES = 40
local SPLASH_SPEED = NumberRange.new(4, 9)
local SPLASH_SPREAD = Vector2.new(70, 70)
local SPLASH_LIFETIME_SECONDS = 3
local FLASH_START = 0.35
local FLASH_INFO = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPECK_BOX = Vector3.new(60, 40, 60)
local SPECK_RATE = 30

local DiveFxController = {}

local function makeSpecks(): (Part, ParticleEmitter)
	local holder = Instance.new("Part")
	holder.Name = "DiveSpecks"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = SPECK_BOX
	local specks = Instance.new("ParticleEmitter")
	specks.Shape = Enum.ParticleEmitterShape.Box
	specks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	specks.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	specks.LightEmission = 0.6
	specks.Rate = SPECK_RATE
	specks.Lifetime = NumberRange.new(4, 6)
	specks.Speed = NumberRange.new(0.2, 0.6)
	specks.SpreadAngle = Vector2.new(180, 180)
	specks.Size = NumberSequence.new(0.12)
	specks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(0.8, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	specks.Enabled = false
	specks.Parent = holder
	holder.Parent = Workspace.CurrentCamera
	return holder, specks
end

local function splash(flash: GuiObject)
	local root = Gui.localRoot()
	if root then
		local burst = Effects.bubbles(root, SPLASH_NAME, 0)
		burst.Speed = SPLASH_SPEED
		burst.SpreadAngle = SPLASH_SPREAD
		burst:Emit(SPLASH_BUBBLES)
		task.delay(SPLASH_LIFETIME_SECONDS, function()
			burst:Destroy()
		end)
	end
	flash.BackgroundTransparency = FLASH_START
	flash.Visible = true
	local fade = TweenService:Create(flash, FLASH_INFO, { BackgroundTransparency = 1 })
	fade.Completed:Once(function()
		flash.Visible = false
	end)
	fade:Play()
end

-- The trail sits on the head; a respawned character gets a new one on the next update.
local function ensureTrail(trail: ParticleEmitter?): ParticleEmitter?
	if trail and trail.Parent then
		return trail
	end
	local root = Gui.localRoot()
	local character = if root then root.Parent else nil
	local head = if character then character:FindFirstChild("Head") else nil
	local anchor = if head and head:IsA("BasePart") then head else root
	return if anchor then Effects.bubbles(anchor, TRAIL_NAME, TRAIL_RATE) else nil
end

function DiveFxController.init()
	local flash = Gui.waitFor(Gui.screen("DiveFxGui"), "Flash") :: GuiObject
	local holder, specks = makeSpecks()
	local diving = false
	local trail: ParticleEmitter? = nil

	Remotes.getEvent("DiveUpdate").OnClientEvent:Connect(function(state: Types.DiveState)
		if state.diving and not diving then
			splash(flash)
		end
		diving = state.diving
		specks.Enabled = diving
		if diving then
			trail = ensureTrail(trail)
		elseif trail then
			trail:Destroy()
			trail = nil
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if diving and camera then
			holder.CFrame = camera.CFrame
		end
	end)
end

return DiveFxController
