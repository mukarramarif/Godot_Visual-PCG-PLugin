@tool
extends Control

## 3D Visual Tile Socket Editor with Hex Support
## Socket-based tile connection system

var wfc_generator: Node = null
var tile_library: Dictionary = {}
var current_tile: String = ""

# UI Elements
var main_hsplit: HSplitContainer
var tile_list: ItemList
var viewport_container: SubViewportContainer
var viewport: SubViewport
var properties_panel: VBoxContainer
var toolbar: HBoxContainer
var socket_inputs: Dictionary = {}
var highlight_cube: HighlighCube = null
# 3D Preview
var preview_root: Node3D
var preview_camera: Camera3D
var current_tile_instance: Node3D = null

# Camera controls
var camera_distance: float = 5.0
var camera_angle_h: float = 45.0
var camera_angle_v: float = 30.0
var is_orbiting: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

# Grid settings
var grid_size_x: int = 20
var grid_size_y: int = 20
var grid_size_z: int = 1
var grid_type: String = "square"  # "square" or "hex"
var hex_orientation: String = "flat"  # "flat" or "pointy"
var tile_size: float = 2.0
var tile_spacing: float = 0.0  # Gap between tiles

# Panel size settings
var left_panel_width: int = 200
var right_panel_width: int = 280

# Direction definitions
const SQUARE_DIRECTIONS = ["north", "south", "east", "west", "up", "down"]
const HEX_FLAT_DIRECTIONS = ["ne", "e", "se", "sw", "w", "nw", "up", "down"]
const HEX_POINTY_DIRECTIONS = ["ne", "e", "se", "sw", "w", "nw", "up", "down"]

const DIRECTION_COLORS = {
	# Square
	"north": Color.RED,
	"south": Color.CYAN,
	"east": Color.GREEN,
	"west": Color.YELLOW,
	"up": Color.MAGENTA,
	"down": Color.ORANGE,
	# Hex flat-top
	"n": Color.RED,
	"s": Color.CYAN,
	# Hex pointy-top
	"e": Color.GREEN,
	"w": Color.YELLOW,
	# Hex shared
	"ne": Color(1.0, 0.5, 0.0),
	"se": Color(0.0, 0.8, 0.8),
	"sw": Color.BLUE,
	"nw": Color(1.0, 0.0, 0.5),
}

func get_current_directions() -> Array:
	if grid_type == "hex":
		if hex_orientation == "flat":
			return HEX_FLAT_DIRECTIONS
		else:
			return HEX_POINTY_DIRECTIONS
	return SQUARE_DIRECTIONS

func _ready():
	setup_ui()
	setup_3d_preview()

func set_wfc_generator(generator: Node) -> void:
	wfc_generator = generator
	print("WFC Generator set: ", wfc_generator)

func setup_ui():
	main_hsplit = HSplitContainer.new()
	main_hsplit.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hsplit.split_offset = left_panel_width
	add_child(main_hsplit)

	# === LEFT PANEL ===
	var left_panel = VBoxContainer.new()
	left_panel.name = "LeftPanel"
	left_panel.custom_minimum_size.x = 150  # Minimum, but adjustable via split
	main_hsplit.add_child(left_panel)

	var library_label = Label.new()
	library_label.text = "Tile Library"
	library_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(library_label)

	var import_btn = Button.new()
	import_btn.text = "Import Tiles"
	import_btn.pressed.connect(_on_import_tiles)
	left_panel.add_child(import_btn)

	var remove_btn = Button.new()
	remove_btn.text = "Remove Tile"
	remove_btn.pressed.connect(_on_remove_tile)
	left_panel.add_child(remove_btn)

	tile_list = ItemList.new()
	tile_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile_list.item_selected.connect(_on_tile_selected)
	left_panel.add_child(tile_list)

	# === CENTER PANEL (with nested split for right panel) ===
	var center_right_split = HSplitContainer.new()
	center_right_split.name = "CenterRightSplit"
	center_right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.add_child(center_right_split)

	var center_panel = VBoxContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_right_split.add_child(center_panel)

	toolbar = HBoxContainer.new()
	toolbar.custom_minimum_size.y = 40
	center_panel.add_child(toolbar)
	setup_toolbar()

	viewport_container = SubViewportContainer.new()
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	viewport_container.gui_input.connect(_on_viewport_input)
	center_panel.add_child(viewport_container)

	var instructions = Label.new()
	instructions.text = "Left-click + drag to orbit | Scroll to zoom"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_panel.add_child(instructions)

	# === RIGHT PANEL ===
	var right_container = VBoxContainer.new()
	right_container.name = "RightContainer"
	right_container.custom_minimum_size.x = 280  # Minimum width
	center_right_split.add_child(right_container)

	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_container.add_child(right_scroll)

	properties_panel = VBoxContainer.new()
	properties_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(properties_panel)

	setup_socket_editor_ui()

