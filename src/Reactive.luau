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
	derived: boolean,
	deps: { [Node]: boolean },
	children: { [Node]: boolean },
	owner: Node?,
	owned: { Node }?,
	cleanups: { () -> () }?,
	state: number,
	destroyed: boolean,
}

local CLEAN = 0
local CHECK = 1
local DIRTY = 2

local scopeStack: { Node } = {}
local updateQueue: { Node } = {}
local updateSet: { [Node]: boolean } = {}
local batchDepth = 0
local flushing = false

local function report(err: any)
	task.spawn(error, err, 0)
end

local function traceback(err: any): string
	return debug.traceback(tostring(err), 2)
end

local function getCurrentScope(): Node?
	return scopeStack[#scopeStack]
end

local function pushScope(node: Node)
	table.insert(scopeStack, node)
end

local function popScope()
	table.remove(scopeStack)
end

local function newNode(owner: Node?, effect: ((any) -> any)?, derived: boolean): Node
	local node: Node = {
		cache = nil,
		effect = effect,
		derived = derived,
		deps = {},
		children = {},
		owner = owner,
		owned = nil,
		cleanups = nil,
		state = CLEAN,
		destroyed = false,
	}
	if owner then
		local owned = owner.owned
		if owned then
			table.insert(owned, node)
		else
			owner.owned = { node }
		end
	end
	return node
end

local function subscribe(scope: Node, dep: Node)
	dep.children[scope] = true
	scope.deps[dep] = true
end

local function addCleanup(node: Node, fn: () -> ())
	local cleanups = node.cleanups
	if cleanups then
		table.insert(cleanups, fn)
	else
		node.cleanups = { fn }
	end
end

local function flushCleanups(node: Node)
	local cleanups = node.cleanups
	if cleanups then
		node.cleanups = nil
		for _, fn in cleanups do
			local ok, err = xpcall(fn :: () -> ...any, traceback)
			if not ok then
				report(err)
			end
		end
	end
end

local function unsubscribe(node: Node)
	for dep in node.deps do
		dep.children[node] = nil
	end
	table.clear(node.deps)
end

local destroyNode: (Node) -> ()

local function destroyOwned(node: Node)
	local owned = node.owned
	if owned then
		while owned[1] do
			destroyNode(owned[1])
		end
	end
end

destroyNode = function(node: Node)
	if node.destroyed then
		return
	end
	node.destroyed = true
	node.state = CLEAN
	destroyOwned(node)
	flushCleanups(node)
	unsubscribe(node)
	table.clear(node.children)
	local owner = node.owner
	local list = if owner then owner.owned else nil
	if list then
		local idx = table.find(list, node)
		if idx then
			local n = #list
			list[idx] = list[n]
			list[n] = nil
		end
	end
	node.owner = nil
end

local function queueNode(node: Node)
	if not updateSet[node] then
		updateSet[node] = true
		table.insert(updateQueue, node)
	end
end

local function markChildren(node: Node, state: number)
	for child in node.children do
		if child.state < state then
			local previous = child.state
			child.state = state
			if child.derived then
				if previous == CLEAN then
					markChildren(child, CHECK)
				end
			else
				queueNode(child)
			end
		end
	end
end

local function hasChanged(old: any, new: any): boolean
	return old ~= new or (type(new) == "table" and not table.isfrozen(new))
end

local function evaluateNode(node: Node)
	local fn = node.effect
	if not fn or node.destroyed then
		return
	end
	local oldCache = node.cache
	destroyOwned(node)
	flushCleanups(node)
	unsubscribe(node)
	pushScope(node)
	local ok, result = xpcall(fn, traceback, oldCache)
	popScope()
	node.state = CLEAN
	if not ok then
		report(result)
		return
	end
	node.cache = result
	if node.derived and hasChanged(oldCache, result) then
		for child in node.children do
			child.state = DIRTY
		end
	end
end

local function updateNode(node: Node)
	if node.destroyed then
		return
	end
	if node.state == CHECK then
		for dep in node.deps do
			if dep.derived then
				updateNode(dep)
				if node.state == DIRTY then
					break
				end
			end
		end
	end
	if node.state == DIRTY then
		evaluateNode(node)
	end
	node.state = CLEAN
end

local function flushQueue()
	if flushing or batchDepth > 0 then
		return
	end
	flushing = true
	local i = 1
	while i <= #updateQueue do
		local node = updateQueue[i]
		updateSet[node] = nil
		if not node.destroyed and node.state ~= CLEAN then
			updateNode(node)
		end
		i += 1
	end
	table.clear(updateQueue)
	flushing = false
end

local function source<T>(initial: T): Source<T>
	local node = newNode(nil, nil, false)
	node.cache = initial
	local function fn(...: T): T
		if select("#", ...) == 0 then
			local scope = getCurrentScope()
			if scope then
				subscribe(scope, node)
			end
			return node.cache
		end
		local newValue = ...
		if not hasChanged(node.cache, newValue) then
			return newValue
		end
		node.cache = newValue
		markChildren(node, DIRTY)
		flushQueue()
		return newValue
	end
	return fn :: any
end

local function root<T>(fn: () -> T): (T, () -> ())
	local node = newNode(nil, nil, false)
	pushScope(node)
	local ok, result = xpcall(fn, traceback)
	popScope()
	local function dispose()
		destroyNode(node)
	end
	if not ok then
		dispose()
		error(result, 0)
	end
	return result, dispose
end

local function effect(fn: () -> ()): () -> ()
	local node = newNode(getCurrentScope(), function(): any
		fn()
		return nil
	end, false)
	evaluateNode(node)
	return function()
		destroyNode(node)
	end
end

local function derive<T>(fn: () -> T): () -> T
	local node = newNode(getCurrentScope(), function(): any
		return fn()
	end, true)
	evaluateNode(node)
	return function(): T
		updateNode(node)
		local scope = getCurrentScope()
		if scope and not node.destroyed then
			subscribe(scope, node)
		end
		return node.cache
	end
end

local function Value<T>(initial: T): State<T>
	local src = source(initial)
	return {
		get = function(self: State<T>): T
			return src()
		end,
		set = function(self: State<T>, value: T)
			src(value)
		end,
		update = function(self: State<T>, fn: (T) -> T)
			src(fn(src()))
		end,
		source = src,
	}
end

local function computed<T>(fn: () -> T): () -> T
	return derive(fn)
end

local function untrack<T>(fn: () -> T): T
	local saved = scopeStack
	scopeStack = {}
	local ok, result = xpcall(fn, traceback)
	scopeStack = saved
	if not ok then
		error(result, 0)
	end
	return result
end

local function peek<T>(value: (() -> T) | State<T>): T
	if type(value) == "function" then
		return untrack(value :: () -> T)
	end
	local state = value :: State<T>
	return untrack(function(): T
		return state:get()
	end)
end

local function batch(fn: () -> ())
	batchDepth += 1
	local ok, err = xpcall(fn :: () -> ...any, traceback)
	batchDepth -= 1
	flushQueue()
	if not ok then
		error(err, 0)
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
