extends Node

# SaveManager — singleton global
# Guarda y carga el estado de la partida en disco.

const SAVE_PATH := "user://save.dat"


func save_game() -> void:
	var data := {
		"abilities":        GameManager.abilities.duplicate(),
		"max_health":       GameManager.max_health,
		"current_health":   GameManager.current_health,
		"respawn_position": {
			"x": GameManager.respawn_position.x,
			"y": GameManager.respawn_position.y,
		},
		"current_room": GameManager.current_room,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()
		print("Partida guardada.")


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var data: Variant = file.get_var()
	file.close()
	if not data is Dictionary:
		return false

	GameManager.abilities       = data["abilities"]
	GameManager.max_health      = data["max_health"]
	GameManager.current_health  = data["current_health"]
	GameManager.respawn_position = Vector2(
		data["respawn_position"]["x"],
		data["respawn_position"]["y"]
	)
	GameManager.current_room = data["current_room"]
	print("Partida cargada.")
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
		print("Partida eliminada.")
