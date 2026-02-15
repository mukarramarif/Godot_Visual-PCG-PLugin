extends Node

class_name WaveFunctionCollapse

var tileset_data: Dictionary = {}
var grid: Array = []
var grid_size: Vector3i = Vector3i(20, 20, 3)
var tile_templates: Dictionary = {}
var grid_type: String = "square"  # "square" or "hex"
var hex_orientation: String = "flat"  # "flat" or "pointy"
var tile_size: float = 2.0
var tile_spacing: float = 0.0  # Gap between tiles

# Error tracking
var last_error: Dictionary = {}
var contradiction_history: Array = []
var problematic_tiles: Dictionary = {}  # tile_name -> count of issues

signal generation_completed(grid_res: Array)
signal generation_failed(error: Dictionary)

const HEX_FLAT_DIRECTIONS = ["ne", "e", "se", "sw", "w", "nw", "up", "down"]
const HEX_POINTY_DIRECTIONS = ["ne", "e", "se", "sw", "w", "nw", "up", "down"]
const SQUARE_DIRECTIONS = ["north", "south", "east", "west", "up", "down"]

## Error types
enum ErrorType {
	NONE,
	INVALID_TILESET,
	NO_TILES,
	NO_CONNECTIONS,
	CONTRADICTION,
	MAX_ITERATIONS,
	ISOLATED_TILE,
	IMPOSSIBLE_CONSTRAINT
}

func run_wfc(tileset: Dictionary):
	print("=== Starting WFC Generation ===")

	# Reset error tracking
	last_error = {}
	contradiction_history = []
	problematic_tiles = {}

	tileset_data = tileset
	grid_type = tileset.get("grid_type", "square")
	tile_size = tileset.get("tile_size", 2.0)
	tile_spacing = tileset.get("tile_spacing", 0.0)

	# Auto-detect hex orientation from socket directions if not specified
	if tileset.has("hex_orientation"):
		hex_orientation = tileset.get("hex_orientation")
	elif grid_type == "hex":
		hex_orientation = detect_hex_orientation_from_sockets()
	else:
		hex_orientation = "flat"

	print("Grid type: %s, Hex orientation: %s" % [grid_type, hex_orientation])

	# Validate tileset with detailed errors
	var validation = validate_tileset_detailed()
	if not validation["valid"]:
		emit_signal("generation_failed", validation)
		return null

	prepare_tiles()
	init_grid(grid_size)

	var result = collapse_grid_with_diagnostics()

	if result["success"]:
		print("WFC Generation completed successfully!")
		print_grid()
		emit_signal("generation_completed", grid)
		return grid
	else:
		emit_signal("generation_failed", result)
		return null

