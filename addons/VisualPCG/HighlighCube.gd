@tool
extends Node3D
class_name HighlighCube

@export var extents: Vector3 = Vector3(1, 1, 1): set = _set_extents
@export var highlight_color: Color = Color(1, 0, 0, 0.8): set = _set_color

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
@export var shape: int = Shapes.CUBE
# --- Per-face socket coloring ---
# Stores direction -> { "color": Color, "socket": String }
var socket_faces: Dictionary = {}
# Holds references to the face MeshInstance3D nodes so we can clear them
var _face_instances: Dictionary = {}
# holds the geometry definitons for the shape faces - used to position/rotate the face quads correctly
enum Shapes { CUBE, HEX }
# Face geometry definitions for a unit cube
# "offset_axis" and "rotation" orient the quad onto the correct face
# QuadMesh default: lies in XY plane, normal facing +Z
const FACE_DEFS = {
	"south": {
		"offset_dir": Vector3(0, 0, 1),
		"rotation": Vector3(0, 0, 0),
		"size_axes": [0, 1],        # quad uses extents.x and extents.y
	},
	"north": {
		"offset_dir": Vector3(0, 0, -1),
		"rotation": Vector3(0, 180, 0),
		"size_axes": [0, 1],
	},
	"east": {
		"offset_dir": Vector3(1, 0, 0),
		"rotation": Vector3(0, -90, 0),
		"size_axes": [2, 1],        # quad uses extents.z and extents.y
	},
	"west": {
		"offset_dir": Vector3(-1, 0, 0),
		"rotation": Vector3(0, 90, 0),
		"size_axes": [2, 1],
	},
	"up": {
		"offset_dir": Vector3(0, 1, 0),
		"rotation": Vector3(90, 0, 0),
		"size_axes": [0, 2],        # quad uses extents.x and extents.z
	},
	"down": {
		"offset_dir": Vector3(0, -1, 0),
		"rotation": Vector3(-90, 0, 0),
		"size_axes": [0, 2],
	},

}
const HEX_FACE_DEFS = {
	"south": {
		"offset_dir": Vector3(0, 0, 1),
		"rotation": Vector3(0, 0, 0),
		"size_axes": [0, 1],        # quad uses extents.x and extents.y
	},
	"north": {
		"offset_dir": Vector3(0, 0, -1),
		"rotation": Vector3(0, 180, 0),
		"size_axes": [0, 1],
	},
	"east": {
		"offset_dir": Vector3(1, 0, 0),
		"rotation": Vector3(0, -90, 0),
		"size_axes": [2, 1],        # quad uses extents.z
	},
	"west": {
		"offset_dir": Vector3(-1, 0, 0),
		"rotation": Vector3(0, 90, 0),
		"size_axes": [2, 1],
	},
	"up": {
		"offset_dir": Vector3(0, 1, 0),
		"rotation": Vector3(90, 0, 0),
		"size_axes": [0, 2],        # quad uses extents.x and extents.z
	},
	"down": {
		"offset_dir": Vector3(0, -1, 0),
		"rotation": Vector3(-90, 0, 0),
		"size_axes": [0, 2],
	},
	"northeast": {
		"offset_dir": Vector3(1, 0, 1),
		"rotation": Vector3(0, -45, 0),
		"size_axes": [2, 1],        # quad uses extents.z
	},
	"northwest": {
		"offset_dir": Vector3(-1, 0, 1),
		"rotation": Vector3(0, 45, 0),
		"size_axes": [2, 1],
	},
	"southeast": {
		"offset_dir": Vector3(1, 0, -1),
		"rotation": Vector3(0, -135, 0),
		"size_axes": [2, 1],
	},
	"southwest": {
		"offset_dir": Vector3(-1, 0, -1),
		"rotation": Vector3(0, 135, 0),
		"size_axes": [2, 1],
	},
}
# How much to shrink face quads so the wireframe edges stay visible
const FACE_INSET: float = 0.9

func _set_shape(value):
	shape = value
	_rebuild_wireframe()
	_rebuild_faces()
	# Note: we keep the same face defs for both shapes, so no need to rebuild faces here
func _set_extents(value):
	extents = value
	_rebuild_wireframe()
	_rebuild_faces()

func _set_color(value):
	highlight_color = value
	if _material:
		_material.albedo_color = highlight_color

func _ready():
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = highlight_color
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.material_override = _material
	add_child(_mesh_instance)
	_rebuild_wireframe()

# --- Public API ---

## Call this to update which faces are colored.
## faces_dict maps direction name -> { "color": Color, "socket": String }
## Directions with socket "-1" or missing are hidden.
func set_socket_faces(faces_dict: Dictionary, shape_value):
	shape = shape_value
	socket_faces = faces_dict
	_rebuild_faces()

## Convenience: highlight a single direction (e.g. on hover/focus)
func highlight_direction(direction: String, highlighted: bool):
	if _face_instances.has(direction):
		var mi: MeshInstance3D = _face_instances[direction]
		var mat: StandardMaterial3D = mi.material_override
		mat.albedo_color.a = 0.7 if highlighted else 0.35

# --- Wireframe ---

