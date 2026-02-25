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
# holds the geometry definitions for the shape faces
enum Shapes { CUBE, HEX }

# Face geometry definitions for a unit cube
# QuadMesh default: lies in XY plane, normal facing +Z
const FACE_DEFS = {
	"south": {
		"offset_dir": Vector3(0, 0, 1),
		"rotation": Vector3(0, 0, 0),
		"size_axes": [0, 1],
	},
	"north": {
		"offset_dir": Vector3(0, 0, -1),
		"rotation": Vector3(0, 180, 0),
		"size_axes": [0, 1],
	},
	"east": {
		"offset_dir": Vector3(1, 0, 0),
		"rotation": Vector3(0, -90, 0),
		"size_axes": [2, 1],
	},
	"west": {
		"offset_dir": Vector3(-1, 0, 0),
		"rotation": Vector3(0, 90, 0),
		"size_axes": [2, 1],
	},
	"up": {
		"offset_dir": Vector3(0, 1, 0),
		"rotation": Vector3(90, 0, 0),
		"size_axes": [0, 2],
	},
	"down": {
		"offset_dir": Vector3(0, -1, 0),
		"rotation": Vector3(-90, 0, 0),
		"size_axes": [0, 2],
	},
}

# Hex face definitions — keys match the socket direction names.
# Side faces have "angle_deg": the outward-normal angle measured from +X,
# counterclockwise in the XZ plane (where -Z = north).
# Geometry is pointy-top: vertices at 30+60*i, face normals at 60*i.
const HEX_FACE_DEFS = {
	"e":  { "angle_deg": 0.0 },
	"ne": { "angle_deg": 60.0 },
	"nw": { "angle_deg": 120.0 },
	"w":  { "angle_deg": 180.0 },
	"sw": { "angle_deg": 240.0 },
	"se": { "angle_deg": 300.0 },
	"up":   { "offset_dir": Vector3(0, 1, 0) },
	"down": { "offset_dir": Vector3(0, -1, 0) },
}

# How much to shrink face quads so the wireframe edges stay visible
const FACE_INSET: float = 0.9

func _set_shape(value):
	shape = value
	_rebuild_wireframe()
	_rebuild_faces()

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

# --- Hex helpers ---

## Derive the hex circumradius (center-to-vertex) from the AABB extents.
## For a pointy-top hex: AABB width = R*sqrt(3), AABB depth = 2*R
## so extents.x = R*sqrt(3)/2, extents.z = R.
## We take whichever is larger to fully enclose the mesh.
func _get_hex_circumradius() -> float:
	var r_from_z = extents.z
	var r_from_x = extents.x * 2.0 / sqrt(3.0)
	return max(r_from_z, r_from_x)

## Return the 6 hex vertex positions for one ring at the given y height.
## Pointy-top: vertices at 30 + 60*i degrees.
func _hex_ring(y: float, R: float) -> Array:
	var verts = []
	for i in range(6):
		var angle = deg_to_rad(30.0 + 60.0 * i)
		verts.append(Vector3(cos(angle) * R, y, -sin(angle) * R))
	return verts

# --- Public API ---

func set_socket_faces(faces_dict: Dictionary, shape_value):
	shape = shape_value
	socket_faces = faces_dict
	_rebuild_wireframe()
	_rebuild_faces()

func highlight_direction(direction: String, highlighted: bool):
	if _face_instances.has(direction):
		var mi: MeshInstance3D = _face_instances[direction]
		var mat: StandardMaterial3D = mi.material_override
		mat.albedo_color.a = 0.7 if highlighted else 0.35

# --- Wireframe ---

func _rebuild_wireframe():
	if not _mesh_instance:
		return
	match shape:
		Shapes.HEX:
			_rebuild_wireframe_hex()
		_:
			_rebuild_wireframe_cube()

func _rebuild_wireframe_cube():
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
	var R = _get_hex_circumradius()
	var top = _hex_ring(extents.y, R)
	var bot = _hex_ring(-extents.y, R)

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	# Top hexagon ring
	for i in range(6):
		im.surface_add_vertex(top[i])
		im.surface_add_vertex(top[(i + 1) % 6])
	# Bottom hexagon ring
	for i in range(6):
		im.surface_add_vertex(bot[i])
		im.surface_add_vertex(bot[(i + 1) % 6])
	# 6 vertical pillars
	for i in range(6):
		im.surface_add_vertex(top[i])
		im.surface_add_vertex(bot[i])
	im.surface_end()
	_mesh_instance.mesh = im

# --- Face quad rendering ---

func _rebuild_faces():
	for key in _face_instances:
		if is_instance_valid(_face_instances[key]):
			_face_instances[key].queue_free()
	_face_instances.clear()
	var face_defs = FACE_DEFS if shape == Shapes.CUBE else HEX_FACE_DEFS

	for direction in socket_faces:
		var face_data = socket_faces[direction]
		var socket_value: String = face_data.get("socket", "-1")
		if socket_value == "-1" or socket_value.is_empty():
			continue

		var face_def = face_defs.get(direction)
		if not face_def:
			continue

		var color: Color = face_data.get("color", Color.WHITE)
		_create_face_quad(direction, face_def, color)

func _create_face_quad(direction: String, face_def: Dictionary, color: Color):
	# Material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true

	# MeshInstance
	var mi = MeshInstance3D.new()
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
		# --- Side rectangle ---
		var R = _get_hex_circumradius()
		var apothem = R * sqrt(3.0) / 2.0
		var edge_len = R  # side length of a regular hex = circumradius
		var quad = QuadMesh.new()
		quad.size = Vector2(edge_len * FACE_INSET, extents.y * 2.0 * FACE_INSET)
		mi.mesh = quad

		var angle_rad = deg_to_rad(face_def["angle_deg"])
		# Position at apothem distance along the outward face normal
		mi.position = Vector3(
			cos(angle_rad) * apothem,
			0.0,
			-sin(angle_rad) * apothem
		)
		# Rotate so the quad's +Z normal faces outward along the face normal
		# Ry(alpha) maps +Z to (sin(alpha), 0, cos(alpha))
		# We need (cos(theta), 0, -sin(theta)), which gives alpha = 90 + theta
		mi.rotation_degrees = Vector3(0, 90.0 + face_def["angle_deg"], 0)
	else:
		# --- Top / bottom hexagon fan ---
		var R = _get_hex_circumradius() * FACE_INSET
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var y = face_def["offset_dir"].y * extents.y
		var center = Vector3(0, y, 0)
		for i in range(6):
			var a1 = deg_to_rad(30.0 + 60.0 * i)
			var a2 = deg_to_rad(30.0 + 60.0 * (i + 1))
			st.add_vertex(center)
			st.add_vertex(Vector3(cos(a1) * R, y, -sin(a1) * R))
			st.add_vertex(Vector3(cos(a2) * R, y, -sin(a2) * R))
		mi.mesh = st.commit()
