@tool
extends Control

var graph_edit: GraphEdit
var add_node_menu: PopupMenu
var toolbar: HBoxContainer
var mouse_pos_for_new_node: Vector2
## This following AST structure for nodes we will execute them i.e i figure that out
func _ready() -> void:
	setup_ui()
	setup_graph_edit()
	setup_toolbar()
func setup_ui():
	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	add_child(vbox)
	
	toolbar = HBoxContainer.new()
	toolbar.custom_minimum_size.y = 40
	vbox.add_child(toolbar)
	
	graph_edit = GraphEdit.new()
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(graph_edit)
	
func setup_graph_edit():
	graph_edit.right_disconnects = true
	graph_edit.show_zoom_label = true
	graph_edit.minimap_enabled = true
	graph_edit.minimap_opacity = 0.5

	
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	graph_edit.popup_request.connect(_on_popup_request)
	graph_edit.gui_input.connect(_on_graph_gui_input)
func setup_toolbar():
	var title_label= Label.new()
	title_label.text = "Wave Function Collapse"
	title_label.add_theme_font_size_override("font_size",16)
	toolbar.add_child(title_label)
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
	
	var save_btn = Button.new()
	save_btn.text = "Save Tileset"
	save_btn.pressed.connect(_on_save_tileset)
	toolbar.add_child(save_btn)
	
	var load_btn = Button.new()
	load_btn.text = "Load Tileset"
	load_btn.pressed.connect(_on_load_tileset)
	toolbar.add_child(load_btn)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	
	var validate_btn = Button.new()
	validate_btn.text = "Validate Rules"
	validate_btn.pressed.connect(_on_validate_rules)
	toolbar.add_child(validate_btn)
#toolbar functions
func _on_validate_rules():
	return null
func _on_save_tileset():
	return null
func _on_new_tile():
	return null
func _on_load_tileset():
	return null
func _on_import_tiles():
	return null
# Signal handlers
func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	# Validate connection types here if needed
	var from_node_obj = graph_edit.get_node(NodePath(from_node))
	var to_node_obj = graph_edit.get_node(NodePath(to_node))
	
	# Simple type checking (you can expand this)
	graph_edit.connect_node(from_node, from_port, to_node, to_port)
	_on_execute_graph()

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_on_execute_graph()

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