## Detailed tileset validation
func validate_tileset_detailed() -> Dictionary:
	var result = {
		"valid": true,
		"error_type": ErrorType.NONE,
		"message": "",
		"details": "",
		"suggestions": []
	}

	# Check if tiles exist
	if not tileset_data.has("tiles"):
		result["valid"] = false
		result["error_type"] = ErrorType.INVALID_TILESET
		result["message"] = "Invalid Tileset Structure"
		result["details"] = "The tileset data is missing the 'tiles' key."
		result["suggestions"] = [
			"Make sure you've imported at least one tile",
			"Try saving and reloading the tileset"
		]
		return result

	if tileset_data["tiles"].size() == 0:
		result["valid"] = false
		result["error_type"] = ErrorType.NO_TILES
		result["message"] = "No Tiles in Tileset"
		result["details"] = "The tileset contains no tiles to work with."
		result["suggestions"] = [
			"Import some 3D models using the 'Import Tiles' button",
			"Load an existing tileset with the 'Load' button"
		]
		return result

	# Check socket connections
	var tiles_without_connections = []
	var orphan_tiles = []  # Tiles that can't connect to anything
	var directions = get_current_directions()

	for tile_name in tileset_data["tiles"]:
		var tile = tileset_data["tiles"][tile_name]
		var sockets = tile.get("sockets", {})
		var neighbors = tile.get("neighbors", {})

		var has_any_connection = false
		var connection_counts = {}

		for direction in directions:
			var socket = sockets.get(direction, "-1")
			var neighbor_list = neighbors.get(direction, [])

			if socket != "-1" and not socket.is_empty():
				has_any_connection = true

			connection_counts[direction] = neighbor_list.size()

		if not has_any_connection:
			tiles_without_connections.append(tile_name)

		# Check if tile can actually connect to other tiles
		var total_connections = 0
		for dir in connection_counts:
			total_connections += connection_counts[dir]

		if total_connections == 0 and has_any_connection:
			orphan_tiles.append(tile_name)

	if tiles_without_connections.size() == tileset_data["tiles"].size():
		result["valid"] = false
		result["error_type"] = ErrorType.NO_CONNECTIONS
		result["message"] = "No Socket Connections Defined"
		result["details"] = "None of the tiles have any socket connections defined. All sockets are set to -1 (invalid)."
		result["suggestions"] = [
			"Select each tile and set socket values (e.g., '1S' for symmetric connections)",
			"Use the 'Quick Presets' to apply common socket patterns",
			"Tiles need matching sockets to connect: '1S' connects to '1S', '1' connects to '1F'"
		]
		return result

	if orphan_tiles.size() > 0:
		result["valid"] = false
		result["error_type"] = ErrorType.ISOLATED_TILE
		result["message"] = "Isolated Tiles Detected"
		result["details"] = "These tiles have sockets but cannot connect to any other tile:\n• " + "\n• ".join(orphan_tiles)
		result["suggestions"] = [
			"Check that socket IDs match between tiles",
			"Remember: '1S' connects to '1S', but '1' only connects to '1F'",
			"Make sure opposing faces have compatible sockets"
		]
		return result

	if tiles_without_connections.size() > 0:
		# Warning but allow
		print("Warning: Some tiles have no connections: ", tiles_without_connections)

	return result

func get_current_directions() -> Array:
	if grid_type == "hex":
		if hex_orientation == "flat":
			return HEX_FLAT_DIRECTIONS
		else:
			return HEX_POINTY_DIRECTIONS
	return SQUARE_DIRECTIONS

## Auto-detect hex orientation by checking which socket directions are used
func detect_hex_orientation_from_sockets() -> String:
	if not tileset_data.has("tiles"):
		return "flat"

	var has_e_w = false  # Pointy-top uses e/w
	var has_n_s = false  # Flat-top uses n/s

	for tile_name in tileset_data["tiles"]:
		var tile = tileset_data["tiles"][tile_name]
		var sockets = tile.get("sockets", {})

		for direction in sockets.keys():
			if direction == "e" or direction == "w":
				has_e_w = true
			if direction == "n" or direction == "s":
				has_n_s = true

	# Determine orientation based on which directions are present
	if has_e_w and not has_n_s:
		print("Auto-detected hex orientation: pointy (found e/w sockets)")
		return "pointy"
	elif has_n_s and not has_e_w:
		print("Auto-detected hex orientation: flat (found n/s sockets)")
		return "flat"
	elif has_e_w and has_n_s:
		# Has both - could be mixed, default to pointy since it's more common
		print("Warning: Tileset has both e/w and n/s sockets. Defaulting to pointy-top.")
		return "pointy"
	else:
		# Neither - default to pointy which uses ne/nw/se/sw/e/w
		print("Auto-detected hex orientation: pointy (default)")
		return "pointy"

func prepare_tiles():
	tile_templates.clear()
	for tile_id in tileset_data["tiles"]:
		var tile_data = tileset_data["tiles"][tile_id]
		tile_templates[tile_data["name"]] = {
			"id": tile_id,
			"name": tile_data["name"],
			"type": tile_data.get("type", "3d"),
			"weight": tile_data.get("weight", 1.0),
			"neighbors": tile_data.get("neighbors", {}),
			"sockets": tile_data.get("sockets", {}),
			"file_path": tile_data.get("file_path", "")
		}
	print("Prepared %d tile templates" % tile_templates.size())

