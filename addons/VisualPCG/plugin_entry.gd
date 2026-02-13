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


func _on_wfc_generation_complete(grid_res: Array) -> void:
	print("WFC Generation Completed")
	if grid_res.size() > 0 and grid_res[0] is Array and grid_res[0].size() > 0:
		print("Generated grid %dx%dx%d" % [grid_res[0][0].size(), grid_res[0].size(), grid_res.size()])
	create_level_scene(grid_res)


func _on_wfc_generation_failed(error) -> void:
	# Handle both dictionary (new format) and string (legacy format) errors
	if error is Dictionary:
		show_detailed_error_dialog(error)
	else:
		# Legacy string error
		push_error("WFC Generation Failed: %s" % str(error))
		var error_dialog = AcceptDialog.new()
		error_dialog.dialog_text = "WFC Generation Failed:\n" + str(error)
		error_dialog.title = "Generation Error"
		get_editor_interface().get_base_control().add_child(error_dialog)
		error_dialog.popup_centered()
		error_dialog.confirmed.connect(func(): error_dialog.queue_free())


func show_detailed_error_dialog(error: Dictionary) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "WFC Generation Failed"
	dialog.dialog_hide_on_ok = true

	var main_container = VBoxContainer.new()
	main_container.custom_minimum_size = Vector2(550, 400)

	# Error title with icon
	var title_hbox = HBoxContainer.new()
	var title = Label.new()
	title.text = "❌ " + error.get("message", "Unknown Error")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	title_hbox.add_child(title)
	main_container.add_child(title_hbox)

	main_container.add_child(HSeparator.new())

	# Progress info (if available)
	if error.has("progress"):
		var progress_hbox = HBoxContainer.new()
		var progress_label = Label.new()
		var pct = error["progress"] * 100
		progress_label.text = "📊 Progress before failure: %.1f%% (%d/%d cells collapsed)" % [
			pct,
			error.get("collapsed_count", 0),
			error.get("total_cells", 0)
		]
		progress_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		progress_hbox.add_child(progress_label)
		main_container.add_child(progress_hbox)
		main_container.add_child(HSeparator.new())

	# Details section
	var details_title = Label.new()
	details_title.text = "📋 Details:"
	details_title.add_theme_font_size_override("font_size", 14)
	main_container.add_child(details_title)

	var details_scroll = ScrollContainer.new()
	details_scroll.custom_minimum_size.y = 100
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var details_text = RichTextLabel.new()
	details_text.bbcode_enabled = true
	details_text.fit_content = true
	details_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_text.text = error.get("details", "No details available")
	details_scroll.add_child(details_text)
	main_container.add_child(details_scroll)

	main_container.add_child(HSeparator.new())

	# Suggestions section
	var suggestions = error.get("suggestions", [])
	if suggestions.size() > 0:
		var suggest_title = Label.new()
		suggest_title.text = "💡 How to fix:"
		suggest_title.add_theme_font_size_override("font_size", 14)
		suggest_title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		main_container.add_child(suggest_title)

		var suggest_container = VBoxContainer.new()
		for i in range(suggestions.size()):
			var suggestion = suggestions[i]
			var s_label = Label.new()
			s_label.text = "%d. %s" % [i + 1, suggestion]
			s_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			suggest_container.add_child(s_label)
		main_container.add_child(suggest_container)

	# Problematic tiles section
	var prob_tiles = error.get("problematic_tiles", {})
	if prob_tiles.size() > 0:
		main_container.add_child(HSeparator.new())

		var prob_title = Label.new()
		prob_title.text = "⚠️ Tiles that caused conflicts:"
		prob_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		main_container.add_child(prob_title)

		# Sort tiles by conflict count
		var sorted_tiles = []
		for t in prob_tiles:
			sorted_tiles.append({"name": t, "count": prob_tiles[t]})
		sorted_tiles.sort_custom(func(a, b): return a["count"] > b["count"])

		var tiles_container = VBoxContainer.new()
		var max_to_show = min(5, sorted_tiles.size())
		for i in range(max_to_show):
			var t = sorted_tiles[i]
			var t_label = Label.new()
			t_label.text = "  • %s (%d conflicts)" % [t["name"], t["count"]]
			tiles_container.add_child(t_label)

		if sorted_tiles.size() > 5:
			var more_label = Label.new()
			more_label.text = "  ... and %d more" % (sorted_tiles.size() - 5)
			more_label.add_theme_color_override("font_color", Color.GRAY)
			tiles_container.add_child(more_label)

		main_container.add_child(tiles_container)

	dialog.add_child(main_container)
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(600, 500))
	dialog.confirmed.connect(func(): dialog.queue_free())

	# Also print to console for logging
	print("=== WFC GENERATION FAILED ===")
	print("Error: ", error.get("message", "Unknown"))
	print("Details: ", error.get("details", ""))
	for suggestion in suggestions:
		print("  Suggestion: ", suggestion)
	print("=============================")


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