func setup_toolbar():
	var grid_label = Label.new()
	grid_label.text = "Grid:"
	toolbar.add_child(grid_label)

	var type_option = OptionButton.new()
	type_option.add_item("Square", 0)
	type_option.add_item("Hex (Pointy)", 1)
	type_option.add_item("Hex (Flat)", 2)
	type_option.selected = 0
	type_option.item_selected.connect(_on_grid_type_changed)
	toolbar.add_child(type_option)

	toolbar.add_child(VSeparator.new())

	# Size controls
	var x_spin = SpinBox.new()
	x_spin.custom_minimum_size.x = 80
	x_spin.min_value = 1
	x_spin.max_value = 100
	x_spin.value = grid_size_x
	x_spin.prefix = "X:"
	x_spin.value_changed.connect(func(v): grid_size_x = int(v))
	toolbar.add_child(x_spin)

	var y_spin = SpinBox.new()
	y_spin.custom_minimum_size.x = 80
	y_spin.min_value = 1
	y_spin.max_value = 100
	y_spin.value = grid_size_y
	y_spin.prefix = "Y:"
	y_spin.value_changed.connect(func(v): grid_size_y = int(v))
	toolbar.add_child(y_spin)

	var z_spin = SpinBox.new()
	z_spin.custom_minimum_size.x = 80
	z_spin.min_value = 0
	z_spin.max_value = 20
	z_spin.value = grid_size_z
	z_spin.prefix = "Z:"
	z_spin.tooltip_text = "0 = 2D grid"
	z_spin.value_changed.connect(func(v): grid_size_z = int(v))
	toolbar.add_child(z_spin)

	toolbar.add_child(VSeparator.new())

	# Tile size
	var size_spin = SpinBox.new()
	size_spin.name = "TileSizeSpin"
	size_spin.custom_minimum_size.x = 100
	size_spin.min_value = 0.5
	size_spin.max_value = 10.0
	size_spin.step = 0.1
	size_spin.value = tile_size
	size_spin.prefix = "Size:"
	size_spin.tooltip_text = "Size of each tile"
	size_spin.value_changed.connect(func(v): tile_size = v)
	toolbar.add_child(size_spin)

	# Tile spacing (gap between tiles)
	var spacing_spin = SpinBox.new()
	spacing_spin.name = "TileSpacingSpin"
	spacing_spin.custom_minimum_size.x = 100
	spacing_spin.min_value = 0.0
	spacing_spin.max_value = 5.0
	spacing_spin.step = 0.05
	spacing_spin.value = tile_spacing
	spacing_spin.prefix = "Gap:"
	spacing_spin.tooltip_text = "Spacing/gap between tiles"
	spacing_spin.value_changed.connect(func(v): tile_spacing = v)
	toolbar.add_child(spacing_spin)

	toolbar.add_child(VSeparator.new())

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save_tileset)
	toolbar.add_child(save_btn)

	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_on_load_tileset)
	toolbar.add_child(load_btn)

	toolbar.add_child(VSeparator.new())

	var run_btn = Button.new()
	run_btn.text = "Run WFC"
	run_btn.pressed.connect(_on_run_wfc)
	toolbar.add_child(run_btn)

func _on_grid_type_changed(index: int):
	match index:
		0:
			grid_type = "square"
			hex_orientation = ""
		1:
			grid_type = "hex"
			hex_orientation = "pointy"
		2:
			grid_type = "hex"
			hex_orientation = "flat"

	print("Grid type: %s, Hex orientation: %s" % [grid_type, hex_orientation])

	# Rebuild socket editor with new directions
	rebuild_socket_editor()

	# Reset sockets on all tiles for new grid type
	for tile_name in tile_library:
		tile_library[tile_name]["sockets"] = create_default_sockets()

