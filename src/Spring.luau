--!strict
--!optimize 2

local RunService = game:GetService("RunService")
local Reactive = require "./Reactive"

type Source<T> = Reactive.Source<T>
type State<T> = Reactive.State<T>

type SpringState = {
	kind: string,
	position: { number },
	velocity: { number },
	goal: { number },
	target: any,
	omega: number,
	zeta: number,
	output: Source<any>,
	active: boolean,
	alive: boolean,
}

local SUBSTEP = 1 / 240
local MAX_FRAME = 0.1
local REST_EPSILON = 1e-4
local MIN_PERIOD = 1e-3

local active: { [SpringState]: boolean } = {}
local activeCount = 0
local accumulator = 0
local heartbeat: RBXScriptConnection? = nil

local function pack(value: any): { number }?
	local kind = typeof(value)
	if kind == "number" then
		return { value }
	elseif kind == "Vector2" then
		return { value.X, value.Y }
	elseif kind == "Vector3" then
		return { value.X, value.Y, value.Z }
	elseif kind == "UDim2" then
		return { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
	elseif kind == "Color3" then
		return { value.R, value.G, value.B }
	elseif kind == "CFrame" then
		local axis, angle = value:ToAxisAngle()
		local s = math.sin(angle / 2)
		local p = value.Position
		return { p.X, p.Y, p.Z, axis.X * s, axis.Y * s, axis.Z * s, math.cos(angle / 2) }
	end
	return nil
end

local function unpack(kind: string, v: { number }): any
	if kind == "number" then
		return v[1]
	elseif kind == "Vector2" then
		return Vector2.new(v[1], v[2])
	elseif kind == "Vector3" then
		return Vector3.new(v[1], v[2], v[3])
	elseif kind == "UDim2" then
		return UDim2.new(v[1], v[2], v[3], v[4])
	elseif kind == "Color3" then
		return Color3.new(math.clamp(v[1], 0, 1), math.clamp(v[2], 0, 1), math.clamp(v[3], 0, 1))
	elseif kind == "CFrame" then
		local qx, qy, qz, qw = v[4], v[5], v[6], v[7]
		local length = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
		if length < 1e-9 then
			return CFrame.new(v[1], v[2], v[3])
		end
		return CFrame.new(v[1], v[2], v[3], qx / length, qy / length, qz / length, qw / length)
	end
	return nil
end

local function step(dt: number)
	accumulator += math.min(dt, MAX_FRAME)
	local steps = math.floor(accumulator / SUBSTEP)
	if steps <= 0 then
		return
	end
	accumulator -= steps * SUBSTEP
	local settled: { SpringState } = {}
	local moving: { SpringState } = {}
	for s in active do
		local x, v, g = s.position, s.velocity, s.goal
		local w2h = s.omega * s.omega * SUBSTEP
		local denominator = 1 + 2 * s.zeta * s.omega * SUBSTEP + w2h * SUBSTEP
		for _ = 1, steps do
			for i = 1, #x do
				local vi = (v[i] - w2h * (x[i] - g[i])) / denominator
				v[i] = vi
				x[i] += vi * SUBSTEP
			end
		end
		local resting = true
		for i = 1, #x do
			if math.abs(x[i] - g[i]) > REST_EPSILON or math.abs(v[i]) > REST_EPSILON then
				resting = false
				break
			end
		end
		if resting then
			table.insert(settled, s)
		else
			table.insert(moving, s)
		end
	end
	for _, s in settled do
		active[s] = nil
		activeCount -= 1
		s.active = false
		table.move(s.goal, 1, #s.goal, 1, s.position)
		for i = 1, #s.position do
			s.velocity[i] = 0
		end
	end
	if activeCount <= 0 then
		activeCount = 0
		accumulator = 0
		if heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end
	Reactive.batch(function()
		for _, s in moving do
			s.output(unpack(s.kind, s.position))
		end
		for _, s in settled do
			s.output(s.target)
		end
	end)
end

local function activate(s: SpringState)
	if s.active or not s.alive then
		return
	end
	s.active = true
	active[s] = true
	activeCount += 1
	if not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
end

local function deactivate(s: SpringState)
	if not s.active then
		return
	end
	s.active = false
	active[s] = nil
	activeCount -= 1
	if activeCount <= 0 then
		activeCount = 0
		accumulator = 0
		if heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end
end

local function zeros(n: number): { number }
	return table.create(n, 0)
end

local function setTarget(s: SpringState, value: any)
	local kind = typeof(value)
	local goal = pack(value)
	s.target = value
	if goal == nil or kind ~= s.kind or #s.position ~= #goal then
		s.kind = kind
		s.goal = goal or {}
		s.position = table.clone(s.goal)
		s.velocity = zeros(#s.goal)
		deactivate(s)
		s.output(value)
		return
	end
	if kind == "CFrame" then
		local x = s.position
		local dot = x[4] * goal[4] + x[5] * goal[5] + x[6] * goal[6] + x[7] * goal[7]
		if dot < 0 then
			for i = 4, 7 do
				goal[i] = -goal[i]
			end
		end
	end
	s.goal = goal
	activate(s)
end

local function spring<T>(input: (() -> T) | State<T>, period: number?, damping: number?): () -> T
	local getter: () -> T
	if type(input) == "function" then
		getter = input :: () -> T
	else
		local state = input :: State<T>
		getter = function(): T
			return state:get()
		end
	end
	local omega = 2 * math.pi / math.max(period or 0.35, MIN_PERIOD)
	local zeta = math.max(damping or 0.8, 0)
	local output = Reactive.source(nil :: any)
	local s: SpringState = {
		kind = "",
		position = {},
		velocity = {},
		goal = {},
		target = nil,
		omega = omega,
		zeta = zeta,
		output = output,
		active = false,
		alive = true,
	}
	Reactive.effect(function()
		setTarget(s, getter())
	end)
	Reactive.cleanup(function()
		s.alive = false
		deactivate(s)
	end)
	return function(): T
		return output()
	end
end

return {
	spring = spring,
}