func init_grid(size: Vector3i):
	var effective_z = max(1, size.z)
	grid_size = Vector3i(size.x, size.y, effective_z)
	grid.clear()

	var all_tiles = tile_templates.keys()

	for z in range(effective_z):
		var layer = []
		for y in range(size.y):
			var row = []
			for x in range(size.x):
				row.append({
					"position": Vector3i(x, y, z),
					"collapsed": false,
					"possible_tiles": all_tiles.duplicate(),
					"tile": null,
					"collapse_history": []  # Track what happened here
				})
			layer.append(row)
		grid.append(layer)
	print("Grid initialized: %dx%dx%d (%s)" % [grid_size.x, grid_size.y, grid_size.z, grid_type])

## Main collapse with full diagnostics
func collapse_grid_with_diagnostics() -> Dictionary:
	var iterations = 0
	var total_cells = grid_size.x * grid_size.y * grid_size.z
	var max_iterations = total_cells * 10

	while not is_grid_fully_collapsed():
		iterations += 1

		if iterations > max_iterations:
			return create_error(
				ErrorType.MAX_ITERATIONS,
				"Maximum Iterations Exceeded",
				"The algorithm ran for %d iterations without completing. This usually indicates a problem with the tileset." % iterations,
				[
					"Reduce the grid size and try again",
					"Check that tiles have enough connection variety",
					"Add more tiles with different socket configurations"
				]
			)

		var cell = find_lowest_entropy_cell()

		if cell == null:
			# Contradiction found
			return analyze_contradiction()

		if cell["possible_tiles"].size() == 0:
			# Should not happen, but safety check
			return analyze_contradiction_at_cell(cell)

		# Collapse the cell
		if not collapse_cell(cell):
			return analyze_contradiction_at_cell(cell)

		# Record what tile was placed
		cell["collapse_history"].append(cell["tile"])

		# Propagate and check for contradictions
		var propagation_result = propagate_with_tracking(cell)
		if not propagation_result["success"]:
			return propagation_result

		# Progress update
		if iterations % 50 == 0:
			var progress = get_collapse_progress() * 100
			print("Progress: %.1f%% (%d/%d cells)" % [progress, get_collapsed_count(), total_cells])

	return {"success": true}

## Propagate constraints with detailed tracking
func propagate_with_tracking(start_cell: Dictionary) -> Dictionary:
	var queue = [start_cell]
	var processed = {}

	while queue.size() > 0:
		var curr = queue.pop_front()
		var pos = curr["position"]
		var key = "%d,%d,%d" % [pos.x, pos.y, pos.z]

		if processed.has(key):
			continue
		processed[key] = true

		if not curr["collapsed"]:
			continue

		for neighbor_data in get_neighbors(pos):
			var neighbor_cell = neighbor_data["cell"]
			var direction = neighbor_data["direction"]

			if neighbor_cell["collapsed"]:
				continue

			var allowed = get_allowed_tiles(curr["tile"], direction)
			var old_possibilities = neighbor_cell["possible_tiles"].duplicate()
			var new_possibilities = []

			for possible in neighbor_cell["possible_tiles"]:
				if possible in allowed:
					new_possibilities.append(possible)

			if new_possibilities.size() == 0 and old_possibilities.size() > 0:
				# Contradiction!
				var neighbor_pos = neighbor_cell["position"]

				# Track problematic tiles
				if not problematic_tiles.has(curr["tile"]):
					problematic_tiles[curr["tile"]] = 0
				problematic_tiles[curr["tile"]] += 1

				contradiction_history.append({
					"collapsed_tile": curr["tile"],
					"collapsed_pos": pos,
					"failed_pos": neighbor_pos,
					"direction": direction,
					"was_possible": old_possibilities,
					"allowed_by_collapsed": allowed
				})

				return analyze_contradiction_detailed(curr, neighbor_cell, direction, old_possibilities, allowed)

			if new_possibilities.size() < old_possibilities.size():
				neighbor_cell["possible_tiles"] = new_possibilities
				queue.append(neighbor_cell)

	return {"success": true}