func create_default_sockets() -> Dictionary:
	var sockets = {}
	for direction in get_current_directions():
		sockets[direction] = "-1"
	return sockets
## Setups the UI on right side
func setup_socket_editor_ui():
	var title = Label.new()
	title.text = "Socket Editor"
	title.add_theme_font_size_override("font_size", 16)
	properties_panel.add_child(title)

	properties_panel.add_child(HSeparator.new())

	# Help text
	var help = Label.new()
	help.text = "Socket Format:\n  -1 = no connection\n  0 = empty/air\n  1S = symmetric\n  1/1F = asymmetric pair"
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color.GRAY)
	properties_panel.add_child(help)

	properties_panel.add_child(HSeparator.new())

	# Tile name
	var name_label = Label.new()
	name_label.name = "TileNameLabel"
	name_label.text = "No tile selected"
	properties_panel.add_child(name_label)

	properties_panel.add_child(HSeparator.new())

	# Socket inputs container (rebuilt when grid type changes)
	var socket_container = VBoxContainer.new()
	socket_container.name = "SocketContainer"
	properties_panel.add_child(socket_container)

	build_socket_inputs(socket_container)

	properties_panel.add_child(HSeparator.new())

	# Presets
	var presets_container = VBoxContainer.new()
	presets_container.name = "PresetsContainer"
	properties_panel.add_child(presets_container)
	build_presets(presets_container)

	properties_panel.add_child(HSeparator.new())

	# Weight
	var weight_hbox = HBoxContainer.new()
	var weight_label = Label.new()
	weight_label.text = "Weight:"
	weight_hbox.add_child(weight_label)
	var weight_spin = SpinBox.new()
	weight_spin.name = "WeightSpin"
	weight_spin.min_value = 0.1
	weight_spin.max_value = 10.0
	weight_spin.step = 0.1
	weight_spin.value = 1.0
	weight_spin.value_changed.connect(_on_weight_changed)
	weight_hbox.add_child(weight_spin)
	properties_panel.add_child(weight_hbox)

	properties_panel.add_child(HSeparator.new())

	# Compatibility display
	var compat_label = Label.new()
	compat_label.text = "Compatible Tiles:"
	compat_label.add_theme_font_size_override("font_size", 14)
	properties_panel.add_child(compat_label)

	var compat_list = RichTextLabel.new()
	compat_list.name = "CompatList"
	compat_list.custom_minimum_size.y = 150
	compat_list.bbcode_enabled = true
	compat_list.fit_content = true
	properties_panel.add_child(compat_list)

func build_socket_inputs(container: VBoxContainer):
	socket_inputs.clear()

	var sockets_label = Label.new()
	sockets_label.text = "Sockets (%s grid):" % grid_type.capitalize()
	sockets_label.add_theme_font_size_override("font_size", 14)
	container.add_child(sockets_label)

	for direction in get_current_directions():
		var hbox = HBoxContainer.new()

		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(16, 16)
		color_rect.color = DIRECTION_COLORS.get(direction, Color.WHITE)
		hbox.add_child(color_rect)

		var dir_label = Label.new()
		dir_label.text = direction.to_upper() + ":"
		dir_label.custom_minimum_size.x = 40
		hbox.add_child(dir_label)

		var input = LineEdit.new()
		input.name = "Socket_" + direction
		input.placeholder_text = "-1"
		input.custom_minimum_size.x = 80
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input.text_changed.connect(_on_socket_changed.bind(direction))
		hbox.add_child(input)

		socket_inputs[direction] = input
		container.add_child(hbox)

