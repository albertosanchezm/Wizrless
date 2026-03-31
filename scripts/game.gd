extends Node2D

## Kernel del juego. Gestiona el ciclo de vida de rooms y persiste HUD y Player.

const FIRST_ROOM := "res://scenes/world/rooms/room1.tscn"

@onready var _room_container: Node2D = $RoomContainer
@onready var _player: CharacterBody2D = $Player

var _current_room: Node = null


func _ready() -> void:
	add_to_group(&"game_kernel")
	_load_room(FIRST_ROOM)


## Llamado por SceneManager. Hace fade-out, cambia de room, reposiciona el player, fade-in.
func change_room(scene_path: String, spawn_point: String = "default") -> void:
	await _fade(1.0, 0.3)
	await _load_room(scene_path, spawn_point)
	await _fade(0.0, 0.3)


func _load_room(scene_path: String, spawn_point: String = "default") -> void:
	# Descargar room actual
	if _current_room:
		_current_room.queue_free()
		_current_room = null

	# Cargar e instanciar la nueva room
	var packed: PackedScene = load(scene_path)
	var room: Node = packed.instantiate()
	_room_container.add_child(room)
	_current_room = room

	# Congelar física del player para evitar que la gravedad actúe durante el spawn
	_player.set_physics_process(false)

	# Esperar a que el TileMapLayer genere sus collision shapes
	await get_tree().physics_frame

	# Reposicionar el player en el spawn point indicado
	var spawn_points: Node = room.get_node_or_null("SpawnPoints")
	if spawn_points:
		var target := spawn_points.get_node_or_null(spawn_point) as Marker2D
		if not target:
			target = spawn_points.get_child(0) as Marker2D
		if target:
			_player.global_position = target.global_position
			_player.velocity = Vector2.ZERO

	# Reactivar física
	_player.set_physics_process(true)


func _fade(target_alpha: float, duration: float) -> void:
	var overlay := $FadeOverlay/Overlay as ColorRect
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", target_alpha, duration)
	await tween.finished
