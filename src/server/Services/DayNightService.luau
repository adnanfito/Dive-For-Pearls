--!strict
-- Moves the sun so the island has day and night. Visual only. The server owns the clock so every
-- player sees the same sky. Nights pass faster than days and stay bright enough to play in.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local DAY_SECONDS = 180 -- 3 minutes daytime (pagi ke siang ke sore)
local NIGHT_SECONDS = 90 -- 1.5 minutes nighttime (malam berbintang)
local SUNRISE_HOUR = 6
local SUNSET_HOUR = 18
local START_HOUR = 10
local TWILIGHT_HOURS = 2.0 -- smooth transition around sunrise and sunset
local STEP_SECONDS = 0.5
local NIGHT_AMBIENT = Color3.fromRGB(75, 85, 130)
local NIGHT_OUTDOOR_AMBIENT = Color3.fromRGB(90, 100, 145)

local DayNightService = {}

local function isDay(hour: number): boolean
	return hour >= SUNRISE_HOUR and hour < SUNSET_HOUR
end

local function nightAmount(hour: number): number
	local toEdge = if isDay(hour)
		then math.min(hour - SUNRISE_HOUR, SUNSET_HOUR - hour)
		else -math.min((hour - SUNSET_HOUR) % 24, (SUNRISE_HOUR - hour) % 24)
	return math.clamp(0.5 - toEdge / TWILIGHT_HOURS, 0, 1)
end

function DayNightService.init()
	local dayAmbient = Lighting.Ambient
	local dayOutdoorAmbient = Lighting.OutdoorAmbient
	local hour = START_HOUR
	local waited = 0
	Lighting.ClockTime = hour
	RunService.Heartbeat:Connect(function(deltaTime)
		waited += deltaTime
		if waited < STEP_SECONDS then
			return
		end
		local hoursPerSecond = if isDay(hour)
			then (SUNSET_HOUR - SUNRISE_HOUR) / DAY_SECONDS
			else (24 - SUNSET_HOUR + SUNRISE_HOUR) / NIGHT_SECONDS
		hour = (hour + waited * hoursPerSecond) % 24
		waited = 0
		local night = nightAmount(hour)
		Lighting.ClockTime = hour
		Lighting.Ambient = dayAmbient:Lerp(NIGHT_AMBIENT, night)
		Lighting.OutdoorAmbient = dayOutdoorAmbient:Lerp(NIGHT_OUTDOOR_AMBIENT, night)
	end)
end

return DayNightService
