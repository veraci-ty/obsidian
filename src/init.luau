--!strict

local obsidian = require(script.core)

export type Source<T> = obsidian.Source<T>
export type State<T> = obsidian.State<T>
export type Factory = obsidian.Factory

return table.freeze(obsidian)
