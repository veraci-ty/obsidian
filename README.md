<div align="center">
  <img src="logo.png" alt="Obsidian Logo" width="200">
  
  # Obsidian
  
  A lightweight, strictly-typed reactive UI library for Roblox that combines the best of Fusion and Vide. Zero dependencies. Performant.
</div>

## Features

- **Reactive System**: Automatic dependency tracking with fine-grained updates
- **Strict Typing**: Full `--!strict` support with complete type safety
- **Spring Animations**: Built-in spring physics for smooth, natural animations
- **Component System**: Reusable components with the `Establish` pattern
- **Zero Dependencies**: Standalone library, just drop it in and start building
- **Performance**: Native-optimized functions with `@native` annotations

## Installation

### Wally (Recommended)

Add to your `wally.toml`:

```toml
[dependencies]
Obsidian = "veraci-ty/obsidian@1.0.0"
```

Then run:
```bash
wally install
```

### Rojo

1. Download the latest release from [GitHub Releases](https://github.com/veraci-ty/obsidian/releases)
2. Extract the `Obsidian` folder
3. Place it in your `src/ReplicatedStorage/Packages/` directory
4. Add to your `default.project.json`:

```json
{
  "name": "project",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Packages": {
        "$className": "Folder",
        "Obsidian": {
          "$path": "src/ReplicatedStorage/Packages/Obsidian"
        }
      }
    }
  }
}
```

### Roblox Studio

1. Download the `.rbxm` file from [GitHub Releases](https://github.com/veraci-ty/obsidian/releases)
2. Import into Roblox Studio
3. Place in `ReplicatedStorage.Packages`

## Quick Start

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Obsidian = require(ReplicatedStorage.Packages.Obsidian)
local Players = game:GetService("Players")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Parent = playerGui

Obsidian.attach(function()
    return Obsidian.new "Frame" {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(15, 17, 22),
        [Obsidian.Children] = {
            Obsidian.new "TextLabel" {
                Size = UDim2.fromScale(1, 1),
                Text = "Hello, Obsidian!",
                TextColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 1,
            },
        },
    }
end, screenGui)
```

## Documentation

Full documentation is available at: [https://obsidian-ui.github.io](https://obsidian-ui.github.io)

### Core Concepts

**Reactive Sources**
```lua
local count = Obsidian.source(0)
print(count())  --> 0
count(5)
print(count())  --> 5
```

**Derived Values**
```lua
local count = Obsidian.source(0)
local doubled = Obsidian.derive(function()
    return count() * 2
end)
```

**Effects**
```lua
local name = Obsidian.source("World")
Obsidian.effect(function()
    print("Hello, " .. name() .. "!")
end)
```

**Spring Animations**
```lua
local pos = Obsidian.source(0)
local smooth = Obsidian.spring(pos, 0.4, 0.8)

Obsidian.new "Frame" {
    Position = function()
        return UDim2.fromOffset(smooth(), 0)
    end,
}
```

**Components**
```lua
Obsidian:Establish("Button", function(props)
    return Obsidian.new "TextButton" {
        Size = UDim2.fromOffset(160, 44),
        Text = props.Text or "Button",
        Activated = props.OnClick,
    }
end)

Obsidian.new "Button" { Text = "Click Me" }
```

## API Reference

### Reactivity

- `source(initial)` - Create a reactive source
- `derive(fn)` - Create a derived reactive value
- `computed(fn)` - Alias for `derive`
- `effect(fn)` - Run side effects on change
- `Value(initial)` - State object with `get`, `set`, `update` methods
- `spring(input, period?, damping?)` - Smooth spring animations
- `peek(value)` - Read without tracking
- `untrack(fn)` - Execute without tracking dependencies
- `batch(fn)` - Batch reactive updates
- `root(fn)` - Create reactive root with manual cleanup
- `cleanup(fn)` - Register cleanup function

### Instances

- `new "ClassName" { ... }` - Create instances with reactive properties
- `Children` - Special key for nesting child instances
- `Parent` - Reactive parent property
- `OnDestroy` - Cleanup callbacks
- `Ref` - Reference callbacks
- `mount(render, parent)` - Mount UI to parent
- `attach(render, parent)` - Alias for `mount`
- `apply(instance)` - Apply props to existing instance

### Components

- `Establish(name, factory)` - Register reusable components

### Utilities

- `map(list, fn)` - Map over a list
- `compact(list)` - Remove nil values

## Requirements

- Roblox Studio or Roblox runtime
- Luau (Roblox's Lua variant)

## License

MIT License - see [LICENSE](LICENSE) file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Links

- **Documentation**: [https://obsidian-ui.github.io](https://obsidian-ui.github.io)
- **Wally Package**: `veraci-ty/obsidian`
- **Issues**: [GitHub Issues](https://github.com/veraci-ty/obsidian/issues)

## Acknowledgments

Obsidian takes inspiration from:
- [Fusion](https://github.com/Elttob/Fusion) - Excellent reactive framework
- [Vide](https://github.com/centau/vide) - Elegant UI syntax
