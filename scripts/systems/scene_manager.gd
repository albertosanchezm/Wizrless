extends Node

# SceneManager — singleton global
# Gestiona las transiciones entre salas/escenas con fade.

signal transition_started
signal transition_finished

var _is_transitioning := false


func change_room(scene_path: String, spawn_point: String = "default") -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	transition_started.emit()

	# Fade out
	await _fade(1.0, 0.3)

	# Cambiar escena
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame

	# Notificar al spawn point de la sala nueva
	var root := get_tree().current_scene
	if root and root.has_method("set_spawn_point"):
		root.set_spawn_point(spawn_point)

	# Fade in
	await _fade(0.0, 0.3)
	_is_transitioning = false
	transition_finished.emit()


func _fade(target_alpha: float, duration: float) -> void:
	# Se espera un ColorRect con nombre "FadeOverlay" en el CanvasLayer de UI
	var overlay := _get_fade_overlay()
	if not overlay:
		await get_tree().create_timer(duration).timeout
		return
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", target_alpha, duration)
	await tween.finished


func _get_fade_overlay() -> CanvasItem:
	# Buscar en el árbol de escena
	var nodes := get_tree().get_nodes_in_group("fade_overlay")
	if nodes.size() > 0:
		return nodes[0] as CanvasItem
	return null
