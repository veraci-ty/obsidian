--!nocheck

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local taskLib = require("@lune/task")

local reported = 0
local testTask = setmetatable({
	spawn = function(fn, ...)
		if fn == error then
			reported += 1
			return nil
		end
		return taskLib.spawn(fn, ...)
	end,
	reported = function()
		return reported
	end,
}, { __index = taskLib })

local listeners = {}
local listenerCount = 0

local heartbeat = {}
function heartbeat:Connect(fn)
	local connection = { Connected = true }
	listeners[connection] = fn
	listenerCount += 1
	function connection:Disconnect()
		if listeners[self] then
			listeners[self] = nil
			listenerCount -= 1
		end
		self.Connected = false
	end
	return connection
end

local runService = {
	Heartbeat = heartbeat,
	__step = function(dt)
		local snapshot = {}
		for _, fn in listeners do
			table.insert(snapshot, fn)
		end
		for _, fn in snapshot do
			fn(dt)
		end
	end,
	__connections = function()
		return listenerCount
	end,
}

local game = {}
function game:GetService(name)
	if name == "RunService" then
		return runService
	end
	error("service not mocked: " .. tostring(name))
end

local loaded = {}

local function load(path)
	if loaded[path] ~= nil then
		return loaded[path]
	end
	local base = string.match(path, "^(.*)/[^/]*$") or "."
	local env = {
		task = testTask,
		game = game,
		Vector2 = roblox.Vector2,
		Vector3 = roblox.Vector3,
		UDim2 = roblox.UDim2,
		UDim = roblox.UDim,
		Color3 = roblox.Color3,
		CFrame = roblox.CFrame,
	}
	env.require = function(name)
		local resolved = name
		if string.sub(name, 1, 3) == "../" then
			resolved = (string.match(base, "^(.*)/[^/]*$") or ".") .. "/" .. string.sub(name, 4)
		elseif string.sub(name, 1, 2) == "./" then
			resolved = base .. "/" .. string.sub(name, 3)
		end
		return load(resolved)
	end
	local chunk = luau.load(fs.readFile(path .. ".luau"), {
		debugName = path,
		environment = env,
		injectGlobals = true,
	})
	local result = chunk()
	loaded[path] = if result == nil then true else result
	return result
end

local ok = true
for _, spec in { "tests/reactive.spec", "tests/spring.spec" } do
	local success, err = pcall(load, spec)
	if not success then
		print(err)
		ok = false
	end
end

if not ok then
	error("tests failed", 0)
end