## Analyze why a contradiction occurred
func analyze_contradiction() -> Dictionary:
	# Find the cell that has no possibilities
	var problem_cell = null

	for layer in grid:
		for row in layer:
			for cell in row:
				if not cell["collapsed"] and cell["possible_tiles"].size() == 0:
					problem_cell = cell
					break

	if problem_cell == null:
		return create_error(
			ErrorType.CONTRADICTION,
			"Contradiction Detected",
			"A cell reached zero possible tiles, but the specific cell could not be identified.",
			[
				"Try regenerating - WFC has some randomness",
				"Add more tile variety to your tileset",
				"Check that all socket connections are bidirectional"
			]
		)

	return analyze_contradiction_at_cell(problem_cell)

func analyze_contradiction_at_cell(cell: Dictionary) -> Dictionary:
	var pos = cell["position"]
	var neighbors = get_neighbors(pos)

	var neighbor_info = []
	var constraining_tiles = []

	for n in neighbors:
		var n_cell = n["cell"]
		var dir = n["direction"]

		if n_cell["collapsed"]:
			var allowed = get_allowed_tiles(n_cell["tile"], get_opposite_direction(dir))
			neighbor_info.append("• %s: '%s' (allows: %s)" % [
				dir.to_upper(),
				n_cell["tile"],
				", ".join(allowed) if allowed.size() > 0 else "nothing!"
			])
			constraining_tiles.append(n_cell["tile"])

	var details = "Cell at position (%d, %d, %d) has no valid tiles.\n\n" % [pos.x, pos.y, pos.z]
	details += "Neighboring collapsed tiles:\n"
	details += "\n".join(neighbor_info) if neighbor_info.size() > 0 else "(none)"

	var suggestions = [
		"The neighboring tiles don't have a common tile they all allow",
		"Try adding a 'universal' tile that can connect to everything (all sockets = '0')",
	]

	if constraining_tiles.size() > 0:
		suggestions.append("Review socket settings for: " + ", ".join(constraining_tiles))

	# Find most problematic tile
	if problematic_tiles.size() > 0:
		var worst_tile = ""
		var worst_count = 0
		for t in problematic_tiles:
			if problematic_tiles[t] > worst_count:
				worst_count = problematic_tiles[t]
				worst_tile = t
		suggestions.append("Tile '%s' caused %d conflicts - check its sockets" % [worst_tile, worst_count])

	return create_error(
		ErrorType.CONTRADICTION,
		"Contradiction: No Valid Tile",
		details,
		suggestions
	)

func analyze_contradiction_detailed(collapsed_cell: Dictionary, failed_cell: Dictionary, direction: String, was_possible: Array, allowed: Array) -> Dictionary:
	var collapsed_pos = collapsed_cell["position"]
	var failed_pos = failed_cell["position"]
	var collapsed_tile = collapsed_cell["tile"]

	var details = "Placing '%s' at (%d,%d,%d) made position (%d,%d,%d) unsolvable.\n\n" % [
		collapsed_tile,
		collapsed_pos.x, collapsed_pos.y, collapsed_pos.z,
		failed_pos.x, failed_pos.y, failed_pos.z
	]

	details += "Direction: %s → %s\n\n" % [direction.to_upper(), get_opposite_direction(direction).to_upper()]

	details += "Tiles that WERE possible: %s\n\n" % [", ".join(was_possible)]
	details += "Tiles that '%s' allows in %s direction: %s\n" % [
		collapsed_tile,
		direction.to_upper(),
		", ".join(allowed) if allowed.size() > 0 else "NONE"
	]

	var suggestions = []

	if allowed.size() == 0:
		suggestions.append("Tile '%s' has no connections defined for %s direction" % [collapsed_tile, direction.to_upper()])
		suggestions.append("Set a socket value for '%s' → %s (currently -1 or empty)" % [collapsed_tile, direction.to_upper()])
	else:
		var missing = []
		for tile in was_possible:
			if tile not in allowed:
				missing.append(tile)
		if missing.size() > 0 and missing.size() <= 3:
			suggestions.append("Consider adding connections from '%s' to: %s" % [collapsed_tile, ", ".join(missing)])

		suggestions.append("Add more tiles that can connect to '%s' from the %s" % [collapsed_tile, get_opposite_direction(direction).to_upper()])

	suggestions.append("Try a smaller grid size to reduce constraint complexity")
	suggestions.append("Add a 'wildcard' tile with symmetric sockets (e.g., all sides = '0')")

	return create_error(
		ErrorType.CONTRADICTION,
		"Contradiction During Propagation",
		details,
		suggestions
	)

