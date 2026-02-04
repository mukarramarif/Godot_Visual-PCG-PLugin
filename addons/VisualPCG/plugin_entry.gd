@tool
extends EditorPlugin

var pcg_editor_panel: Control
var pcg_dock: Control
var wfc_generator: Node
func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	var pcg_editor_scene = preload("res://addons/VisualPCG/PcgEditScene.tscn")
	pcg_editor_panel = pcg_editor_scene.instantiate()
	wfc_generator = preload("WaveFuncCollapse.gd").new()
	add_child(wfc_generator)
	add_control_to_bottom_panel(pcg_editor_panel, "PCG Visual")
	if pcg_editor_panel.has_method("set_wfc_generator"):
		print("Setting WFC Generator in PCG Editor Panel")
		pcg_editor_panel.set_wfc_generator(wfc_generator)
	else:
		print("PCG Editor Panel does not have set_wfc_generator method")
	# pcg_editor_panel.call_deferred("set_wfc_generator", wfc_generator)
	if wfc_generator.has_signal("generation_completed"):
		wfc_generator.generation_completed.connect(_on_wfc_generation_complete)

	if wfc_generator.has_signal("generation_failed"):
		wfc_generator.generation_failed.connect(_on_wfc_generation_failed)




func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	if pcg_editor_panel:
		remove_control_from_bottom_panel(pcg_editor_panel)
		pcg_editor_panel.queue_free()
	if wfc_generator:
		wfc_generator.queue_free()
	pass
func _on_wfc_generation_complete(grid_res: Array) -> void:
	print("WFC Generation Completed")
	print("Generated grid %dx%d" % [grid_res.size(), grid_res[0].size()])
func _on_wfc_generation_failed(error: String) -> void:
	push_error("WFC Generation Failed: %s" % error)
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = "WFC Generation Failed:\n" + error
	error_dialog.title = "Generation Error"
	get_editor_interface().get_base_control().add_child(error_dialog)
	error_dialog.popup_centered()
	error_dialog.confirmed.connect(func(): error_dialog.queue_free())
func create_level_scene(grid: Array):
	if not wfc_generator:
		return

	# Create new scene
	var level_root = Node3D.new()
	level_root.name = "GeneratedLevel"

	# Instantiate tiles
	wfc_generator.instantiate_tiles_in_world(level_root, 2.0)

	# Save as scene
	var packed_scene = PackedScene.new()
	packed_scene.pack(level_root)

	var save_path = "res://generated_levels/level_%s.tscn" % Time.get_datetime_string_from_system().replace(":", "-")

	# Create directory if needed
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("generated_levels"):
		dir.make_dir("generated_levels")

	var error = ResourceSaver.save(packed_scene, save_path)

	if error == OK:
		print("Level scene saved to: " + save_path)

		# Open in editor
		get_editor_interface().open_scene_from_path(save_path)
	else:
		push_error("Failed to save level scene")
