extends Area2D
class_name RoomExit

@export var target_room: String = ""
@export var target_spawn: String = "default"

var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node2D) -> void:
	if _used:
		return
	_used = true
	SceneManager.change_room(target_room, target_spawn)
