# VisualPCG Plugin - Development Guide

## Project Overview

**VisualPCG** is a Godot 4.6 editor plugin for procedural content generation using a visual tile/socket system backed by the **Wave Function Collapse (WFC)** algorithm. It allows users to import 3D assets, define socket-based connection rules between tiles, and generate procedural 3D environments directly in the Godot editor.

- **Engine:** Godot 4.6
- **Renderer:** Forward Plus
- **Language:** GDScript
- **Status:** Alpha (v0.1)
- **Author:** Muhammad Arif

---

## Project Structure

```
pcg_plugin/
├── addons/
│   ├── VisualPCG/              # Main plugin code
│   │   ├── plugin.cfg          # Plugin metadata
│   │   ├── plugin_entry.gd     # EditorPlugin bootstrap (206 lines)
│   │   ├── TileSocketEditor.gd # Main editor UI (1066 lines)
│   │   ├── WaveFuncCollapse.gd # Core WFC algorithm (1042 lines)
│   │   ├── HighlighCube.gd     # 3D socket highlight overlay (288 lines)
│   │   ├── PCGNode.gd          # Runtime generation node (37 lines)
│   │   ├── NodeTypes.gd        # Visual scripting stub (13 lines)
│   │   ├── NodeFunctions.gd    # Shared file dialog utility (28 lines)
│   │   ├── CustomEnvNode.gd    # Deprecated graph editor (994 lines, all commented)
│   │   └── PcgEditScene.tscn   # Editor scene file
│   └── wakatime/               # Time tracking addon
├── Assets/                     # External 3D asset packs
├── generated_levels/           # Output WFC-generated scenes
├── player.gd                   # FPS-style player controller
├── player.tscn                 # Player scene
├── world.gd                    # Empty world node
├── world.tscn                  # World scene
├── PCGNode.tscn                # Runtime PCG demo scene (hex tiles)
├── project.godot               # Godot project config
├── tileset*.json               # Various tileset configs
├── wfc_tileset_export.json     # Exported tileset
└── README.md                   # Project readme
```

---

## Architecture

```
plugin_entry.gd (EditorPlugin)
	|
	+-- PcgEditScene.tscn -> TileSocketEditor.gd (Bottom Panel "PCG Visual")
	|       |
	|       +-- 3D Preview (SubViewport + Camera3D + Lights)
	|       +-- Tile Library (ItemList)
	|       +-- Socket Editor (LineEdits per direction)
	|       +-- HighlighCube.gd (Visual socket overlay)
	|       +-- JSON Save/Load
	|
	+-- WaveFunctionCollapse.gd (WFC Engine - child node)
			|
			+-- Grid initialization
			+-- Constraint propagation
			+-- Backtracking
			+-- Error analysis
			+-- Tile instantiation

PCGNode.gd (Runtime node for in-game generation)
```

### Data Flow

1. User imports 3D models (`.glb`, `.gltf`, `.fbx`, `.obj`, `.tscn`) via TileSocketEditor
2. User assigns socket values per tile direction in the editor
3. User clicks "Run WFC" -> `convert_sockets_to_neighbors()` builds adjacency data
4. `WaveFunctionCollapse.run_wfc()` executes the algorithm
5. On success, `plugin_entry.create_level_scene()` instantiates tiles and saves as `res://generated_levels/level_<timestamp>.tscn`
6. Alternatively, `PCGNode` can be placed in any scene for runtime generation

---

## Key Components

### WaveFuncCollapse.gd - WFC Algorithm

- **Grid:** 3D array `[z][y][x]` of cell dictionaries
- **Algorithm:** Entropy-based observation -> weighted random collapse -> queue-based constraint propagation -> backtracking on contradiction
- **Grid types:** Square (6 directions), Hex flat-top (8 directions), Hex pointy-top (8 directions)
- **Backtracking:** Max 3 retries, max 3 backtracks per attempt
- **Error handling:** Detailed error dictionaries with progress, suggestions, and problematic tile analysis

### TileSocketEditor.gd - Editor UI

Three-panel layout:
- **Left:** Tile library (ItemList), Import/Remove buttons
- **Center:** Toolbar (grid settings, save/load, run WFC) + 3D preview viewport
- **Right:** Socket editor (LineEdit per direction), Quick Presets, Weight spinner, Compatible Tiles list

### Socket System

| Format | Meaning |
|--------|---------|
| `-1` | No connection (blocked) |
| `0` | Empty/air (open space) |
| `1S`, `2S` | Symmetric - connects to same value with `S` suffix |
| `1`, `2` | Plain (asymmetric half) - connects to matching `F` |
| `1F`, `2F` | Flipped (asymmetric half) - connects to matching plain |

### JSON Tileset Format

```json
{
  "grid_type": "square",
  "grid_size": {"x": 20, "y": 20, "z": 1},
  "hex_orientation": "pointy",
  "tile_size": 2.0,
  "tile_spacing": 0.0,
  "tiles": {
	"tile_name": {
	  "name": "tile_name",
	  "file_path": "res://path/to/model.glb",
	  "type": "3d",
	  "format": "glb",
	  "weight": 1.0,
	  "sockets": {"north": "1S", "south": "1S", "east": "1S", "west": "1S", "up": "-1", "down": "0"},
	  "neighbors": {"north": [{"tile": "other_tile", "via": "south"}]}
	}
  }
}
```

---

## How I Should Work on This Project

### Code Conventions

- **GDScript** with Godot 4.6 conventions
- Use `@tool` for editor-time scripts
- Use `@export` for inspector-exposed variables
- Use `class_name` for globally accessible classes
- Snake_case for variables/functions, PascalCase for classes
- No comments unless explicitly requested
- Follow existing patterns in the codebase
- Only use gdScript with static typing where it is already used

### Development Approach

1. **Read before editing** - Always read the full file content before making changes
2. **Understand the architecture** - Know how components interact before modifying
3. **Preserve existing patterns** - Match the existing code style and structure
4. **Test in Godot** - Changes should be verifiable by opening the project in Godot 4.6
5. **No documentation files** - Do not create README, docs, or other markdown files unless explicitly asked

### Key Files to Modify

| Task | Primary File(s) |
|------|----------------|
| WFC algorithm changes | `addons/VisualPCG/WaveFuncCollapse.gd` |
| Editor UI changes | `addons/VisualPCG/TileSocketEditor.gd` |
| Plugin lifecycle | `addons/VisualPCG/plugin_entry.gd` |
| Runtime generation | `addons/VisualPCG/PCGNode.gd` |
| 3D highlight visuals | `addons/VisualPCG/HighlighCube.gd` |
| Plugin metadata | `addons/VisualPCG/plugin.cfg` |

### Things to Avoid

- Do not modify `CustomEnvNode.gd` - it is fully deprecated/commented out
- Do not modify `.godot/` directory contents - these are auto-generated
- Do not modify `.import` files - these are auto-generated by Godot
- Do not modify generated level files in `generated_levels/`
- Do not change `config_version` in `project.godot`

### TODO Items (from README)

- [ ] Add more PCG tools like Perlin Noise as options
- [ ] Runtime generation in games

---

## Input Mappings

| Action | Key |
|--------|-----|
| move_forward | W |
| move_backward | S |
| move_left | A |
| move_right | D |
| wave | F |

---

## Git Workflow

- Do not commit unless explicitly asked
- When committing, follow the existing commit message style
- Never commit secrets or credentials
