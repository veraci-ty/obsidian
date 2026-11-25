--!strict

local Reactive = require "./Reactive"

local Children = {}
local Parent = {}
local OnDestroy = {}
local Ref = {}

export type ComponentProps<T> = T & {
	[any]: any,
}

export type InstanceClassName = 
| "ScreenGui"
| "SurfaceGui"
| "BillboardGui"
| "Frame"
| "TextButton"
| "TextLabel"
| "ImageButton"
| "ImageLabel"
| "ScrollingFrame"
| "ViewportFrame"
| "CanvasGroup"
| "UICorner"
| "UIStroke"
| "UIGradient"
| "UIGridLayout"
| "UIListLayout"
| "UIPadding"
| "UISizeConstraint"
| "UIAspectRatioConstraint"
| "UITextSizeConstraint"
| "TextBox"
| string

export type EstablishedComponentName = string

export type ComponentName = InstanceClassName | EstablishedComponentName

local registry: { [string]: (props: { [any]: any }) -> Instance } = {}
local ctorCache: { [string]: (props: { [any]: any }) -> Instance } = {}
local creationLogs: { { [Instance]: boolean } } = {}

local function logCreation(instance: Instance)
	local log = creationLogs[#creationLogs]
	if log then
		log[instance] = true
	end
end

local function collectChildren(result: any, out: { Instance }, seen: { [Instance]: boolean })
	if typeof(result) == "Instance" then
		if not seen[result] then
			seen[result] = true
			table.insert(out, result)
		end
	elseif type(result) == "table" then
		for _, c in result do
			if typeof(c) == "Instance" and not seen[c] then
				seen[c] = true
				table.insert(out, c)
			end
		end
	end
end

local function bindChildren(instance: Instance, render: () -> any): () -> ()
	local current: { [Instance]: boolean } = {}
	local owned: { [Instance]: boolean } = {}
	local function release(child: Instance)
		if owned[child] then
			owned[child] = nil
			child:Destroy()
		elseif child.Parent == instance then
			child.Parent = nil
		end
	end
	local stop = Reactive.effect(function()
		local log: { [Instance]: boolean } = {}
		local depth = #creationLogs + 1
		creationLogs[depth] = log
		local ok, result = pcall(render)
		for i = #creationLogs, depth, -1 do
			creationLogs[i] = nil
		end
		if not ok then
			error(result, 0)
		end
		local list: { Instance } = {}
		local nextSet: { [Instance]: boolean } = {}
		collectChildren(result, list, nextSet)
		for _, c in list do
			if log[c] then
				owned[c] = true
			end
			c.Parent = instance
		end
		for c in current do
			if not nextSet[c] then
				release(c)
			end
		end
		current = nextSet
	end)
	return function()
		stop()
		for c in current do
			if owned[c] then
				c:Destroy()
			end
		end
		table.clear(current)
		table.clear(owned)
	end
end

local function applyProps(instance: Instance, props: { [any]: any }): { () -> () }
	local cleanups = {}
	for key, value in props do
		if key == Children then
			local children = value :: { Instance }
			for i = 1, #children do
				children[i].Parent = instance
			end
		elseif key == Parent then
			if type(value) == "function" then
				local stop = Reactive.effect(function()
					instance.Parent = value()
				end)
				table.insert(cleanups, stop)
			else
				instance.Parent = value
			end
		elseif key == OnDestroy then
			table.insert(cleanups, value)
		elseif key == Ref then
			if type(value) == "function" then
				value(instance)
			else
				value:set(instance)
			end
		elseif type(key) == "number" then
			local child = value
			if typeof(child) == "Instance" then
				child.Parent = instance
			elseif type(child) == "function" then
				table.insert(cleanups, bindChildren(instance, child))
			elseif type(child) == "table" then
				for _, c in child do
					if typeof(c) == "Instance" then
						c.Parent = instance
					end
				end
			end
		else
			local prop = (instance :: any)[key]
			if typeof(prop) == "RBXScriptSignal" then
				local conn = prop:Connect(value)
				table.insert(cleanups, function()
					conn:Disconnect()
				end)
			elseif type(value) == "function" then
				local stop = Reactive.effect(function()
					(instance :: any)[key] = value()
				end)
				table.insert(cleanups, stop)
			else
				(instance :: any)[key] = value
			end
		end
	end
	return cleanups
end

local function createCtor(className: string): (props: { [any]: any }) -> Instance
	return function(props: { [any]: any }): Instance
		local instance = Instance.new(className)
		logCreation(instance)
		local cleanups = applyProps(instance, props)
		if #cleanups > 0 then
			instance.Destroying:Once(function()
				for i = 1, #cleanups do
					cleanups[i]()
				end
			end)
		end
		return instance
	end
end

setmetatable(ctorCache, {
	__index = function(self, className: string)
		local ctor = createCtor(className)
		rawset(self, className, ctor)
		return ctor
	end,
})

local function New(className: InstanceClassName)
	return ctorCache[className]
end

local function new(className: ComponentName)
	local established = registry[className]
	if established then
		return established
	end
	return ctorCache[className]
end

local function establish<T>(name: string, factory: (props: ComponentProps<T>) -> Instance): (props: ComponentProps<T>) -> Instance
	registry[name] = factory :: (props: { [any]: any }) -> Instance
	return factory
end

local function mount(render: () -> Instance, parent: Instance): Instance
	local instance, cleanup = Reactive.root(function()
		return render()
	end)
	instance.Parent = parent
	instance.Destroying:Once(function()
		cleanup()
	end)
	return instance
end

local function apply(instance: Instance): (props: { [any]: any }) -> Instance
	return function(props: { [any]: any }): Instance
		local cleanups = applyProps(instance, props)
		if #cleanups > 0 then
			instance.Destroying:Once(function()
				for i = 1, #cleanups do
					cleanups[i]()
				end
			end)
		end
		return instance
	end
end

return {
	New = New,
	new = new,
	Children = Children,
	Parent = Parent,
	OnDestroy = OnDestroy,
	Ref = Ref,
	mount = mount,
	attach = mount,
	establish = establish,
	apply = apply,
}