func create_error(type: ErrorType, message: String, details: String, suggestions: Array) -> Dictionary:
	last_error = {
		"success": false,
		"error_type": type,
		"message": message,
		"details": details,
		"suggestions": suggestions,
		"progress": get_collapse_progress(),
		"collapsed_count": get_collapsed_count(),
		"total_cells": grid_size.x * grid_size.y * grid_size.z,
		"problematic_tiles": problematic_tiles.duplicate()
	}
	return last_error

func get_neighbors(pos: Vector3i) -> Array:
	var neighbors = []

	if grid_type == "hex":
		neighbors = get_hex_neighbors(pos)
	else:
		neighbors = get_square_neighbors(pos)

	# Vertical neighbors (same for both)
	if pos.z > 0:
		neighbors.append({"cell": grid[pos.z - 1][pos.y][pos.x], "direction": "down"})
	if pos.z < grid_size.z - 1:
		neighbors.append({"cell": grid[pos.z + 1][pos.y][pos.x], "direction": "up"})

	return neighbors

func get_square_neighbors(pos: Vector3i) -> Array:
	var neighbors = []
	if pos.y > 0:
		neighbors.append({"cell": grid[pos.z][pos.y - 1][pos.x], "direction": "north"})
	if pos.y < grid_size.y - 1:
		neighbors.append({"cell": grid[pos.z][pos.y + 1][pos.x], "direction": "south"})
	if pos.x > 0:
		neighbors.append({"cell": grid[pos.z][pos.y][pos.x - 1], "direction": "west"})
	if pos.x < grid_size.x - 1:
		neighbors.append({"cell": grid[pos.z][pos.y][pos.x + 1], "direction": "east"})
	return neighbors

func get_hex_neighbors(pos: Vector3i) -> Array:
	var neighbors = []
	var x = pos.x
	var y = pos.y
	var z = pos.z

	if hex_orientation == "flat":
		return get_flat_hex_neighbors(pos)
	else:
		return get_pointy_hex_neighbors(pos)

func get_flat_hex_neighbors(pos: Vector3i) -> Array:
	var neighbors = []
	var x = pos.x
	var y = pos.y
	var z = pos.z

	# Flat-top hex: offset by ROW (y), odd rows shifted right
	var is_odd_row = (y % 2) == 1

	var offsets: Array
	if is_odd_row:
		# Odd rows: shifted right
		offsets = [
			{"dx": 0, "dy": -1, "dir": "nw"},   # NW: up
			{"dx": 1, "dy": -1, "dir": "ne"},   # NE: up-right
			{"dx": 1, "dy": 0, "dir": "e"},     # E: right
			{"dx": 0, "dy": 1, "dir": "se"},    # SE: down
			{"dx": -1, "dy": 0, "dir": "w"},    # W: left
			{"dx": -1, "dy": -1, "dir": "sw"},  # SW: up-left
		]
	else:
		# Even rows: not shifted
		offsets = [
			{"dx": -1, "dy": -1, "dir": "nw"},  # NW: up-left
			{"dx": 0, "dy": -1, "dir": "ne"},   # NE: up
			{"dx": 1, "dy": 0, "dir": "e"},     # E: right
			{"dx": 0, "dy": 1, "dir": "se"},    # SE: down
			{"dx": -1, "dy": 1, "dir": "sw"},   # SW: down-left
			{"dx": -1, "dy": 0, "dir": "w"},    # W: left
		]

	for offset in offsets:
		var nx = x + offset["dx"]
		var ny = y + offset["dy"]
		if nx >= 0 and nx < grid_size.x and ny >= 0 and ny < grid_size.y:
			neighbors.append({"cell": grid[z][ny][nx], "direction": offset["dir"]})

	return neighbors

