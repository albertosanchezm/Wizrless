extends Node

signal transition_started
signal transition_finished

var _is_transitioning := false


func change_room(scene_path: String, spawn_point: String = "default") -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	transition_started.emit()

	var game := _get_game()
	if game:
		await game.change_room(scene_path, spawn_point)

	_is_transitioning = false
	transition_finished.emit()


func _get_game() -> Node:
	var nodes := get_tree().get_nodes_in_group(&"game_kernel")
	return nodes[0] if nodes.size() > 0 else null
