--!strict
-- Particle effects shared by the controllers, so bubbles look the same in the chamber and the sea.

local Effects = {}

function Effects.bubbles(parent: BasePart, name: string, rate: number): ParticleEmitter
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = name
	bubbles.Color = ColorSequence.new(Color3.fromRGB(230, 250, 255))
	bubbles.LightEmission = 0.4
	bubbles.Rate = rate
	bubbles.Lifetime = NumberRange.new(1.5, 2.5)
	bubbles.Speed = NumberRange.new(2, 3.5)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.SpreadAngle = Vector2.new(15, 15)
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.5) })
	bubbles.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.9) })
	bubbles.Parent = parent
	return bubbles
end

return Effects
