--!strict

local RunService = game:GetService("RunService")
local Reactive = require "./Reactive"

type Source<T> = Reactive.Source<T>
type State<T> = Reactive.State<T>

type SpringState = {
	getTarget: () -> any,
	current: any,
	target: any,
	period: number,
	damping: number,
	output: Source<any>,
}

local springs: { SpringState } = {}
local heartbeat: RBXScriptConnection? = nil

@native
local function lerp(a, b, t)
	if typeof(a) == "number" then
		return a + (b - a) * t
	end
	if typeof(a) == "Color3" then
		return a:Lerp(b, t)
	end
	if typeof(a) == "UDim2" then
		return a:Lerp(b, t)
	end
	if typeof(a) == "Vector2" then
		return a:Lerp(b, t)
	end
	if typeof(a) == "Vector3" then
		return a:Lerp(b, t)
	end
	return b
end

--[[
TODO: stress test this make sure i dont get any nan values, might optimize if this does end up running every frame which i assume it would. 

Maybe clamp alpha: alpha = math.clamp(alpha, 0, 1)?
idk man
--]]
@native
local function stepSprings(dt: number)
	for _, s in springs do
		s.target = s.getTarget()
		local speed = 1 / math.max(s.period, 0.001)
		local alpha = 1 - math.exp(-speed * dt * s.damping)
		s.current = lerp(s.current, s.target, alpha)
		s.output(s.current)
	end
end

local function ensureHeartbeat()
	if heartbeat then
		return
	end
	heartbeat = RunService.Heartbeat:Connect(stepSprings)
end

local function spring<T>(input: (() -> T) | State<T>, period: number?, damping: number?)
	local getter = if type(input) == "function"
		then input :: () -> T
		else function()
			return (input :: State<T>):get()
		end
	local initial = getter()
	local out = Reactive.source(initial)
	local state: SpringState = {
		getTarget = getter,
		current = initial,
		target = initial,
		period = period or 0.35,
		damping = damping or 0.8,
		output = out,
	}
	table.insert(springs, state)
	ensureHeartbeat()
	return function()
		return out()
	end
end

return {
	spring = spring,
}
