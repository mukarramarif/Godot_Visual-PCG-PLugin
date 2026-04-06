extends SceneTree

func _init():
    var args = OS.get_cmdline_args()
    var json_path = "res://tilesetSquare.json"
    
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
    
    var WFC = load("res://addons/VisualPCG/WaveFuncCollapse.gd")
    var wfc_instance = WFC.new()
    
    var gs = tileset_data.get("grid_size", {})
    var grid_size = Vector3i(
        gs.get("x", 20),
        gs.get("y", 20),
        gs.get("z", 1)
    )
    wfc_instance.grid_size = grid_size
    
    wfc_instance.connect("generation_failed", Callable(self, "_on_failed"))
    wfc_instance.connect("generation_completed", Callable(self, "_on_success"))
    
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
