# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- `effect` and `derive` created outside a `root`/`mount` now re-run when their dependencies change.
- Dependents of a `derive` are now updated when the derive's value changes (previously its siblings were re-marked instead). Updates are glitch-free and skip effects whose derived inputs did not change.
- Errors thrown inside effects, derives and cleanups are reported with a traceback instead of being swallowed.
- `untrack`/`peek` no longer leak tracking into an outer scope and restore the scope if the callback errors.
- Springs are released when their owning scope is cleaned up, stop writing once at rest, and the Heartbeat connection is disconnected when no spring is moving.
- Function children (`[n] = function() ... end`) now destroy instances they created on a previous run and unparent external instances that are no longer returned.

### Changed
- `spring` is now a real damped spring (position and velocity, `period` in seconds, `damping` as damping ratio) integrated at a fixed 240 Hz substep. Supports number, Vector2, Vector3, UDim2, Color3 and CFrame; other types snap.

### Added
- `tests/` with Lune specs for the reactive core and springs (`lune run tests/run.luau`) and a Studio spec for function children.

## [1.0.0] - 2025-01-25

### Added
- Core reactive system: `source`, `derive`, `effect`, `Value`
- Instance creation with `new` and `Children`
- Spring animation system
- Component system with `Establish`
- Full `--!strict` typing support
- `@native` optimizations for performance
- Utility functions: `map`, `compact`
- Advanced reactivity: `peek`, `untrack`, `batch`, `root`, `cleanup`
- Instance utilities: `Parent`, `OnDestroy`, `Ref`, `mount`, `attach`, `apply`

[Unreleased]: https://github.com/veraci-ty/obsidian/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/veraci-ty/obsidian/releases/tag/v1.0.0
