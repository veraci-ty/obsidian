--!strict

local RunService = game:GetService("RunService")
local Reactive = require "../src/Reactive"
local Spring = require "../src/Spring"

local failures = 0
local passes = 0

local function check(name: string, condition: boolean)
	if condition then
		passes += 1
	else
		failures += 1
		print("FAIL: " .. name)
	end
end

local mock = RunService :: any
local manual = type(mock.__step) == "function"

local function advance(seconds: number)
	if manual then
		local remaining = seconds
		while remaining > 0 do
			local dt = math.min(remaining, 1 / 60)
			mock.__step(dt)
			remaining -= dt
		end
	else
		task.wait(seconds)
	end
end

local function connected(): number?
	if manual then
		return mock.__connections()
	end
	return nil
end

do
	local target = Reactive.source(0)
	local value, dispose = Reactive.root(function()
		return Spring.spring(target, 0.5, 0.3)
	end)
	check("spring starts at its initial value", value() == 0)
	target(1)
	local peak = 0
	for _ = 1, 120 do
		advance(1 / 60)
		peak = math.max(peak, value())
	end
	check("underdamped spring overshoots", peak > 1.05)
	advance(10)
	check("spring settles exactly on target", value() == 1)
	local count = connected()
	if count then
		check("heartbeat disconnects when every spring rests", count == 0)
	end
	target(2)
	advance(1 / 30)
	count = connected()
	if count then
		check("heartbeat reconnects when a spring wakes", count == 1)
	end
	dispose()
	count = connected()
	if count then
		check("disposing the owning root removes the spring", count == 0)
	end
	local frozen = value()
	advance(0.5)
	check("disposed spring stops writing output", value() == frozen)
end

do
	local target = Reactive.source(0)
	local value, dispose = Reactive.root(function()
		return Spring.spring(target, 0.4, 1)
	end)
	target(1)
	local peak = 0
	for _ = 1, 300 do
		advance(1 / 60)
		peak = math.max(peak, value())
	end
	check("critically damped spring does not overshoot", peak <= 1 + 1e-6)
	dispose()
end

do
	local target = Reactive.source(Vector3.zero)
	local value, dispose = Reactive.root(function()
		return Spring.spring(target, 0.3, 0.8)
	end)
	target(Vector3.new(10, 0, 0))
	advance(0.1)
	local mid = value()
	check("Vector3 spring moves between endpoints", mid.X > 0 and mid.X < 10)
	advance(5)
	check("Vector3 spring settles", value() == Vector3.new(10, 0, 0))
	dispose()
end

do
	local target = Reactive.source(UDim2.fromOffset(0, 0))
	local value, dispose = Reactive.root(function()
		return Spring.spring(target, 0.3, 0.8)
	end)
	target(UDim2.new(1, 100, 0.5, 50))
	advance(0.1)
	local mid = value()
	check("UDim2 spring animates scale and offset", mid.X.Scale > 0 and mid.X.Scale < 1 and mid.Y.Offset > 0)
	advance(5)
	check("UDim2 spring settles", value() == UDim2.new(1, 100, 0.5, 50))
	dispose()
end

do
	local target = Reactive.source(Color3.new(0, 0, 0))
	local value, dispose = Reactive.root(function()
		return Spring.spring(target, 0.3, 0.5)
	end)
	target(Color3.new(1, 1, 1))
	for _ = 1, 120 do
		advance(1 / 60)
		local c = value()
		if c.R > 1 or c.R < 0 then
			check("Color3 spring stays in range", false)
		end
	end
	advance(5)
	check("Color3 spring settles", value() == Color3.new(1, 1, 1))
	dispose()
end

do
	local start = CFrame.new(0, 0, 0)
	local finish = CFrame.new(4, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
	local target = Reactive.source(start)
	local value, dispose = Reactive.root(function()
		return Spring.spring(target, 0.3, 1)
	end)
	target(finish)
	advance(0.08)
	local mid = value()
	local _, angle = (start:ToObjectSpace(mid)):ToAxisAngle()
	check("CFrame spring interpolates rotation", angle > 0.01 and angle < math.pi / 2 - 0.01)
	check("CFrame spring interpolates position", mid.Position.X > 0 and mid.Position.X < 4)
	advance(5)
	check("CFrame spring settles", value() == finish)
	dispose()
end

do
	local state = Reactive.Value(5)
	local value, dispose = Reactive.root(function()
		return Spring.spring(state)
	end)
	state:set(6)
	advance(5)
	check("spring accepts a State object", value() == 6)
	dispose()
end

do
	local label = Reactive.source("a")
	local value, dispose = Reactive.root(function()
		return Spring.spring(label)
	end)
	label("b")
	check("unsupported types snap", value() == "b")
	dispose()
end

do
	local target = Reactive.source(0)
	local _, dispose = Reactive.root(function()
		for _ = 1, 50 do
			Spring.spring(target)
		end
		return nil
	end)
	target(1)
	dispose()
	local count = connected()
	if count then
		check("many springs are released with their root", count == 0)
	end
end

print(string.format("spring: %d passed, %d failed", passes, failures))
if failures > 0 then
	error("spring tests failed", 0)
end
