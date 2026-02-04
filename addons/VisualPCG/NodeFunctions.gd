extends RefCounted

class_name NodeFunctions

static func _open_files(ParentNode: Node,callback: Callable):

		var file_dialog = FileDialog.new()
		file_dialog.title = "Import 2D/3D Assets"
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES  # Allow multiple files
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.use_native_dialog = false

		# Set filters for tile images
		file_dialog.add_filter("*.png", "PNG Images")
		file_dialog.add_filter("*.jpg,*.jpeg", "JPEG Images")
		file_dialog.add_filter("*.svg", "SVG Images")
		file_dialog.add_filter("*.tscn", "Godot Scenes")
		file_dialog.add_filter("*.fbx", "FBX Files")
		file_dialog.add_filter("*.obj", "OBJ Files")
		file_dialog.add_filter("*.glb,*.gltf", "GLTF/GLB Files")
		file_dialog.files_selected.connect(callback)
		ParentNode.add_child(file_dialog)
		file_dialog.popup_centered(Vector2i(900,700))
		file_dialog.close_requested.connect(func(): file_dialog.queue_free())
		file_dialog.canceled.connect(func(): file_dialog.queue_free())
		return file_dialog
