@tool
extends Control
var wfc_generator = null
var graph_edit: GraphEdit
var add_node_menu: PopupMenu
var toolbar: HBoxContainer
var mouse_pos_for_new_node: Vector2
var tile_library_panel: Panel
var property_panel: VBoxContainer
var tile_list: ItemList
var current_tiles: Dictionary = {}
var selected_tile_node: GraphNode = null
var symmetry_enabled: bool = true
func set_wfc_generator(generator: Node) -> void:
	wfc_generator = generator
	print("WFC Generator set: ", wfc_generator)
## This following AST structure for nodes we will execute them i.e i figure that out
func _ready() -> void:
	setup_ui()
	setup_graph_edit()
	setup_toolbar()
	setup_properity_tab()
func setup_ui():
	# Main horizontal split
	var hsplit = HSplitContainer.new()
	hsplit.anchor_right = 1.0
	hsplit.anchor_bottom = 1.0
	add_child(hsplit)

	# Left side: Tile library
	tile_library_panel = Panel.new()
	tile_library_panel.custom_minimum_size.x = 250
	hsplit.add_child(tile_library_panel)

	# Center: Graph edit (main work area)
	var center_vbox = VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(center_vbox)

	toolbar = HBoxContainer.new()
	toolbar.custom_minimum_size.y = 40
	center_vbox.add_child(toolbar)

	graph_edit = GraphEdit.new()
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(graph_edit)

	# Right side: Properties panel
	var right_scroll = ScrollContainer.new()
	right_scroll.custom_minimum_size.x = 300
	hsplit.add_child(right_scroll)

	property_panel = VBoxContainer.new()
	property_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(property_panel)


func setup_graph_edit():
	graph_edit.right_disconnects = true
	graph_edit.show_zoom_label = true
	graph_edit.minimap_enabled = true


	# Connections represent neighbor relationships
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	graph_edit.node_selected.connect(_on_node_selected)
	graph_edit.node_deselected.connect(_on_node_deselected)
func setup_toolbar():
	var title_label= Label.new()
	title_label.text = "Wave Function Collapse"
	title_label.add_theme_font_size_override("font_size",16)
	toolbar.add_child(title_label)
	toolbar.add_child(VSeparator.new())

	var symmetry_check = CheckButton.new()
	symmetry_check.text = "Auto Symmetry"
	symmetry_check.button_pressed = symmetry_enabled
	symmetry_check.toggled.connect(_on_symmetry_toggled)
	symmetry_check.tooltip_text = "Automatically create reverse connections (North ↔ South, etc.)"
	toolbar.add_child(symmetry_check)

	toolbar.add_child(VSeparator.new())

	var new_tile_btn = Button.new()
	new_tile_btn.text = "New Tile"
	new_tile_btn.pressed.connect(_on_new_tile)
	toolbar.add_child(new_tile_btn)

	var import_btn = Button.new()
	import_btn.text = "Import Tiles"
	import_btn.pressed.connect(_on_import_tiles)
	toolbar.add_child(import_btn)

	toolbar.add_child(VSeparator.new())

	# var save_btn = Button.new()
	# save_btn.text = "Save Tileset"
	# save_btn.pressed.connect(_on_save_tileset)
	# toolbar.add_child(save_btn)

	# var load_btn = Button.new()
	# load_btn.text = "Load Tileset"
	# load_btn.pressed.connect(_on_load_tileset)
	# toolbar.add_child(load_btn)

	# var spacer = Control.new()
	# spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# toolbar.add_child(spacer)

	# var validate_btn = Button.new()
	# validate_btn.text = "Validate Rules"
	# validate_btn.pressed.connect(_on_validate_rules)
	# toolbar.add_child(validate_btn)
	var execute_btn = Button.new()
	execute_btn.text = "Run WFC"
	execute_btn.pressed.connect(_on_execute_wfc)
	toolbar.add_child(execute_btn)
