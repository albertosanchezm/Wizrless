extends Node2D
class_name Room

## Identificador único de esta habitación. Usado por GameManager para respawn y guardado.
@export var room_id: String = ""


func _ready() -> void:
	var spawn := $SpawnPoints/PlayerSpawn as Marker2D
	GameManager.set_respawn(spawn.global_position, room_id, get_scene_file_path())
	_on_enter()


## Sobrescribir en escenas heredadas para lógica específica de cada habitación.
func _on_enter() -> void:
	pass


func get_floor_y(default_y: float = global_position.y) -> float:
	var terrain := get_node_or_null("Terrain") as TileMapLayer
	if terrain == null or terrain.tile_set == null:
		return default_y

	var reference_point := _get_floor_reference_point(default_y)
	var local_x := terrain.to_local(reference_point).x
	var cell_x := terrain.local_to_map(Vector2(local_x, 0.0)).x
	var surface_cell_y: Variant = _get_surface_cell_y(terrain, cell_x)
	if surface_cell_y == null:
		return default_y

	var cell_center := terrain.map_to_local(Vector2i(cell_x, int(surface_cell_y)))
	var half_tile_height := terrain.tile_set.tile_size.y * 0.5
	return terrain.to_global(cell_center).y - half_tile_height


func get_floor_y_at(global_x: float, default_y: float = global_position.y) -> float:
	return get_floor_y(default_y)


func _get_floor_reference_point(default_y: float) -> Vector2:
	var spawn_points := get_node_or_null("SpawnPoints")
	if spawn_points == null:
		return Vector2(global_position.x, default_y)

	var reference_point := Vector2(global_position.x, default_y)
	var found_marker := false
	for child in spawn_points.get_children():
		if child is Marker2D:
			var marker := child as Marker2D
			if not found_marker or marker.global_position.y > reference_point.y:
				reference_point = marker.global_position
				found_marker = true

	return reference_point


func _get_surface_cell_y(terrain: TileMapLayer, cell_x: int) -> Variant:
	var used_cells := terrain.get_used_cells()
	if used_cells.is_empty():
		return null

	# Intentar con la columna exacta primero
	var bottom_y := -2147483648
	var found := false
	for cell in used_cells:
		if cell.x == cell_x:
			bottom_y = maxi(bottom_y, cell.y)
			found = true

	# Si no hay tiles en esa columna, buscar la fila más baja de todo el tilemap
	if not found:
		for cell in used_cells:
			bottom_y = maxi(bottom_y, cell.y)
		# Buscar la fila de superficie: subir desde bottom_y mientras haya tiles
		# usando cualquier columna que tenga tile en bottom_y como referencia
		var ref_x := cell_x
		for cell in used_cells:
			if cell.y == bottom_y:
				ref_x = cell.x
				break
		cell_x = ref_x

	var surface_y := bottom_y
	while terrain.get_cell_source_id(Vector2i(cell_x, surface_y - 1)) != -1:
		surface_y -= 1

	return surface_y