func build_presets(container: VBoxContainer):
	# Clear existing
	for child in container.get_children():
		child.queue_free()

	var presets_label = Label.new()
	presets_label.text = "Quick Presets:"
	container.add_child(presets_label)

	var preset_grid = GridContainer.new()
	preset_grid.columns = 2
	container.add_child(preset_grid)

	var presets = []
	if grid_type == "hex":
		if hex_orientation == "flat":
			presets = [
				["All -1", func(): apply_all_sockets("-1")],
				["All 0", func(): apply_all_sockets("0")],
				["All Sides 1S", func(): apply_hex_sides_flat("1S")],
				["Open Hex", func(): apply_open_hex()],
			]
		else:
			presets = [
				["All -1", func(): apply_all_sockets("-1")],
				["All 0", func(): apply_all_sockets("0")],
				["All Sides 1S", func(): apply_hex_sides_pointy("1S")],
				["Open Hex", func(): apply_open_hex()],
			]
	else:
		presets = [
			["All -1", func(): apply_all_sockets("-1")],
			["All 0", func(): apply_all_sockets("0")],
			["Floor", func(): apply_floor_preset()],
			["Wall N/S", func(): apply_wall_ns_preset()],
		]

	for preset in presets:
		var btn = Button.new()
		btn.text = preset[0]
		btn.pressed.connect(preset[1])
		preset_grid.add_child(btn)

func rebuild_socket_editor():
	var socket_container = properties_panel.get_node_or_null("SocketContainer")
	if socket_container:
		for child in socket_container.get_children():
			child.queue_free()
		build_socket_inputs(socket_container)

	var presets_container = properties_panel.get_node_or_null("PresetsContainer")
	if presets_container:
		build_presets(presets_container)

# Preset helpers
func apply_all_sockets(value: String):
	if current_tile.is_empty():
		return
	for direction in get_current_directions():
		socket_inputs[direction].text = value
		_on_socket_changed(value, direction)

func apply_hex_sides_pointy(value: String):
	if current_tile.is_empty():
		return
	for direction in ["ne", "e", "se", "sw", "w", "nw"]:
		if socket_inputs.has(direction):
			socket_inputs[direction].text = value
			_on_socket_changed(value, direction)
	if socket_inputs.has("up"):
		socket_inputs["up"].text = "-1"
		_on_socket_changed("-1", "up")
	if socket_inputs.has("down"):
		socket_inputs["down"].text = "-1"
		_on_socket_changed("-1", "down")

func apply_hex_sides_flat(value: String):
	if current_tile.is_empty():
		return
	for direction in ["n", "ne", "se", "s", "sw", "nw"]:
		if socket_inputs.has(direction):
			socket_inputs[direction].text = value
			_on_socket_changed(value, direction)
	if socket_inputs.has("up"):
		socket_inputs["up"].text = "-1"
		_on_socket_changed("-1", "up")
	if socket_inputs.has("down"):
		socket_inputs["down"].text = "-1"
		_on_socket_changed("-1", "down")

func apply_open_hex():
	if current_tile.is_empty():
		return
	for direction in ["ne", "e", "se", "sw", "w", "nw"]:
		socket_inputs[direction].text = "1S"
		_on_socket_changed("1S", direction)
	socket_inputs["up"].text = "0"
	socket_inputs["down"].text = "0"
	_on_socket_changed("0", "up")
	_on_socket_changed("0", "down")

func apply_floor_preset():
	if current_tile.is_empty():
		return
	for direction in ["north", "south", "east", "west"]:
		socket_inputs[direction].text = "1S"
		_on_socket_changed("1S", direction)
	socket_inputs["up"].text = "-1"
	socket_inputs["down"].text = "0"
	_on_socket_changed("-1", "up")
	_on_socket_changed("0", "down")

func apply_wall_ns_preset():
	if current_tile.is_empty():
		return
	socket_inputs["north"].text = "1S"
	socket_inputs["south"].text = "1S"
	_on_socket_changed("1S", "north")
	_on_socket_changed("1S", "south")
	for direction in ["east", "west", "up", "down"]:
		socket_inputs[direction].text = "-1"
		_on_socket_changed("-1", direction)

func _on_socket_changed(new_text: String, direction: String):
	if current_tile.is_empty() or not tile_library.has(current_tile):
		return
	tile_library[current_tile]["sockets"][direction] = new_text.strip_edges()
	update_compatibility_display()
	_update_highlight_faces()

func _on_weight_changed(value: float):
	if current_tile.is_empty() or not tile_library.has(current_tile):
		return
	tile_library[current_tile]["weight"] = value

