--!strict

local Reactive = require "./Reactive"
local Instance = require "./Instance"
local Spring = require "./Spring"
local Util = require "./Util"

export type Source<T> = Reactive.Source<T>
export type State<T> = Reactive.State<T>
export type Factory = (props: { [any]: any }) -> Instance

local Obsidian = {
	Source = (nil :: any) :: Source<any>,
	State = (nil :: any) :: State<any>,
	source = Reactive.source,
	derive = Reactive.derive,
	effect = Reactive.effect,
	computed = Reactive.computed,
	Value = Reactive.Value,
	peek = Reactive.peek,
	untrack = Reactive.untrack,
	batch = Reactive.batch,
	root = Reactive.root,
	cleanup = Reactive.cleanup,
	New = Instance.New,
	new = Instance.new,
	Children = Instance.Children,
	Parent = Instance.Parent,
	OnDestroy = Instance.OnDestroy,
	Ref = Instance.Ref,
	mount = Instance.mount,
	attach = Instance.attach,
	apply = Instance.apply,
	spring = Spring.spring,
	map = Util.map,
	compact = Util.compact,
}

function Obsidian:Establish(name: string, factory: Factory)
	return Instance.establish(name, factory)
end

return Obsidian
