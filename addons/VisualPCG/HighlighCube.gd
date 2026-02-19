@tool
extends Node3D
class_name HighlighCube

@export var extents: Vector3 = Vector3(1, 1, 1): set = _set_extents
@export var highlight_color: Color = Color(1, 0, 0, 0.8): set = _set_color

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D

func _set_extents(value):
    extents = value
    _rebuild_wireframe()

func _set_color(value):
    highlight_color = value
    if _material:
        _material.albedo_color = highlight_color

func _ready():
    _material = StandardMaterial3D.new()
    _material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _material.albedo_color = highlight_color
    _material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _material.no_depth_test = true  # Always visible through geometry

    _mesh_instance = MeshInstance3D.new()
    _mesh_instance.material_override = _material
    add_child(_mesh_instance)
    _rebuild_wireframe()

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
    # Front face
    for pair in [[0,1],[1,2],[2,3],[3,0]]:
        im.surface_add_vertex(verts[pair[0]])
        im.surface_add_vertex(verts[pair[1]])
    # Back face
    for pair in [[4,5],[5,6],[6,7],[7,4]]:
        im.surface_add_vertex(verts[pair[0]])
        im.surface_add_vertex(verts[pair[1]])
    # Connecting edges
    for pair in [[0,4],[1,5],[2,6],[3,7]]:
        im.surface_add_vertex(verts[pair[0]])
        im.surface_add_vertex(verts[pair[1]])
    im.surface_end()
    _mesh_instance.mesh = im
