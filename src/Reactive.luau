--!strict

export type Source<T> = (() -> T) & ((T) -> T)
export type State<T> = {
	get: (State<T>) -> T,
	set: (State<T>, T) -> (),
	update: (State<T>, (T) -> T) -> (),
	source: Source<T>,
}

type Node = {
	cache: any,
	effect: ((any) -> any)?,
	deps: { [SourceNode]: boolean },
	owner: Node?,
	owned: { Node }?,
	cleanups: { () -> () }?,
	dirty: boolean,
}

type SourceNode = {
	cache: any,
	children: { [Node]: boolean },
}

local scopeStack: { Node } = {}
local updateQueue: { Node } = {}
local updateSet: { [Node]: boolean } = {}
local batching = false
local batchDepth = 0

local function getCurrentScope(): Node?
	return scopeStack[#scopeStack]
end

local function pushScope(node: Node)
	table.insert(scopeStack, node)
end

local function popScope()
	table.remove(scopeStack)
end

local function addCleanup(node: Node, fn: () -> ())
	if node.cleanups then
		table.insert(node.cleanups, fn)
	else
		node.cleanups = { fn }
	end
end

local function flushCleanups(node: Node)
	if node.cleanups then
		for _, fn in node.cleanups do
			pcall(fn)
		end
		table.clear(node.cleanups)
	end
end

local function unsubscribe(node: Node)
	for dep in node.deps do
		dep.children[node] = nil
	end
	table.clear(node.deps)
end

local function destroyNode(node: Node)
	flushCleanups(node)
	unsubscribe(node)
	if node.owner and node.owner.owned then
		local idx = table.find(node.owner.owned, node)
		if idx then
			local n = #node.owner.owned
			node.owner.owned[idx] = node.owner.owned[n]
			node.owner.owned[n] = nil
		end
	end
	if node.owned then
		while node.owned[1] do
			destroyNode(node.owned[1])
		end
	end
	node.owner = nil
end

local function destroyOwned(node: Node)
	if node.owned then
		while node.owned[1] do
			destroyNode(node.owned[1])
		end
	end
end

local function evaluateNode(node: Node)
	if not node.effect then
		return false
	end
	local oldCache = node.cache
	flushCleanups(node)
	destroyOwned(node)
	unsubscribe(node)
	pushScope(node)
	local ok, result = pcall(node.effect, node.cache)
	popScope()
	if ok then
		node.cache = result
		node.dirty = false
	end
	return oldCache ~= node.cache
end

local function queueNode(node: Node)
	if not updateSet[node] then
		updateSet[node] = true
		table.insert(updateQueue, node)
	end
end

local function flushQueue()
	local i = 1
	while i <= #updateQueue do
		local node = updateQueue[i]
		updateSet[node] = nil
		if node.owner and node.dirty then
			if evaluateNode(node) then
				for child in node.deps do
					if child.children then
						for c in child.children do
							if c.effect then
								c.dirty = true
								queueNode(c)
							end
						end
					end
				end
			end
		end
		i += 1
	end
	table.clear(updateQueue)
end

local function notifyChildren(srcNode: SourceNode)
	for child in srcNode.children do
		child.dirty = true
		queueNode(child)
	end
	if not batching then
		flushQueue()
	end
end

local function source<T>(initial: T): Source<T>
	local node: SourceNode = {
		cache = initial,
		children = {},
	}
	local function fn(...): T
		if select("#", ...) == 0 then
			local scope = getCurrentScope()
			if scope then
				node.children[scope] = true
				scope.deps[node] = true
			end
			return node.cache
		end
		local newValue = ... :: T
		if node.cache == newValue and (type(newValue) ~= "table" or table.isfrozen(newValue)) then
			return newValue
		end
		node.cache = newValue
		notifyChildren(node)
		return newValue
	end
	return fn
end

local function root<T>(fn: () -> T): (T, () -> ())
	local node: Node = {
		cache = nil,
		effect = nil,
		deps = {},
		owner = nil,
		owned = nil,
		cleanups = nil,
		dirty = false,
	}
	pushScope(node)
	local result = fn()
	popScope()
	return result, function()
		destroyNode(node)
	end
end

local function effect(fn: () -> ()): () -> ()
	local owner = getCurrentScope()
	local node: Node = {
		cache = nil,
		effect = function()
			fn()
			return nil
		end,
		deps = {},
		owner = owner,
		owned = nil,
		cleanups = nil,
		dirty = true,
	}
	if owner then
		if owner.owned then
			table.insert(owner.owned, node)
		else
			owner.owned = { node }
		end
	end
	evaluateNode(node)
	return function()
		destroyNode(node)
	end
end

local function derive<T>(fn: () -> T): () -> T
	local owner = getCurrentScope()
	local node: Node = {
		cache = nil :: any,
		effect = function()
			return fn()
		end,
		deps = {},
		owner = owner,
		owned = nil,
		cleanups = nil,
		dirty = true,
	}
	if owner then
		if owner.owned then
			table.insert(owner.owned, node)
		else
			owner.owned = { node }
		end
	end
	evaluateNode(node)
	return function(): T
		local scope = getCurrentScope()
		if scope then
			for dep in node.deps do
				dep.children[scope] = true
				scope.deps[dep] = true
			end
		end
		if node.dirty then
			evaluateNode(node)
		end
		return node.cache
	end
end

local function Value<T>(initial: T): State<T>
	local src = source(initial)
	return {
		get = function(self): T
			return src()
		end,
		set = function(self, value: T)
			src(value)
		end,
		update = function(self, fn: (T) -> T)
			src(fn(src()))
		end,
		source = src,
	}
end

local function computed<T>(fn: () -> T): () -> T
	return derive(fn)
end

local function peek<T>(value: (() -> T) | State<T>): T
	local prev = scopeStack[#scopeStack]
	scopeStack[#scopeStack] = nil
	local result: T
	if type(value) == "function" then
		result = (value :: () -> T)()
	else
		result = (value :: State<T>):get()
	end
	if prev then
		scopeStack[#scopeStack + 1] = prev
	end
	return result
end

local function untrack<T>(fn: () -> T): T
	local prev = scopeStack[#scopeStack]
	scopeStack[#scopeStack] = nil
	local result = fn()
	if prev then
		scopeStack[#scopeStack + 1] = prev
	end
	return result
end

local function batch(fn: () -> ())
	batchDepth += 1
	if batchDepth == 1 then
		batching = true
	end
	local ok, err = pcall(fn)
	batchDepth -= 1
	if batchDepth == 0 then
		batching = false
		flushQueue()
	end
	if not ok then
		error(err, 2)
	end
end

local function cleanup(fn: () -> ())
	local scope = getCurrentScope()
	if scope then
		addCleanup(scope, fn)
	end
end

return {
	source = source,
	derive = derive,
	effect = effect,
	Value = Value,
	computed = computed,
	peek = peek,
	untrack = untrack,
	batch = batch,
	root = root,
	cleanup = cleanup,
}
