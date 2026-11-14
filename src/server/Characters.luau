--!strict
-- Server-side lookups on player characters, shared by the services that check positions.
local Characters = {}

-- nil while the character is dead, respawning or not spawned yet.
function Characters.aliveRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root
end

return Characters