func _rebuild_wireframe():
	if not _mesh_instance:
		return
	var im = ImmediateMesh.new()
	var e = extents
	var verts = [
		Vector3( e.x,  e.y,  e.z), Vector3(-e.x,  e.y,  e.z),
		Vector3(-e.x, -e.y,  e.z), Vector3( e.x, -e.y,  e.z),
		Vector3( e.x,  e.y, -e.z), Vector3(-e.x,  e.y, -e.z),
		Vector3(-e.x, -e.y, -e.z), Vector3( e.x, -e.y, -e.z),
	]
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for pair in [[0,1],[1,2],[2,3],[3,0]]:
		im.surface_add_vertex(verts[pair[0]])
		im.surface_add_vertex(verts[pair[1]])
	for pair in [[4,5],[5,6],[6,7],[7,4]]:
		im.surface_add_vertex(verts[pair[0]])
		im.surface_add_vertex(verts[pair[1]])
	for pair in [[0,4],[1,5],[2,6],[3,7]]:
		im.surface_add_vertex(verts[pair[0]])
		im.surface_add_vertex(verts[pair[1]])
	im.surface_end()
	_mesh_instance.mesh = im
func _rebuild_wireframe_hex():
	if not _mesh_instance:
		return
	var im = ImmediateMesh.new()
	var e = extents
	var h = e.x * 0.5
	var verts = [
		Vector3( 0,  e.y,  e.z), Vector3(-h,  e.y,  e.z * 0.5), Vector3(-h,  e.y, -e.z * 0.5),
		Vector3( 0,  e.y, -e.z), Vector3( h,  e.y, -e.z * 0.5), Vector3( h,  e.y,  e.z * 0.5),
		Vector3( 0, -e.y,  e.z), Vector3(-h, -e.y,  e.z * 0.5), Vector3(-h, -e.y, -e.z * 0.5),
		Vector3( 0, -e.y, -e.z), Vector3( h, -e.y, -e.z * 0.5), Vector3( h, -e.y,  e.z * 0.5),
	]
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for pair in [[0,1],[1,2],[2,3],[3,4],[4,5],[5,0]]:
		im.surface_add_vertex(verts[pair[0]])
		im.surface_add_vertex(verts[pair[1]])
	for pair in [[6,7],[7,8],[8,9],[9,10],[10,11],[11,6]]:
		im.surface_add_vertex(verts[pair[0]])
		im.surface_add_vertex(verts[pair[1]])
	for i in range(6):
		im.surface_add_vertex(verts[i])
		im.surface_add_vertex(verts[i + 6])
	im.surface_end()
	_mesh_instance.mesh = im
# --- Face quad rendering ---

func _rebuild_faces():
	# Remove old face quads
	for key in _face_instances:
		if is_instance_valid(_face_instances[key]):
			_face_instances[key].queue_free()
	_face_instances.clear()
<<<<<<< Updated upstream

=======
	var face_defs = FACE_DEFS if shape == Shapes.CUBE else HEX_FACE_DEFS
>>>>>>> Stashed changes
	# Build new ones for each active socket direction
	for direction in socket_faces:
		var face_data = socket_faces[direction]
		var socket_value: String = face_data.get("socket", "-1")
		if socket_value == "-1" or socket_value.is_empty():
			continue  # Don't draw disabled sockets

		var face_def = face_defs.get(direction)
		if not face_def:
			continue  # Skip directions we don't have geometry for (hex sides)

		var color: Color = face_data.get("color", Color.WHITE)
		_create_face_quad(direction, face_def, color)

func _create_face_quad(direction: String, face_def: Dictionary, color: Color):
	var e_array = [extents.x, extents.y, extents.z]
	var size_x = e_array[face_def["size_axes"][0]] * 2.0 * FACE_INSET
	var size_y = e_array[face_def["size_axes"][1]] * 2.0 * FACE_INSET

	# Mesh
	var quad = QuadMesh.new()
	quad.size = Vector2(size_x, size_y)

	# Material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true

	# MeshInstance
	var mi = MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.name = "Face_" + direction

	match shape:
		Shapes.CUBE:
			_setup_cube_face(mi, face_def)
		Shapes.HEX:
			_setup_hex_face(mi, face_def)
	add_child(mi)
	_face_instances[direction] = mi
func _setup_cube_face(mi: MeshInstance3D, face_def: Dictionary):

	var e_array = [extents.x, extents.y, extents.z]
	var size_x = e_array[face_def["size_axes"][0]] * 2.0 * FACE_INSET
	var size_y = e_array[face_def["size_axes"][1]] * 2.0 * FACE_INSET
	var quad = QuadMesh.new()
	quad.size = Vector2(size_x, size_y)
	mi.mesh = quad
	var offset_dir: Vector3 = face_def["offset_dir"]
	mi.position = offset_dir * Vector3(extents.x, extents.y, extents.z) * abs(offset_dir)
	mi.rotation_degrees = face_def["rotation"]

func _setup_hex_face(mi: MeshInstance3D, face_def: Dictionary):

	if face_def.has("angle_deg"):
		# Side rectangle
		var quad = QuadMesh.new()
		quad.size = Vector2(extents.x * FACE_INSET, extents.y * 2.0 * FACE_INSET)
		mi.mesh = quad
		var angle = deg_to_rad(face_def["angle_deg"])
		var apothem = extents.x * sqrt(3.0) / 2.0
		mi.position = Vector3(cos(angle) * apothem, 0.0, sin(angle) * apothem)
		mi.rotation_degrees = Vector3(0, -face_def["angle_deg"], 0)
	else:
		# Top / bottom hexagon fan
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var y = face_def["offset_dir"].y * extents.y
		var center = Vector3(0, y, 0)
		for i in range(6):
			var a1 = deg_to_rad(60.0 * i)
			var a2 = deg_to_rad(60.0 * (i + 1))
			st.add_vertex(center)
			st.add_vertex(Vector3(cos(a1) * extents.x * FACE_INSET, y, sin(a1) * extents.x * FACE_INSET))
			st.add_vertex(Vector3(cos(a2) * extents.x * FACE_INSET, y, sin(a2) * extents.x * FACE_INSET))
		mi.mesh = st.commit()