func update_socket_inputs():
	if current_tile.is_empty() or not tile_library.has(current_tile):
		for direction in get_current_directions():
			if socket_inputs.has(direction):
				socket_inputs[direction].text = ""
		return

	var tile_data = tile_library[current_tile]
	var sockets = tile_data.get("sockets", {})

	for direction in get_current_directions():
		if socket_inputs.has(direction):
			socket_inputs[direction].text = sockets.get(direction, "-1")

	var weight_spin = properties_panel.get_node_or_null("WeightSpin")
	if weight_spin:
		weight_spin.value = tile_data.get("weight", 1.0)

	var name_label = properties_panel.get_node_or_null("TileNameLabel")
	if name_label:
		name_label.text = "Editing: " + current_tile

func update_compatibility_display():
	var compat_list = properties_panel.get_node_or_null("CompatList")
	if not compat_list:
		return

	if current_tile.is_empty() or not tile_library.has(current_tile):
		compat_list.text = ""
		return

	var text = ""
	var current_sockets = tile_library[current_tile].get("sockets", {})

	for direction in get_current_directions():
		var socket = current_sockets.get(direction, "-1")
		var color = DIRECTION_COLORS.get(direction, Color.WHITE).to_html(false)
		text += "[color=#%s]%s[/color] (%s): " % [color, direction.to_upper(), socket]

		if socket == "-1":
			text += "[color=gray]none[/color]\n"
			continue

		var compatible = []
		for other_tile in tile_library:
			if can_connect(current_tile, direction, other_tile):
				compatible.append(other_tile)

		if compatible.size() == 0:
			text += "[color=red]no matches![/color]\n"
		else:
			text += ", ".join(compatible) + "\n"

	compat_list.text = text

func can_connect(tile_a: String, direction: String, tile_b: String) -> bool:
	if not tile_library.has(tile_a) or not tile_library.has(tile_b):
		return false
	var socket_a = tile_library[tile_a].get("sockets", {}).get(direction, "-1")
	var opposite = get_opposite_direction(direction)
	var socket_b = tile_library[tile_b].get("sockets", {}).get(opposite, "-1")
	return sockets_compatible(socket_a, socket_b)

func sockets_compatible(socket_a: String, socket_b: String) -> bool:
	if socket_a == "-1" or socket_b == "-1":
		return false
	if socket_a.is_empty() or socket_b.is_empty():
		return false

	var a_symmetric = socket_a.ends_with("S")
	var b_symmetric = socket_b.ends_with("S")

	if a_symmetric and b_symmetric:
		return socket_a == socket_b
	if a_symmetric or b_symmetric:
		return false

	var a_flipped = socket_a.ends_with("F")
	var b_flipped = socket_b.ends_with("F")
	var a_base = socket_a.trim_suffix("F")
	var b_base = socket_b.trim_suffix("F")

	if a_base != b_base:
		return false
	return a_flipped != b_flipped

func get_opposite_direction(direction: String) -> String:
	match direction:
		# Square
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
		# Hex flat-top (n/s)
		"n": return "s"
		"s": return "n"
		# Hex shared directions
		"ne": return "sw"
		"sw": return "ne"
		"se": return "nw"
		"nw": return "se"
		# Hex pointy-top (e/w)
		"e": return "w"
		"w": return "e"
		# Vertical
		"up": return "down"
		"down": return "up"
	return direction

# ===== 3D PREVIEW ===== #

func setup_3d_preview():
	viewport = SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport_container.add_child(viewport)

	preview_root = Node3D.new()
	preview_root.name = "PreviewRoot"
	viewport.add_child(preview_root)

	preview_camera = Camera3D.new()
	preview_root.add_child(preview_camera)
	update_camera_position()

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.2
	preview_root.add_child(light)

	var fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(30, -120, 0)
	fill_light.light_energy = 0.4
	preview_root.add_child(fill_light)

	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(10, 10)
	ground.mesh = plane_mesh
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.2, 0.2, 0.2, 0.5)
	ground_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ground.material_override = ground_mat
	ground.position.y = -0.5
	preview_root.add_child(ground)

func update_camera_position():
	if not preview_camera:
		return
	var h_rad = deg_to_rad(camera_angle_h)
	var v_rad = deg_to_rad(camera_angle_v)
	var x = camera_distance * cos(v_rad) * sin(h_rad)
	var y = camera_distance * sin(v_rad)
	var z = camera_distance * cos(v_rad) * cos(h_rad)
	preview_camera.position = Vector3(x, y, z)
	preview_camera.look_at(Vector3.ZERO)