#toolbar functions
func _on_symmetry_toggled(enabled: bool):
	symmetry_enabled = enabled
	print("Symmetry mode: %s" % ("ON" if enabled else "OFF"))
func _on_validate_rules():
	return null
func _on_save_tileset():
	return null
func _on_new_tile():
	return null
func _on_load_tileset():
	return null
func _on_import_tiles():
	NodeFunctions._open_files(self, _on_files_selected)
func _on_files_selected(paths: PackedStringArray):
	print("Importing %d files..." % paths.size())

	for path in paths:
		var extension = path.get_extension().to_lower()

		match extension:
			# 2D Images
			"png", "jpg", "jpeg", "svg", "webp":
				import_2d_tile(path)

			# 3D Models
			"gltf", "glb":
				print("not implemented")
				#import_3d_gltf_tile(path)
			"obj":
				print("not implemented")
				#import_3d_obj_tile(path)
			"fbx":
				import_3d_fbx_tile(path)
			"dae":
				print("not implemented")
				#import_3d_collada_tile(path)
			"blend":
				print("not implemented")
				#import_3d_blender_tile(path)

			# Godot Scenes
			"tscn", "scn":
				print("not implemented")
				#import_scene_tile(path)

			_:
				push_warning("Unsupported file format: %s" % extension)
func import_3d_fbx_tile(path: String):
	# FBX files are imported as scenes
	var scene = load(path) as PackedScene
	if not scene:
		push_error("Failed to load FBX: " + path)
		return

	var scene_root = scene.instantiate()
	var tile_name = path.get_file().get_basename()

	create_tile_node_3d(tile_name, scene_root, path, "fbx")
	print("✓ Imported FBX tile: ", tile_name)
func import_2d_tile(path: String):
	var texture = load(path) as Texture2D
	if not texture:
		push_error("Failed to load texture: " + path)
		return

	var tile_name = path.get_file().get_basename()
	#create_tile_node_2d(tile_name, texture, path)
	print("✓ Imported 2D tile: ", tile_name)

#func create_tile_node_2d(tile_name: String, texture: Texture2D, file_path: String):
	#var node = GraphNode.new()
	#node.title = tile_name + " (2D)"
	#node.name = "Tile_" + str(Time.get_ticks_msec())
	#node.resizable = true
	#
	## Store metadata
	#node.set_meta("tile_type", "2d")
	#node.set_meta("file_path", file_path)
	#node.set_meta("tile_name", tile_name)
	#
	## Preview
	#var texture_rect = TextureRect.new()
	#texture_rect.texture = texture
	#texture_rect.custom_minimum_size = Vector2(128, 128)
	#texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	#texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	#node.add_child(texture_rect)
	#
	#add_wfc_ports(node)
	#
	#graph_edit.add_child(node)
	#node.position_offset = get_next_tile_position()
func create_tile_node_3d(tile_name: String, model_root: Node, file_path: String, format: String):
	var node = GraphNode.new()
	node.title = tile_name + " (3D)"
	node.name = "Tile_" + str(Time.get_ticks_msec())
	node.resizable = true

	# Store metadata
	node.set_meta("tile_type", "3d")
	node.set_meta("file_path", file_path)
	node.set_meta("tile_name", tile_name)
	node.set_meta("format", format)
	node.set_meta("model_root", model_root)

	# Create preview (3D viewport thumbnail)
	var preview_container = await create_3d_preview(model_root)
	node.add_child(preview_container)

	# Model info
	var info_label = Label.new()
	info_label.text = "Format: %s\nPath: %s" % [format.to_upper(), file_path.get_file()]
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	node.add_child(info_label)

	add_wfc_ports_3d(node)

	graph_edit.add_child(node)
	node.position_offset = get_next_tile_position()
var tile_position_offset = Vector2(50, 50)

