extends CharacterBody3D
@export var camera: Camera3D
@export var camera_pivot: Node3D
@export var mouse_sensitivity:float = 0.002
const SPEED = 15.0
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$AnimationPlayer.play("idle")
func _physics_process(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		if $AnimationPlayer.current_animation != "weapon_inspect" and $AnimationPlayer.current_animation != "weapon_inspect2" and $AnimationPlayer.current_animation != "walk":
			$AnimationPlayer.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		if $AnimationPlayer.current_animation != "weapon_inspect" and $AnimationPlayer.current_animation != "weapon_inspect2" and $AnimationPlayer.current_animation != "idle":
			$AnimationPlayer.play("idle")

	move_and_slide()
func _input(event):
		# if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		# 	var displays = get_tree().get_nodes_in_group("display")

		# 	for display in displays:

		# 		var parent = display.get_parent()
		# 		print(parent.name)
		# 		if parent is Node3D:
		# 			var dist = global_position.distance_to(parent.global_position)
		# 			var distance = 20.0 if parent.is_in_group("vase") else 15.0
		# 			if dist < distance:
		# 				if display.is_in_group("door"):
		# 					# var overlay = preload("res://inspect_overlay.tscn").instantiate()
		# 					get_tree().root.add_child(overlay)
		# 					var mesh = parent.mesh if "mesh" in parent else null
		# 					var text_info = ""
		# 					if display.has_node("TextEdit"):
		# 						text_info = display.get_node("TextEdit").text
		# 					elif display.has_node("ColorRect") and display.get_node("ColorRect") is TextEdit:
		# 						text_info = display.get_node("ColorRect").text

		# 					var item_scale = parent.scale
		# 					overlay.setup(mesh, item_scale, text_info)
		# 					return

		# 				display.visible = not display.visible
		# 				var player = get_tree().get_current_scene().get_node("Player")
		# 				player.get_node("PlayerUI").get_node("TextEdit").visible = not display.visible
		# 				if display.visible:
		# 					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# 					if parent.name == "SwordOfVictory":
		# 						player.get_node("AnimationPlayer").play("weapon_inspect2")

		# 					elif parent.name == "BronzeSword":
		# 						player.get_node("AnimationPlayer").play("weapon_inspect")
		# 					elif parent.name == "ScaredText":
		# 						parent.get_node("Text").get_node("AnimationPlayer").play("Sutra Container Opening")
		# 				else:
		# 					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		# 					player.get_node("AnimationPlayer").stop()
		# 					player.get_node("BronzeSword").visible = false
		# 					player.get_node("SwordVictory").visible = false
		if event is InputEventKey and Input.is_action_pressed("wave"):
			$AnimationPlayer.play("wave")
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				# Early return so mouse motion doesn't process while menu is open
				return
		# Ignore mouse input when menu visible
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			return

		if event is InputEventMouseMotion:
			_handle_mouse_look(event)


func _handle_mouse_look(event):
	rotate_y(-event.relative.x * mouse_sensitivity)
	# Pitch: rotate camera pivot only
	camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
	camera_pivot.rotation.x = clamp(
		camera_pivot.rotation.x,
		deg_to_rad(-80),
		deg_to_rad(80)
	)