func get_pointy_hex_neighbors(pos: Vector3i) -> Array:
	var neighbors = []
	var x = pos.x
	var y = pos.y
	var z = pos.z

	# Pointy-top hex: offset coordinates (odd-q)
	var is_odd_col = (x % 2) == 1

	var offsets: Array
	if is_odd_col:
		offsets = [
			{"dx": 1, "dy": 0, "dir": "e"},
			{"dx": -1, "dy": 0, "dir": "w"},
			{"dx": 0, "dy": -1, "dir": "nw"},
			{"dx": 1, "dy": -1, "dir": "ne"},
			{"dx": 0, "dy": 1, "dir": "sw"},
			{"dx": 1, "dy": 1, "dir": "se"},
		]
	else:
		offsets = [
			{"dx": 1, "dy": 0, "dir": "e"},
			{"dx": -1, "dy": 0, "dir": "w"},
			{"dx": -1, "dy": -1, "dir": "nw"},
			{"dx": 0, "dy": -1, "dir": "ne"},
			{"dx": -1, "dy": 1, "dir": "sw"},
			{"dx": 0, "dy": 1, "dir": "se"},
		]

	for offset in offsets:
		var nx = x + offset["dx"]
		var ny = y + offset["dy"]
		if nx >= 0 and nx < grid_size.x and ny >= 0 and ny < grid_size.y:
			neighbors.append({"cell": grid[z][ny][nx], "direction": offset["dir"]})

	return neighbors

func get_opposite_direction(direction: String) -> String:
	match direction:
		# Square grid
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
		# Flat-top hex (n, ne, se, s, sw, nw)
		"n": return "s"
		"s": return "n"
		"ne": return "sw"
		"sw": return "ne"
		"se": return "nw"
		"nw": return "se"
		# Pointy-top hex (ne, e, se, sw, w, nw)
		"e": return "w"
		"w": return "e"
		# Vertical
		"up": return "down"
		"down": return "up"
	return direction

func find_lowest_entropy_cell():
	var min_entropy = INF
	var candidates = []
	for layer in grid:
		for row in layer:
			for cell in row:
				if cell["collapsed"]:
					continue
				var entropy = cell["possible_tiles"].size()
				if entropy == 0:
					return null
				if entropy < min_entropy:
					min_entropy = entropy
					candidates.clear()
					candidates.append(cell)
				elif entropy == min_entropy:
					candidates.append(cell)
	if candidates.size() > 0:
		return candidates[randi() % candidates.size()]
	return null

func collapse_cell(cell: Dictionary) -> bool:
	if cell["possible_tiles"].size() == 0:
		return false
	var chosen = select_weighted_tile(cell["possible_tiles"])
	cell["tile"] = chosen
	cell["collapsed"] = true
	cell["possible_tiles"] = [chosen]
	return true

func select_weighted_tile(possibilities: Array) -> String:
	var total_weight = 0.0
	for tile_name in possibilities:
		if tile_templates.has(tile_name):
			total_weight += tile_templates[tile_name]["weight"]
	var random_value = randf() * total_weight
	var cumulative = 0.0
	for tile_name in possibilities:
		if tile_templates.has(tile_name):
			cumulative += tile_templates[tile_name]["weight"]
			if random_value <= cumulative:
				return tile_name
	return possibilities[0]

func get_allowed_tiles(tile_name: String, direction: String) -> Array:
	if not tile_templates.has(tile_name):
		return []
	var neighbors = tile_templates[tile_name]["neighbors"].get(direction, [])
	var allowed = []
	for conn in neighbors:
		if conn is Dictionary:
			allowed.append(conn["tile"])
		else:
			allowed.append(conn)
	return allowed

func is_grid_fully_collapsed() -> bool:
	for layer in grid:
		for row in layer:
			for cell in row:
				if not cell["collapsed"]:
					return false
	return true

func print_grid():
	print("\n=== WFC Result (%s) ===" % grid_type)
	for z in range(grid.size()):
		print("--- Layer Z=%d ---" % z)
		for row in grid[z]:
			var row_str = ""
			for cell in row:
				row_str += (cell["tile"][0] if cell["tile"] else "?") + " "
			print(row_str)

func get_collapse_progress() -> float:
	var total = grid_size.x * grid_size.y * grid_size.z
	if total == 0:
		return 0.0
	return float(get_collapsed_count()) / float(total)

func get_collapsed_count() -> int:
	var count = 0
	for layer in grid:
		for row in layer:
			for cell in row:
				if cell["collapsed"]:
					count += 1
	return count

