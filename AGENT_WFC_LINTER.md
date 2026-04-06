# VisualPCG WFC Linter - Agent Guide

This guide provides instructions for an LLM agent to programmatically validate a tileset configuration using the VisualPCG Wave Function Collapse (WFC) engine, read its diagnostic output, and resolve connection errors.

## 1. Overview

The WFC generator (`addons/VisualPCG/WaveFuncCollapse.gd`) includes a highly detailed validation step that runs before grid generation. It checks for:
- Disconnected or isolated tiles (tiles with no valid neighbors).
- Dead ends or unresolvable socket configurations.
- Missing bidirectional compatibility.

When a tileset is invalid, it returns a detailed dictionary containing exact diagnostic information. As an agent, you can use this to iteratively "lint" a `.json` tileset and output a valid solution.

## 2. Running the Linter Headless

To run the WFC engine directly from the command line and read its output, you can create a temporary Godot script (e.g., `linter.gd`) in the project root:

```gdscript
# linter.gd
extends SceneTree

func _init():
    var args = OS.get_cmdline_args()
    var json_path = "res://tilesetSquare.json" # Default or parse from args
    
    var file = FileAccess.open(json_path, FileAccess.READ)
    if not file:
        print("ERROR: Could not open ", json_path)
        quit(1)
        return
        
    var json = JSON.new()
    if json.parse(file.get_as_text()) != OK:
        print("ERROR: Invalid JSON")
        quit(1)
        return
        
    var tileset_data = json.get_data()
    
    # Instantiate the WFC Engine
    var WFC = load("res://addons/VisualPCG/WaveFuncCollapse.gd")
    var wfc_instance = WFC.new()
    
    # Listen for failure to capture the diagnostic dictionary
    wfc_instance.connect("generation_failed", Callable(self, "_on_failed"))
    wfc_instance.connect("generation_completed", Callable(self, "_on_success"))
    
    # Run the generator (which internally triggers the linter first)
    print("Running WFC Linter on ", json_path, "...")
    wfc_instance.run_wfc(tileset_data)

func _on_failed(error_dict: Dictionary):
    print("\n=== LINTER FAILED ===")
    print("MESSAGE: ", error_dict.get("message", ""))
    print("DETAILS:\n", error_dict.get("details", ""))
    
    var suggestions = error_dict.get("suggestions", [])
    if suggestions.size() > 0:
        print("\nSUGGESTIONS:")
        for s in suggestions:
            print(" - ", s)
            
    var prob_tiles = error_dict.get("problematic_tiles", {})
    if prob_tiles.size() > 0:
        print("\nPROBLEMATIC TILES (Conflict Count):")
        for t in prob_tiles:
            print(" - ", t, ": ", prob_tiles[t])
            
    quit(1)

func _on_success(grid):
    print("\n=== LINTER SUCCESS ===")
    print("Tileset is valid and generated successfully!")
    quit(0)
```

**Execution Command:**
Run the script using the Godot executable in headless mode:
```bash
godot --headless -s linter.gd
```

## 3. Interpreting the Output

When the linter fails, it will output the structured `generation_failed` dictionary.

### Key Fields to Analyze:
- **`message`**: High-level summary of the failure (e.g., "Disconnected Tile Graph").
- **`details`**: Specific breakdown of which sockets on which tiles have no matching neighbors.
- **`suggestions`**: Actionable steps to fix the JSON rules.
- **`problematic_tiles`**: A frequency map of tiles that caused contradictions during backtracking.

## 4. Agent Workflow to Fix Tilesets

1. **Read the JSON Configuration:** Load the `tilesetSquare.json` or target tileset file.
2. **Execute the Linter:** Run the headless Godot script described above.
3. **Parse the Error Log:** Identify which tiles are isolated or causing contradictions based on the `DETAILS` and `PROBLEMATIC TILES` stdout.
4. **Analyze Socket Rules:**
   - Remember the socket connection rules:
     - `1S` connects to `1S` (Symmetric).
     - `1` connects to `1F` (Flipped/Asymmetric).
     - `-1` is blocked.
     - `0` is empty/air.
   - Look for tiles that have an asymmetrical socket (e.g., `1`) but no other tile in the library has the matching flipped socket (e.g., `1F`) on the opposite face.
   - For vertical building, ensure `up` and `down` sockets form valid pairs (e.g., Floor's `up: 1` needs a Wall's `down: 1F`).
5. **Patch the JSON:** Update the socket values for the problematic tiles.
6. **Re-Run:** Repeat steps 2-5 until the linter outputs `=== LINTER SUCCESS ===`.