--!strict
-- Single registry of remotes. The server creates exactly the names listed here; both sides look
-- them up through this module.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local CLIENT_WAIT_SECONDS = 10

local EVENT_NAMES: { string } = {
	"PressureUpdate", -- server to client only
	"DiveUpdate", -- server to client only
	"DiveShells", -- server to client only
	"DiveNotice", -- server to client only
}
local FUNCTION_NAMES: { string } = {
	"BuyPressureUpgrade",
	"UseLift",
	"CollectShell",
}

local Remotes = {}

function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init must run on the server")
	assert(not ReplicatedStorage:FindFirstChild(FOLDER_NAME), "Remotes.init called twice")

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in EVENT_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in FUNCTION_NAMES do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

local function findRemote(name: string, className: string): Instance
	local folder = if RunService:IsServer()
		then ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		else ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_WAIT_SECONDS)
	assert(folder, `Remotes: folder "{FOLDER_NAME}" missing; did the server call Remotes.init?`)

	local remote = if RunService:IsServer()
		then folder:FindFirstChild(name)
		else folder:WaitForChild(name, CLIENT_WAIT_SECONDS)
	assert(remote and remote:IsA(className), `Remotes: no {className} named "{name}"`)
	return remote
end

function Remotes.getEvent(name: string): RemoteEvent
	return findRemote(name, "RemoteEvent") :: RemoteEvent
end

function Remotes.getFunction(name: string): RemoteFunction
	return findRemote(name, "RemoteFunction") :: RemoteFunction
end

return Remotes