func _on_viewport_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_orbiting = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = max(1.0, camera_distance - 0.5)
			update_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = min(20.0, camera_distance + 0.5)
			update_camera_position()
	elif event is InputEventMouseMotion and is_orbiting:
		var delta = event.position - last_mouse_pos
		last_mouse_pos = event.position
		camera_angle_h += delta.x * 0.5
		camera_angle_v = clamp(camera_angle_v - delta.y * 0.5, -89, 89)
		update_camera_position()

# ===== TILE MANAGEMENT ===== #

func _on_import_tiles():
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.filters = ["*.glb, *.gltf ; GLTF", "*.fbx ; FBX", "*.obj ; OBJ", "*.tscn ; Scenes"]
	file_dialog.files_selected.connect(_on_files_selected)
	file_dialog.canceled.connect(func(): file_dialog.queue_free())
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_files_selected(paths: PackedStringArray):
	for path in paths:
		import_tile(path)
	update_tile_list()
	for child in get_children():
		if child is FileDialog:
			child.queue_free()

func import_tile(path: String):
	var file_name = path.get_file().get_basename()
	var extension = path.get_extension().to_lower()
	var res_path = to_res_path(path)

	tile_library[file_name] = {
		"name": file_name,
		"file_path": res_path,
		"type": "3d",
		"format": extension,
		"weight": 1.0,
		"sockets": create_default_sockets()
	}
	print("Imported tile: ", file_name)

func to_res_path(path: String) -> String:
	if path.begins_with("res://"):
		return path
	var project_path = ProjectSettings.globalize_path("res://")
	var normalized_abs = path.replace("\\", "/")
	var normalized_proj = project_path.replace("\\", "/")
	if normalized_abs.begins_with(normalized_proj):
		return "res://" + normalized_abs.substr(normalized_proj.length())
	return path

func update_tile_list():
	tile_list.clear()
	for tile_name in tile_library:
		tile_list.add_item("🎲 " + tile_name)

func _on_remove_tile():
	var selected_items = tile_list.get_selected_items()
	if selected_items.is_empty():
		show_message("No tile selected to remove.")
		return

	var index = selected_items[0]
	var item_text = tile_list.get_item_text(index)
	var tile_name = item_text.substr(2).strip_edges()

	if tile_library.has(tile_name):
		tile_library.erase(tile_name)
		print("Removed tile: ", tile_name)

	# Clear preview if the removed tile was being displayed
	if current_tile == tile_name:
		current_tile = ""
		if current_tile_instance:
			current_tile_instance.queue_free()
			current_tile_instance = null
		update_socket_inputs()
		update_compatibility_display()

	update_tile_list()

func _on_tile_selected(index: int):
	var item_text = tile_list.get_item_text(index)
	current_tile = item_text.substr(2).strip_edges()
	load_tile_preview(current_tile)
	update_socket_inputs()
	update_compatibility_display()
func _add_highlight_to_preview():
	if highlight_cube:
		highlight_cube.queue_free()
	highlight_cube = HighlighCube.new()
	var aabb = get_combined_aabb(current_tile_instance)
	highlight_cube.extents = aabb.size / 2.0
	highlight_cube.position = aabb.get_center()
	highlight_cube.highlight_color = Color(0, 1, 1, 0.4)
	preview_root.add_child(highlight_cube)
func load_tile_preview(tile_name: String):
	if current_tile_instance:
		current_tile_instance.queue_free()
		current_tile_instance = null

	if not tile_library.has(tile_name):
		return

	var path = tile_library[tile_name]["file_path"]
	var resource = load(path)
	if not resource:
		return

	if resource is PackedScene:
		current_tile_instance = resource.instantiate()
	elif resource is Mesh:
		current_tile_instance = MeshInstance3D.new()
		current_tile_instance.mesh = resource
	else:
		return

	current_tile_instance.position = Vector3.ZERO
	preview_root.add_child(current_tile_instance)
	_add_highlight_to_preview()
	_update_highlight_faces()
	auto_fit_camera()
func _update_highlight_faces():
	if not highlight_cube:
		return
	if current_tile.is_empty() or not tile_library.has(current_tile):
		highlight_cube.set_socket_faces({})
		return

	var sockets = tile_library[current_tile].get("sockets", {})
	var faces: Dictionary = {}
	for direction in get_current_directions():
		var socket_val = sockets.get(direction, "-1")
		faces[direction] = {
			"color": DIRECTION_COLORS.get(direction, Color.WHITE),
			"socket": socket_val,
		}
	highlight_cube.set_socket_faces(faces)
