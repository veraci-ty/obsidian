--!strict

local Reactive = require "../src/Reactive"
local ObsidianInstance = require "../src/Instance"

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

local new = ObsidianInstance.new

do
	local items = Reactive.source({ "a", "b", "c" })
	local frame = new "Frame" {
		[1] = function()
			local out = {}
			for _, name in items() do
				table.insert(out, new "TextLabel" { Name = name, Text = name })
			end
			return out
		end,
	}
	check("function children render initially", #frame:GetChildren() == 3)
	local first = frame:FindFirstChild("a")
	items({ "b" })
	check("stale function children are removed", #frame:GetChildren() == 1 and frame:FindFirstChild("b") ~= nil)
	check("stale owned children are destroyed", first ~= nil and first.Parent == nil)
	items({ "x", "y", "z", "w" })
	check("function children grow again", #frame:GetChildren() == 4)
	frame:Destroy()
end

do
	local external = Instance.new("Folder")
	external.Name = "External"
	local show = Reactive.source(true)
	local frame = new "Frame" {
		[1] = function()
			return if show() then external else nil
		end,
	}
	check("external child is parented", external.Parent == frame)
	show(false)
	check("external child is unparented, not destroyed", external.Parent == nil)
	show(true)
	check("external child can be shown again", external.Parent == frame)
	frame:Destroy()
end

do
	local keep = Instance.new("Folder")
	keep.Name = "Keep"
	local extra = Reactive.source(false)
	local frame = new "Frame" {
		[1] = function()
			local out: { Instance } = { keep }
			if extra() then
				table.insert(out, new "Frame" { Name = "Extra" })
			end
			return out
		end,
	}
	local parentChanges = 0
	keep:GetPropertyChangedSignal("Parent"):Connect(function()
		parentChanges += 1
	end)
	extra(true)
	extra(false)
	check("children present in both results are not reparented", parentChanges == 0 and keep.Parent == frame)
	check("removed dynamic child is gone", frame:FindFirstChild("Extra") == nil)
	frame:Destroy()
end

do
	local count = Reactive.source(1)
	local created: { Instance } = {}
	local _, dispose = Reactive.root(function()
		return new "Frame" {
			[1] = function()
				local out = {}
				for i = 1, count() do
					local label = new "TextLabel" { Name = tostring(i) }
					table.insert(created, label)
					table.insert(out, label)
				end
				return out
			end,
		}
	end)
	count(3)
	count(2)
	local alive = 0
	for _, label in created do
		if label.Parent ~= nil then
			alive += 1
		end
	end
	check("only the latest results stay alive", alive == 2)
	dispose()
end

print(string.format("instance: %d passed, %d failed", passes, failures))
if failures > 0 then
	error("instance tests failed", 0)
end
