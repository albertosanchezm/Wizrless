extends Node

# GameManager — singleton global
# Gestiona el estado de la partida: habilidades desbloqueadas, vida, etc.

signal ability_unlocked(ability_name: String)
signal health_changed(current: int, maximum: int)
signal player_died
signal attack_cooldown_changed(remaining: float, total: float)

# --- Habilidades desbloqueables ---
var abilities: Dictionary = {
	"double_jump": false,
	"dash":        false,
	"wall_jump":   false,
	"wall_slide":  false,
}

# --- Estado del jugador ---
var max_health: int = 6
var current_health: int = 6

# --- Posición de respawn ---
var respawn_position: Vector2 = Vector2.ZERO
var respawn_scene: String = ""
var current_room: String = ""


func unlock_ability(ability_name: String) -> void:
	if ability_name in abilities and not abilities[ability_name]:
		abilities[ability_name] = true
		ability_unlocked.emit(ability_name)
		print("Habilidad desbloqueada: ", ability_name)


func has_ability(ability_name: String) -> bool:
	return abilities.get(ability_name, false)


func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		player_died.emit()


func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


func set_respawn(pos: Vector2, room: String, scene: String = "") -> void:
	respawn_position = pos
	current_room     = room
	respawn_scene    = scene


func reset_health() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
