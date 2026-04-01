extends StaticBody2D
## Barrera de combate: desaparece cuando el boss o el player mueren.

func _ready() -> void:
	var boss := get_tree().get_first_node_in_group(&"boss")
	if boss:
		boss.died.connect(_remove)
	GameManager.player_died.connect(_remove)


func _remove() -> void:
	queue_free()
