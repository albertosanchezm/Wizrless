extends Node2D
class_name Room

## Identificador único de esta habitación. Usado por GameManager para respawn y guardado.
@export var room_id: String = ""


func _ready() -> void:
	var spawn := $SpawnPoints/PlayerSpawn as Marker2D
	GameManager.set_respawn(spawn.global_position, room_id)
	_on_enter()


## Sobrescribir en escenas heredadas para lógica específica de cada habitación.
func _on_enter() -> void:
	pass