func auto_fit_camera():
	if not current_tile_instance:
		return
	var aabb = get_combined_aabb(current_tile_instance)
	if aabb.size.length() > 0:
		camera_distance = aabb.size.length() * 2.0
		update_camera_position()

func get_combined_aabb(node: Node3D) -> AABB:
	var combined = AABB()
	var first = true
	if node is MeshInstance3D and node.mesh:
		combined = node.mesh.get_aabb()
		first = false
	for child in node.get_children():
		if child is Node3D:
			var child_aabb = get_combined_aabb(child)
			if child_aabb.size != Vector3.ZERO:
				combined = child_aabb if first else combined.merge(child_aabb)
				first = false
	return combined

# ===== SAVE/LOAD ===== #

func _on_save_tileset():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = ["*.json ; JSON"]
	dialog.current_file = "tileset.json"
	dialog.file_selected.connect(_save_to_file)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))

func _save_to_file(path: String):
	var data = {
		"grid_type": grid_type,
		"hex_orientation": hex_orientation,
		"tile_size": tile_size,
		"tile_spacing": tile_spacing,
		"tiles": tile_library
	}
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()
	for child in get_children():
		if child is FileDialog:
			child.queue_free()

func _on_load_tileset():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = ["*.json ; JSON"]
	dialog.file_selected.connect(_load_from_file)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))

func _load_from_file(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	file.close()
	var data = json.get_data()

	grid_type = data.get("grid_type", "square")
	hex_orientation = data.get("hex_orientation", "pointy")
	grid_size_x = data.get("grid_size", {}).get("x", 20)
	grid_size_y = data.get("grid_size", {}).get("y", 20)
	grid_size_z = data.get("grid_size", {}).get("z", 1)
	tile_size = data.get("tile_size", 2.0)
	tile_spacing = data.get("tile_spacing", 0.0)
	tile_library = data.get("tiles", {})

	# Update toolbar spinbox values
	_update_toolbar_spinboxes()

	print("Loaded tileset - Grid: %s, Hex orientation: %s, Spacing: %s" % [grid_type, hex_orientation, tile_spacing])
	rebuild_socket_editor()
	update_tile_list()

	for child in get_children():
		if child is FileDialog:
			child.queue_free()

func _update_toolbar_spinboxes():
	# Update the tile size and spacing spinboxes in the toolbar
	for child in toolbar.get_children():
		if child is SpinBox:
			if child.name == "TileSizeSpin":
				child.value = tile_size
			elif child.name == "TileSpacingSpin":
				child.value = tile_spacing
		elif child is OptionButton:
			# Update grid type dropdown based on loaded values
			if grid_type == "square":
				child.selected = 0
			elif grid_type == "hex" and hex_orientation == "pointy":
				child.selected = 1
			elif grid_type == "hex" and hex_orientation == "flat":
				child.selected = 2

# ===== WFC ===== #

func _on_run_wfc():
	if not wfc_generator:
		show_message("WFC Generator not available!")
		return
	if tile_library.size() == 0:
		show_message("No tiles imported!")
		return

	var tileset_data = convert_sockets_to_neighbors()
	tileset_data["grid_type"] = grid_type
	tileset_data["hex_orientation"] = hex_orientation
	tileset_data["tile_size"] = tile_size
	tileset_data["tile_spacing"] = tile_spacing

	wfc_generator.grid_size = Vector3i(grid_size_x, grid_size_y, grid_size_z)
	wfc_generator.run_wfc(tileset_data)

func convert_sockets_to_neighbors() -> Dictionary:
	var result = {"tiles": {}}
	for tile_name in tile_library:
		var tile_data = tile_library[tile_name].duplicate(true)
		var neighbors = {}
		for direction in get_current_directions():
			neighbors[direction] = []
			for other_tile in tile_library:
				if can_connect(tile_name, direction, other_tile):
					neighbors[direction].append({
						"tile": other_tile,
						"via": get_opposite_direction(direction)
					})
		tile_data["neighbors"] = neighbors
		result["tiles"][tile_name] = tile_data
	return result
# Display a simple message dialog
func show_message(text: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
