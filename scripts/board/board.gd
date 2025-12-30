extends Node3D
@export var tile_scene: PackedScene
@export var grid_size := Vector2i(8, 8)
@export var tile_size := 1.0
@export var tile_gap := 0.05 # small space between tiles (in meters)
@export var grid_line_color: Color = Color("#BBD0E666") 
@export var grid_line_y := 0.2 # height above tiles to avoid flicker
@export var show_grid_lines := true


# Example: blocked tiles. We'll make it data-driven later.
@export var blocked: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3)]

var tiles: Dictionary = {} # Vector2i -> Tile node
var _hovered_tile: Node3D = null


func _ready() -> void:
	_spawn_grid()
	_auto_grid_line_y()
	if show_grid_lines:
		_spawn_grid_lines()



func grid_to_world(c: Vector2i) -> Vector3:
	var spacing := tile_size + tile_gap
	var half := Vector2(grid_size.x - 1, grid_size.y - 1) * spacing * 0.5
	var x := c.x * spacing - half.x
	var z := c.y * spacing - half.y
	return Vector3(x, 0.0, z)



func world_to_grid(p: Vector3) -> Vector2i:
	var spacing := tile_size + tile_gap
	var half := Vector2(grid_size.x - 1, grid_size.y - 1) * spacing * 0.5
	return Vector2i(
		roundi((p.x + half.x) / spacing),
		roundi((p.z + half.y) / spacing)
	)


func is_in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < grid_size.x and c.y < grid_size.y

func is_blocked(c: Vector2i) -> bool:
	return blocked.has(c)

func set_highlight(c: Vector2i, enabled: bool) -> void:
	if not tiles.has(c):
		return
	var tile: Node3D = tiles[c]
	tile.call("set_highlight", enabled)

func _spawn_grid() -> void:
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var c := Vector2i(x, y)
			var tile := _create_tile(c, is_blocked(c))
			tile.position = grid_to_world(c)
			add_child(tile)
			tiles[c] = tile

func _create_tile(c: Vector2i, blocked_tile: bool) -> Node3D:
	assert(tile_scene != null, "Board.tile_scene is not assigned. Drag Tile.tscn into it.")
	var tile := tile_scene.instantiate() as Node3D
	tile.name = "Tile_%d_%d" % [c.x, c.y]

	# Pass data into the Tile scene/script
	tile.set("coord", c)
	tile.set("is_blocked", blocked_tile)
	tile.set("tile_size", tile_size)

	return tile

func _spawn_grid_lines() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "GridLines"

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)

	var half := tile_size * 0.5
	var y := grid_line_y

	for y_i in range(grid_size.y):
		for x_i in range(grid_size.x):
			var c := Vector2i(x_i, y_i)
			var center := grid_to_world(c) + Vector3(0, y, 0)

			var p00 := center + Vector3(-half, 0, -half)
			var p10 := center + Vector3( half, 0, -half)
			var p11 := center + Vector3( half, 0,  half)
			var p01 := center + Vector3(-half, 0,  half)

			# 4 edges of the tile
			st.add_vertex(p00); st.add_vertex(p10)
			st.add_vertex(p10); st.add_vertex(p11)
			st.add_vertex(p11); st.add_vertex(p01)
			st.add_vertex(p01); st.add_vertex(p00)

	var mesh := st.commit()
	mesh_instance.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = grid_line_color
	mesh_instance.material_override = mat

	add_child(mesh_instance)

func _auto_grid_line_y() -> void:
	# Grab any tile we spawned
	if tiles.is_empty():
		return

	var any_tile: Node3D = tiles.values()[0]

	# Find the MeshInstance3D inside the tile scene (the one showing the plane/box)
	var mesh_instance := any_tile.find_child("Mesh", true, false) as MeshInstance3D
	if mesh_instance == null:
		return

	# Get the mesh bounding box in world space
	var aabb := mesh_instance.get_aabb()

	# top of the mesh in *local* space
	var local_top_y := aabb.position.y + aabb.size.y

	# convert local Y to world Y (good enough for our flat tiles)
	var scale_y := mesh_instance.global_transform.basis.get_scale().y
	var tile_top_y := mesh_instance.global_transform.origin.y + local_top_y * scale_y

	grid_line_y = tile_top_y + 0.01

func _process(_delta: float) -> void:
	_update_hover()

func _update_hover() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 2000.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var new_tile: Node3D = null
	if not hit.is_empty():
		var n: Node = hit["collider"]
		# collider should already be the Tile (StaticBody3D)
		if n != null and n.has_method("set_highlight"):
			new_tile = n as Node3D

	# turn OFF old hover
	if _hovered_tile != null and _hovered_tile != new_tile:
		_hovered_tile.call("set_highlight", false)

	# turn ON new hover
	_hovered_tile = new_tile
	if _hovered_tile != null:
		_hovered_tile.call("set_highlight", true)