# ===== INSTANTIATE TILES =====

func instantiate_tiles_in_world(parent: Node3D, p_tile_size: float = 2.0, layer_height: float = 2.0, p_spacing: float = -1.0):
	var use_size = tile_size if tile_size > 0 else p_tile_size
	var use_spacing = p_spacing if p_spacing >= 0 else tile_spacing

	# Effective cell size includes spacing
	var cell_size = use_size + use_spacing
	var cell_height = layer_height + use_spacing

	for z in range(grid.size()):
		for y in range(grid[z].size()):
			for x in range(grid[z][y].size()):
				var cell = grid[z][y][x]
				if not cell["tile"]:
					continue

				var tile_name = cell["tile"]
				if not tile_templates.has(tile_name):
					continue

				var filepath = tile_templates[tile_name].get("file_path", "")
				if filepath.is_empty():
					continue

				var resource = load(filepath)
				var instance: Node3D = null

				if resource is PackedScene:
					instance = resource.instantiate()
				elif resource is Mesh:
					instance = MeshInstance3D.new()
					instance.mesh = resource
				else:
					continue

				# Position based on grid type
				var pos: Vector3
				if grid_type == "hex":
					pos = hex_to_world_position(x, y, z, use_size, cell_height, use_spacing)
				else:
					pos = Vector3(x * cell_size, z * cell_height, y * cell_size)

				instance.position = pos
				instance.name = "%s_%d_%d_%d" % [tile_name, x, y, z]
				parent.add_child(instance)
				instance.owner = parent
				_set_owner_recursive(instance, parent)

func hex_to_world_position(x: int, y: int, z: int, hex_size: float, layer_height: float, spacing: float = 0.0) -> Vector3:
	if hex_orientation == "flat":
		return flat_hex_to_world(x, y, z, hex_size, layer_height, spacing)
	else:
		return pointy_hex_to_world(x, y, z, hex_size, layer_height, spacing)

func flat_hex_to_world(x: int, y: int, z: int, hex_size: float, layer_height: float, spacing: float = 0.0) -> Vector3:
	# Flat-top hexagon layout using outer radius (circumradius)
	# hex_size = outer radius (center to vertex)
	# For KayKit tiles: outer_radius = 1.1547, which gives width=2.0, height=2.309

	var outer_radius = hex_size

	# For flat-top hex:
	# Width (edge to edge, horizontal) = sqrt(3) * outer_radius
	# Height (vertex to vertex, vertical) = 2 * outer_radius
	var hex_width = sqrt(3.0) * outer_radius
	var hex_height = 2.0 * outer_radius

	# Horizontal distance between adjacent column centers = width
	var horiz_step = hex_width + spacing

	# Vertical distance between adjacent row centers = 3/4 of height
	var vert_step = (hex_height * 0.75) + spacing

	# Odd rows are offset to the right by half the horizontal step
	var x_offset = 0.0
	if (y % 2) == 1:
		x_offset = horiz_step * 0.5

	var world_x = x * horiz_step + x_offset
	var world_y = z * layer_height
	var world_z = y * vert_step

	return Vector3(world_x, world_y, world_z)

func pointy_hex_to_world(x: int, y: int, z: int, hex_size: float, layer_height: float, spacing: float = 0.0) -> Vector3:
	# Pointy-top hexagon layout
	# In Godot: X = right, Y = up (height), Z = forward (depth)

	var hex_width = sqrt(3.0) * hex_size   # Width (vertex to vertex)
	var hex_height = 2.0 * hex_size         # Height (edge to edge)

	# Horizontal spacing = 3/4 of width (columns interlock)
	var horiz_step = (hex_width * 0.75) + spacing

	# Vertical spacing = full height
	var vert_step = hex_height + spacing

	# Odd columns offset by half height
	var z_offset = 0.0
	if (x % 2) == 1:
		z_offset = hex_height * 0.5

	var world_x = x * horiz_step
	var world_y = z * layer_height
	var world_z = y * vert_step + z_offset

	return Vector3(world_x, world_y, world_z)






func _set_owner_recursive(node: Node, owner: Node):
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)