func get_next_tile_position() -> Vector2:
	var pos = tile_position_offset
	tile_position_offset.x += 200

	# Wrap to next row if too far right
	if tile_position_offset.x > 1000:
		tile_position_offset.x = 50
		tile_position_offset.y += 250

	return pos
func add_wfc_ports(node: GraphNode):
	# 4 directions for 2D with better labels
	var directions = ["North", "South", "East", "West"]
	var colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
	var tooltips = [
		"North side - connects to South",
		"South side - connects to North",
		"East side - connects to West",
		"West side - connects to East"
	]

	for i in directions.size():
		var hbox = HBoxContainer.new()

		# Direction indicator
		var indicator = ColorRect.new()
		indicator.custom_minimum_size = Vector2(12, 12)
		indicator.color = colors[i]
		hbox.add_child(indicator)

		var label = Label.new()
		label.text = " " + directions[i]
		label.tooltip_text = tooltips[i]
		hbox.add_child(label)

		node.add_child(hbox)
		node.set_slot(i + 1, true, i, colors[i], true, i, colors[i])

func add_wfc_ports_3d(node: GraphNode):
	# 6 directions for 3D with better labels
	var directions = ["North", "South", "East", "West", "Up", "Down"]
	var colors = [
		Color.RED,      # North
		Color.BLUE,     # South
		Color.GREEN,    # East
		Color.YELLOW,   # West
		Color.PURPLE,   # Up
		Color.ORANGE    # Down
	]
	var tooltips = [
		"North side - connects to South",
		"South side - connects to North",
		"East side - connects to West",
		"West side - connects to East",
		"Up/Top side - connects to Down",
		"Down/Bottom side - connects to Up"
	]

	for i in directions.size():
		var hbox = HBoxContainer.new()

		# Direction indicator
		var indicator = ColorRect.new()
		indicator.custom_minimum_size = Vector2(12, 12)
		indicator.color = colors[i]
		hbox.add_child(indicator)

		var label = Label.new()
		label.text = " " + directions[i]
		label.tooltip_text = tooltips[i]
		hbox.add_child(label)

		node.add_child(hbox)

		# Offset by 2 to account for preview and info label
		node.set_slot(i + 2, true, i, colors[i], true, i, colors[i])

func create_3d_preview(model: Node) -> Control:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(150, 150)

	# Create SubViewport for 3D preview
	var viewport = SubViewport.new()
	viewport.size = Vector2i(150, 150)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Camera
	var camera = Camera3D.new()
	camera.position = Vector3(0 ,0, 3)
	camera.look_at_from_position(Vector3.ZERO, Vector3.ZERO)
	viewport.add_child(camera)

	# Lighting
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	viewport.add_child(light)

	# Add model
	if model:
		viewport.add_child(model)

	# Display viewport texture
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(150, 150)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

	# Wait for viewport to render
	await get_tree().process_frame
	texture_rect.texture = viewport.get_texture()

	container.add_child(viewport)
	container.add_child(texture_rect)

	return container

# Signal handlers
func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	var from_node_obj = graph_edit.get_node(NodePath(from_node))
	var to_node_obj = graph_edit.get_node(NodePath(to_node))

	if not from_node_obj or not to_node_obj:
		return

	# Prevent connecting to self
	if from_node == to_node:
		push_warning("Cannot connect a tile to itself")
		return

	# Check if connection already exists
	if is_connection_exists(from_node, from_port, to_node, to_port):
		push_warning("Connection already exists")
		return

	var is_3d = from_node_obj.get_meta("tile_type", "2d") == "3d"

	# IF SYMMETRY IS ENABLED: Validate and create reverse connection
	if symmetry_enabled:
		if is_valid_wfc_connection(from_port, to_port, is_3d):
			# Create main connection
			graph_edit.connect_node(from_node, from_port, to_node, to_port)

			# Create reverse connection
			var reverse_port_from = get_opposite_port(to_port, is_3d)
			var reverse_port_to = get_opposite_port(from_port, is_3d)

			if reverse_port_from >= 0 and reverse_port_to >= 0:
				if not is_connection_exists(to_node, reverse_port_from, from_node, reverse_port_to):
					graph_edit.connect_node(to_node, reverse_port_from, from_node, reverse_port_to)
					print("✓ Symmetrical connection: %s(%s) ↔ %s(%s)" % [
						from_node_obj.title, get_direction_name(from_port, is_3d),
						to_node_obj.title, get_direction_name(to_port, is_3d)
					])

			_on_execute_graph()
		else:
			push_warning("Invalid WFC connection: %s ↔ %s" % [
				get_direction_name(from_port, is_3d),
				get_direction_name(to_port, is_3d)
			])

	# IF SYMMETRY IS DISABLED: Allow any connection
	else:
		graph_edit.connect_node(from_node, from_port, to_node, to_port)
		print("✓ Connected: %s [%s] → %s [%s]" % [
			from_node_obj.title,
			get_direction_name(from_port, is_3d),
			to_node_obj.title,
			get_direction_name(to_port, is_3d)
		])
		_on_execute_graph()
