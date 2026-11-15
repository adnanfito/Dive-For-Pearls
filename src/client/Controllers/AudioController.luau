--!strict
-- Plays the game's sounds from SoundService.Sounds (set up in Studio, licensed library audio): one
-- music loop, the beach or underwater ambience loop, and short effects by name.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local FOLDER_NAME = "Sounds"
local WAIT_SECONDS = 10
local FADE_INFO = TweenInfo.new(1)
local UNDERWATER_MUSIC_SCALE = 0.5 -- music steps back so the underwater hum carries the mood

local AudioController = {}

local folder: Instance? = nil
local baseVolumes: { [Sound]: number } = {}
local underwater = false

local function find(name: string): Sound?
	local sounds = folder
	local sound = if sounds then sounds:FindFirstChild(name) else nil
	return if sound and sound:IsA("Sound") then sound else nil
end

local function fadeTo(name: string, scale: number)
	local sound = find(name)
	if sound then
		TweenService:Create(sound, FADE_INFO, { Volume = (baseVolumes[sound] or 0) * scale }):Play()
	end
end

-- A clone per play so quick repeats overlap instead of restarting each other.
function AudioController.play(name: string)
	local sound = find(name)
	if not sound then
		return
	end
	local copy = sound:Clone()
	copy.Parent = SoundService
	copy.Ended:Once(function()
		copy:Destroy()
	end)
	copy:Play()
end

function AudioController.setUnderwater(isUnderwater: boolean)
	if isUnderwater == underwater then
		return
	end
	underwater = isUnderwater
	fadeTo("Waves", if isUnderwater then 0 else 1)
	fadeTo("Underwater", if isUnderwater then 1 else 0)
	fadeTo("Music", if isUnderwater then UNDERWATER_MUSIC_SCALE else 1)
end

function AudioController.init()
	folder = SoundService:WaitForChild(FOLDER_NAME, WAIT_SECONDS)
	if not folder then
		warn(`AudioController: SoundService.{FOLDER_NAME} is missing; the game is silent`)
		return
	end
	for _, name in { "Music", "Waves", "Underwater" } do
		local sound = find(name)
		if sound then
			baseVolumes[sound] = sound.Volume
			sound.Looped = true
			sound:Play()
		end
	end
	local hum = find("Underwater")
	if hum then
		hum.Volume = 0
	end
end

return AudioController
