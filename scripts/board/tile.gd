extends StaticBody3D

@export var coord: Vector2i = Vector2i.ZERO
@export var is_blocked: bool = false
@export var tile_size: float = 1.0
@export var thickness: float = 0.2
@export var hover_outline_color: Color = Color.html("#FFD24D") # outline color (hex)
@export var hover_outline_alpha := 0.85
@export var hover_outline_y_offset := 0.01

var _hover_outline: MeshInstance3D


@onready var mesh: MeshInstance3D = $"Mesh"
@onready var collision: CollisionShape3D = $"Collision"

var _mat_normal := StandardMaterial3D.new()
var _mat_highlight := StandardMaterial3D.new()
var _mat_blocked := StandardMaterial3D.new()

func _ready() -> void:
	_apply_size()
	_setup_materials()
	_create_hover_outline()

	mesh.material_override = _mat_blocked if is_blocked else _mat_normal



func _setup_materials() -> void:
	_mat_normal.albedo_color = Color.html("#442209") 
	_mat_highlight.albedo_color = Color.html("#FFD24D") # brighter highlight (gold)
	_mat_blocked.albedo_color = Color.html("#30080A")

	_mat_normal.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_blocked.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _apply_size() -> void:
	# Mesh
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(tile_size, thickness, tile_size)
	mesh.mesh = box_mesh
	mesh.position.y = thickness * 0.5

	# Collision
	if collision.shape == null or not (collision.shape is BoxShape3D):
		collision.shape = BoxShape3D.new()
	var box_shape := collision.shape as BoxShape3D
	box_shape.size = Vector3(tile_size, thickness, tile_size)
	collision.position.y = thickness * 0.5

func set_highlight(enabled: bool) -> void:
	if is_blocked:
		mesh.material_override = _mat_blocked
		if _hover_outline: _hover_outline.visible = false
		return

	mesh.material_override = _mat_normal
	if _hover_outline: _hover_outline.visible = enabled


func _create_hover_outline() -> void:
	_hover_outline = MeshInstance3D.new()
	_hover_outline.name = "HoverOutline"
	add_child(_hover_outline)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)

	var half := tile_size * 0.5
	var y := thickness + hover_outline_y_offset

	var p00 := Vector3(-half, y, -half)
	var p10 := Vector3( half, y, -half)
	var p11 := Vector3( half, y,  half)
	var p01 := Vector3(-half, y,  half)

	st.add_vertex(p00); st.add_vertex(p10)
	st.add_vertex(p10); st.add_vertex(p11)
	st.add_vertex(p11); st.add_vertex(p01)
	st.add_vertex(p01); st.add_vertex(p00)

	_hover_outline.mesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var c := hover_outline_color
	c.a = hover_outline_alpha
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c

	_hover_outline.material_override = mat
	_hover_outline.visible = false
