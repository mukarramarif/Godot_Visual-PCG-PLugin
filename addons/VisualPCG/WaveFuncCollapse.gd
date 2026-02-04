extends Node

class_name WaveFunctionCollapse
var tileset_data: Dictionary = {}
var grid: Array = []
var grid_size: Vector2i = Vector2i(20,20)
var tile_templates: Dictionary = {}
signal generation_completed(grid_res: Array)
signal generation_failed(error: String)


func run_wfc(tileset:Dictionary):
	tileset_data = tileset

	if not valid_tileset():
		emit_signal("generation_failed", "Invalid tileset data")
		return null
	prepare_tiles()

	init_grid(grid_size)

	var success = collapse_grid()

	if success:
		emit_signal("generation_completed", grid)
		return grid
	else:
		emit_signal("generation_failed", "Collapse function failed - contradiction")
		return null

func valid_tileset()->bool:
	if not tileset_data.has("tiles"):
		push_error("Tileset data missing 'tiles' key")
		return false
	if tileset_data["tiles"].size() == 0:
		push_error("Tileset 'tiles' array is empty")
		return false
	return true

func prepare_tiles():
	tile_templates.clear()
	for tile_id in tileset_data["tiles"]:
		var tile_data = tileset_data["tiles"][tile_id]
		var template = {
			"id": tile_id,
			"name": tile_data["name"],
			"type": tile_data.get("type", "2d"),
			"weight": tile_data.get("weight", 1.0),
			"neighbors": tile_data["neighbors"],
			"file_path": tile_data.get("file_path", "")
		}
		tile_templates[tile_data["name"]] = template
	print("Prepared %d tile templates" % tile_templates.size())

func init_grid(size:Vector2i):
	grid_size = size
	grid.clear()

	var all_tiles = tile_templates.keys()
	for y in range(size.y):
		var row = []
		for x in range(size.x):
			row.append({
				"position": Vector2i(x,y),
				"collapsed":false,
				"possible_tiles": all_tiles.duplicate(),
				"tile": null,
			})
		grid.append(row)
	print("Grid is initialized: %dx%d" % [size.x, size.y])

func collapse_grid()->bool:
	var iterations = 0
	var max_iterations = grid_size.x * grid_size.y * 10
	while not is_grid_fully_collapsed():
		iterations+=1
		if iterations > max_iterations:
			push_error("Max iterations reached, possible contradiction")
			return false
		var cell = find_lowest_entropy_cell()
		if not cell:
			push_error("Failed to find lowest entropy cell")
			return false
		if not collapse_cell(cell):
			push_error("Contradiction occurred while collapsing cell at %s" % str(cell["position"]))
			return false
		propagate_constraints(cell)
		if iterations % 10 == 0:
			var progress = get_collapse_progress()
			print("Progress: %.1f%% (%d/%d cells)" % [progress *100, get_collapsed_count(), grid_size.x * grid_size.y])
	return true

func find_lowest_entropy_cell():
	var min_entropy = INF
	var candidates = []
	for row in grid:
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

func collapse_cell(cell:Dictionary)->bool:
	if cell["possible_tiles"].size() == 0:
		return false
	var chosen_tile = select_weighted_tile(cell["possible_tiles"])
	cell["tile"] = chosen_tile
	cell["collapsed"] = true
	cell["possible_tiles"] = [chosen_tile]
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

func propagate_constraints(start_cell:Dictionary):
	var queue = [start_cell]
	var processed = {}

	while queue.size()>0:
		var curr = queue.pop_front()
		var pos = curr["position"]
		var key = "%d,%d" % [pos.x, pos.y]
		if processed.has(key):
			continue
		processed[key] = true
		if not curr["collapsed"]:
			continue
		var update_neighbors = get_neighbors(pos)
		for neighbor in update_neighbors:
			var neighbor_cell = neighbor["cell"]
			var direction = neighbor["direction"]
			if neighbor_cell["collapsed"]:
				continue
			var curr_tile = curr["tile"]
			var allowed = get_allowed_tiles(curr_tile, direction)

			var new_possibilities = []
			for possible_tile in neighbor_cell["possible_tiles"]:
				if allowed.has(possible_tile):
					new_possibilities.append(possible_tile)
			if new_possibilities.size() < neighbor_cell["possible_tiles"].size():
				neighbor_cell["possible_tiles"] = new_possibilities
				queue.append(neighbor_cell)

func get_neighbors(pos: Vector2i)->Array:
	var neighbors = []
	if pos.y > 0:
		neighbors.append({"cell":grid[pos.y - 1][pos.x], "direction":"north"})
	if pos.y < grid_size.y - 1:
		neighbors.append({"cell":grid[pos.y + 1][pos.x], "direction":"south"})
	if pos.x > 0:
		neighbors.append({"cell":grid[pos.y][pos.x - 1], "direction":"west"})
	if pos.x < grid_size.x - 1:
		neighbors.append({"cell":grid[pos.y][pos.x + 1], "direction":"east"})
	return neighbors

func get_allowed_tiles(tile_name: String, direction: String)->Array:
	if not tile_templates.has(tile_name):
		return []
	var template = tile_templates[tile_name]
	var allowed = template["neighbors"].get(direction, [])
	return allowed

func is_grid_fully_collapsed() -> bool:
	for row in grid:
		for cell in row:
			if not cell["collapsed"]:
				return false
	return true

func get_collapse_progress() -> float:
	var total_cells = grid_size.x * grid_size.y
	var collapsed_count = get_collapsed_count()
	return float(collapsed_count) / float(total_cells)

func get_collapsed_count() -> int:
	var count = 0
	for row in grid:
		for cell in row:
			if cell["collapsed"]:
				count +=1
	return count

func get_grid_result()->Array:
	var result = []
	for row in grid:
		var result_row = []
		for cell in row:
			result_row.append(cell["tile"])
		result.append(result_row)
	return result

func print_grid():
	print("\n=== WFC Grid Result ===")
	for row in grid:
		var row_str = ""
		for cell in row:
			if cell["tile"]:
				row_str += cell["tile"][0] + " "
			else:
				row_str += "? "
		print(row_str)
	print("======================\n")
