--!strict

local Reactive = require "../src/Reactive"

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

do
	local name = Reactive.source("World")
	local runs = 0
	local last = ""
	Reactive.effect(function()
		runs += 1
		last = "Hello, " .. name() .. "!"
	end)
	check("unowned effect runs initially", runs == 1 and last == "Hello, World!")
	name("Obsidian")
	check("unowned effect re-runs on change", runs == 2 and last == "Hello, Obsidian!")
end

do
	local count = Reactive.source(1)
	local doubled = Reactive.derive(function()
		return count() * 2
	end)
	local quadrupled = Reactive.derive(function()
		return doubled() * 2
	end)
	local seen: { number } = {}
	Reactive.effect(function()
		table.insert(seen, quadrupled())
	end)
	count(2)
	count(3)
	check("effect depending only on a chained derive updates", #seen == 3 and seen[2] == 8 and seen[3] == 12)
end

do
	local a = Reactive.source(1)
	local b = Reactive.derive(function()
		return a() + 1
	end)
	local c = Reactive.derive(function()
		return a() * 10
	end)
	local runs = 0
	local glitch = false
	Reactive.effect(function()
		runs += 1
		if c() ~= (b() - 1) * 10 then
			glitch = true
		end
	end)
	a(5)
	check("diamond dependency runs once per change", runs == 2)
	check("diamond dependency is glitch free", not glitch)
end

do
	local n = Reactive.source(2)
	local parity = Reactive.derive(function()
		return n() % 2
	end)
	local runs = 0
	Reactive.effect(function()
		parity()
		runs += 1
	end)
	n(4)
	check("effect skipped when derive value is unchanged", runs == 1)
	n(5)
	check("effect runs when derive value changes", runs == 2)
end

do
	local flag = Reactive.source(true)
	local left = Reactive.source("left")
	local right = Reactive.source("right")
	local picked = Reactive.derive(function()
		return if flag() then left() else right()
	end)
	local last = ""
	Reactive.effect(function()
		last = picked()
	end)
	flag(false)
	right("right2")
	check("dynamic dependencies of a derive are tracked", last == "right2")
	left("ignored")
	check("dropped dependencies no longer trigger", last == "right2")
end

do
	local s = Reactive.source(0)
	local runs = 0
	local cleaned = 0
	local _, dispose = Reactive.root(function()
		Reactive.effect(function()
			s()
			runs += 1
			Reactive.cleanup(function()
				cleaned += 1
			end)
		end)
		return nil
	end)
	s(1)
	check("owned effect re-runs and cleans previous run", runs == 2 and cleaned == 1)
	dispose()
	check("dispose runs final cleanup", cleaned == 2)
	s(2)
	check("disposed effect does not re-run", runs == 2)
end

do
	local a = Reactive.source(1)
	local b = Reactive.source(1)
	local runs = 0
	Reactive.effect(function()
		a()
		b()
		runs += 1
	end)
	Reactive.batch(function()
		a(2)
		b(2)
	end)
	check("batch coalesces updates", runs == 2)
end

do
	local outer = Reactive.source(0)
	local inner = Reactive.source(0)
	local outerRuns = 0
	Reactive.effect(function()
		outer()
		outerRuns += 1
		Reactive.untrack(function()
			return inner()
		end)
	end)
	inner(1)
	check("untrack does not subscribe", outerRuns == 1)
end

do
	local s = Reactive.source(0)
	local runs = 0
	local counter = (task :: any).reported
	local before = if type(counter) == "function" then counter() else 0
	Reactive.effect(function()
		runs += 1
		if s() == 1 then
			error("boom")
		end
	end)
	s(1)
	s(2)
	if type(counter) == "function" then
		check("errors are reported", counter() == before + 1)
	end
	check("effect survives an error and keeps tracking", runs == 3)
end

print(string.format("reactive: %d passed, %d failed", passes, failures))
if failures > 0 then
	error("reactive tests failed", 0)
end
