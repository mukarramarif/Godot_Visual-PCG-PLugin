@tool
extends EditorPlugin

var pcg_editor_panel: Control
var pcg_dock: Control
func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	var pcg_editor_scene = preload("res://addons/VisualPCG/PcgEditScene.tscn")
	pcg_editor_panel = pcg_editor_scene.instantiate()
	add_control_to_bottom_panel(pcg_editor_panel, "PCG Visual")
	


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	if pcg_editor_panel:
		remove_control_from_bottom_panel(pcg_editor_panel)
		pcg_editor_panel.queue_free()
	pass