func is_valid_wfc_connection(from_port: int, to_port: int, is_3d:bool)->bool:
	var opposite_pairs_2d = [
		[0,1], # North South
		[2.,3], # East West
	]
	var opposite_pairs_3d = [
		[0,1],
		[2,3],
		[4,5], # up down
	]
	var pairs = opposite_pairs_3d if is_3d else opposite_pairs_2d
	for pair in pairs:
		if (from_port == pair[0] and to_port == pair[1]) or \
		   (from_port == pair[1] and to_port == pair[0]):
			return true
	if from_port == to_port:
		return true
	return false
func get_opposite_port(port: int, is_3d: bool)->int:
	match port:
		0: return 1
		1: return 0
		2: return 3
		3: return 2
		4: return 5
		5: return 4
	return -1
# Get direction name from port number
func get_direction_name(port: int, is_3d: bool) -> String:
	var directions_3d = ["North", "South", "East", "West", "Up", "Down"]
	var directions_2d = ["North", "South", "East", "West"]

	var dirs = directions_3d if is_3d else directions_2d

	if port >= 0 and port < dirs.size():
		return dirs[port]
	return "Unknown"
func is_connection_exists(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> bool:
	var connections = graph_edit.get_connection_list()
	for conn in connections:
		if conn["from_node"] == from_node and \
		   conn["from_port"] == from_port and \
		   conn["to_node"] == to_node and \
		   conn["to_port"] == to_port:
			return true
	return false
func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_on_execute_graph()
func highlight_compatible_ports(source_node: GraphNode, source_port: int):
	var is_3d = source_node.get_meta("tile_type", "2d") == "3d"
	var compatible_port = get_opposite_port(source_port, is_3d)

	# Highlight all nodes' compatible ports
	for child in graph_edit.get_children():
		if child is GraphNode and child != source_node:
			# You could add visual highlighting here
			pass
func show_connection_error(from_port: int, to_port: int, is_3d: bool):
	var from_dir = get_direction_name(from_port, is_3d)
	var to_dir = get_direction_name(to_port, is_3d)

	print("❌ Cannot connect %s to %s" % [from_dir, to_dir])
	print("   Valid connections:")
	print("   - North ↔ South")
	print("   - East ↔ West")
	if is_3d:
		print("   - Up ↔ Down")
	print("   - Same direction (e.g., North ↔ North)")
func export_wfc_tileset() -> Dictionary:
	var tileset = {
		"tiles": {},
		"symmetry_mode": symmetry_enabled,
		"metadata": {
			"created_at": Time.get_datetime_string_from_system(),
			"total_tiles": 0,
			"total_connections": 0
		}
	}

	# Export all tiles
	for child in graph_edit.get_children():
		if child is GraphNode:
			var tile_id = child.name
			var tile_data = {
				"name": child.title,
				"type": child.get_meta("tile_type", "2d"),
				"file_path": child.get_meta("file_path", ""),
				"format": child.get_meta("format", ""),
				"position": {
					"x": child.position_offset.x,
					"y": child.position_offset.y
				},
				"neighbors": get_tile_neighbors(tile_id),
				"weight": 1.0  # Default weight, can be customized
			}
			tileset["tiles"][tile_id] = tile_data
			tileset["metadata"]["total_tiles"] += 1

	# Count total connections
	tileset["metadata"]["total_connections"] = graph_edit.get_connection_list().size()

	return tileset
func get_tile_neighbors(node_name: String) -> Dictionary:
	var neighbors = {
		"north": [],
		"south": [],
		"east": [],
		"west": [],
		"up": [],
		"down": []
	}

	var node = graph_edit.get_node_or_null(NodePath(node_name))
	if not node:
		return neighbors

	var is_3d = node.get_meta("tile_type", "2d") == "3d"
	var connections = graph_edit.get_connection_list()

	# Collect all outgoing connections
	for conn in connections:
		if conn["from_node"] == node_name:
			var port = conn["from_port"]
			var direction = get_direction_name(port, is_3d).to_lower()

			# Get target tile name
			var target_node = graph_edit.get_node_or_null(NodePath(conn["to_node"]))
			if target_node:
				var target_tile_name = target_node.title
				if not neighbors[direction].has(target_tile_name):
					neighbors[direction].append(target_tile_name)

	return neighbors
func _on_delete_nodes_request(nodes: Array):
	for node_name in nodes:
		var node = graph_edit.get_node(NodePath(node_name))
		if node:
			graph_edit.remove_child(node)
			node.queue_free()

func _on_popup_request(position: Vector2):
	mouse_pos_for_new_node = (position + graph_edit.scroll_offset) / graph_edit.zoom
	add_node_menu.position = get_viewport().get_mouse_position()
	add_node_menu.popup()

func _on_graph_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			mouse_pos_for_new_node = (event.position + graph_edit.scroll_offset) / graph_edit.zoom
			add_node_menu.position = get_viewport().get_mouse_position()
			add_node_menu.popup()
func _on_execute_graph():
	print("Executing PCG Graph...")
func _on_execute_wfc():
	print("\n=== Executing Wave Function Collapse ===")
	print("Wave Function Collapse Generator: " + str(wfc_generator))
	# Export current tileset
	var tileset_data = export_wfc_tileset()

	# Validate before running
	var validation = validate_tileset(tileset_data)
	if not validation.valid:
		push_error("Cannot run WFC: Tileset has errors")
		for error in validation.errors:
			print("  ❌ " + error)
		return

	# Print summary
	print("Tileset Summary:")
	print("  - Tiles: %d" % tileset_data["metadata"]["total_tiles"])
	print("  - Connections: %d" % tileset_data["metadata"]["total_connections"])
	print("  - Symmetry Mode: %s" % ("ON" if symmetry_enabled else "OFF"))

	# Send to WFC generator
	if wfc_generator:
		wfc_generator.run_wfc(tileset_data)
		print("WFC data sent to generator")
	else:
		#Save to file for external use
		save_tileset_to_file(tileset_data)
		print("Tileset exported to file as JSON (no generator connected)")

	print("=====================================\n")
func validate_tileset(tileset_data: Dictionary) -> Dictionary:
	var result = {
		"valid": true,
		"errors": [],
		"warnings": []
	}

	# Check if we have tiles
	if tileset_data["tiles"].size() == 0:
		result.valid = false
		result.errors.append("No tiles in tileset")
		return result

	# Check each tile
	for tile_id in tileset_data["tiles"]:
		var tile = tileset_data["tiles"][tile_id]

		# Check if tile has any neighbors
		var has_neighbors = false
		for direction in tile["neighbors"]:
			if tile["neighbors"][direction].size() > 0:
				has_neighbors = true
				break

		if not has_neighbors:
			result.warnings.append("Tile '%s' has no neighbors" % tile["name"])

		# Validate neighbor references exist
		for direction in tile["neighbors"]:
			for neighbor_name in tile["neighbors"][direction]:
				var found = false
				for check_id in tileset_data["tiles"]:
					if tileset_data["tiles"][check_id]["name"] == neighbor_name:
						found = true
						break

				if not found:
					result.valid = false
					result.errors.append("Tile '%s' references unknown neighbor '%s'" % [tile["name"], neighbor_name])

	return result
func save_tileset_to_file(tileset_data: Dictionary):
	var json_string = JSON.stringify(tileset_data, "\t")
	var file = FileAccess.open("res://wfc_tileset_export.json", FileAccess.WRITE)

	if file:
		file.store_string(json_string)
		file.close()
		print("Tileset saved to: res://wfc_tileset_export.json")
	else:
		push_error("Failed to save tileset file")
func setup_properity_tab():
	var vbox = VBoxContainer.new()
	property_panel.add_child(vbox)
	var tile_label = Label.new()
	tile_label.text = "Tile Properties"
	tile_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(tile_label)
	var search_box = LineEdit.new()
	search_box.placeholder_text = "Search tiles..."
	search_box.text_changed.connect(_on_search_tiles)
	vbox.add_child(search_box)

	tile_list = ItemList.new()
	tile_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile_list.item_selected.connect(_on_tile_library_selected)
	tile_list.item_activated.connect(_on_tile_library_activated)
	vbox.add_child(tile_list)

	var add_to_graph_btn = Button.new()
	add_to_graph_btn.text = "Add to Graph"
	add_to_graph_btn.pressed.connect(_on_add_selected_tile_to_graph)
	vbox.add_child(add_to_graph_btn)
func _on_search_tiles():
	return null
func _on_tile_library_selected():
	return null
func _on_tile_library_activated():
	return null
func _on_add_selected_tile_to_graph():
	return null
func _on_node_selected(node: Node):
	#if node is GraphNode:
		#selected_tile_node = node
		#var tile_id = node.get_meta("tile_id")
		#if tile_id and current_tiles.has(tile_id):
			#display_tile_properties(current_tiles[tile_id])
	return null
func setup_add_node_menu():
	add_node_menu = PopupMenu.new()
	add_child(add_node_menu)

	# Add menu items for WFC tiles
	add_node_menu.add_item("Empty Tile", 0)
	add_node_menu.add_item("Wall Tile", 1)
	add_node_menu.add_item("Floor Tile", 2)
	add_node_menu.add_item("Door Tile", 3)
	add_node_menu.add_separator()
	add_node_menu.add_item("Custom Tile", 4)

	add_node_menu.id_pressed.connect(_on_add_node_menu_id_pressed)
func _on_add_node_menu_id_pressed(id: int):
	var tile_name = ""
	match id:
		0: tile_name = "Empty"
		1: tile_name = "Wall"
		2: tile_name = "Floor"
		3: tile_name = "Door"
		4: tile_name = "Custom"

	create_tile_node(tile_name)
func create_tile_node(tile_name: String) -> GraphNode:
	var node = GraphNode.new()
	node.title = tile_name + " Tile"
	node.name = "Tile_" + str(Time.get_ticks_msec())
	node.resizable = true

	# Add to graph first
	graph_edit.add_child(node)

	# Then set position
	node.position_offset = mouse_pos_for_new_node

	# Add some basic UI to the node
	var label = Label.new()
	label.text = "Weight: 1.0"
	node.add_child(label)

	# Add ports (North, South, East, West)
	for i in 4:
		var port_label = Label.new()
		var directions = ["North", "South", "East", "West"]
		port_label.text = directions[i]
		node.add_child(port_label)

		var colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
		node.set_slot(i + 1, true, i, colors[i], true, i, colors[i])

	return node

func _on_node_deselected(node: Node):
	selected_tile_node = null
