extends Node

# GameManager — singleton global
# Gestiona el estado de la partida: habilidades desbloqueadas, vida, etc.

signal ability_unlocked(ability_name: String)
signal health_changed(current: int, maximum: int)
signal player_took_damage
signal mana_changed(current: float, maximum: float)
signal player_died
signal attack_cooldown_changed(remaining: float, total: float)
signal boss_appeared(boss_name: String, max_health: int)
signal boss_health_changed(current: int, maximum: int)
signal boss_defeated()

const DEVIUM_COMBAT_MUSIC := preload("res://assets/audio/music/devium_combat.mp3")

# --- Habilidades desbloqueables ---
var abilities: Dictionary = {
	"double_jump": false,
	"dash":        false,
	"wall_jump":   false,
	"wall_slide":  false,
}

# --- Estado del jugador ---
var max_health: int = 100
var current_health: int = 100

# --- Posición de respawn ---
var respawn_position: Vector2 = Vector2.ZERO
var respawn_scene: String = ""
var current_room: String = ""
var _music_player: AudioStreamPlayer


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = &"Master"
	add_child(_music_player)

	boss_appeared.connect(_on_boss_appeared)
	boss_defeated.connect(stop_boss_music)
	player_died.connect(stop_boss_music)


func unlock_ability(ability_name: String) -> void:
	if ability_name in abilities and not abilities[ability_name]:
		abilities[ability_name] = true
		ability_unlocked.emit(ability_name)
		print("Habilidad desbloqueada: ", ability_name)


func has_ability(ability_name: String) -> bool:
	return abilities.get(ability_name, false)


func take_damage(amount: int) -> void:
	current_health = max(1, current_health - amount)  # DEBUG: invulnerable
	health_changed.emit(current_health, max_health)
	player_took_damage.emit()


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


func play_boss_music(stream: AudioStream) -> void:
	if stream == null:
		return
	if _music_player.stream != stream:
		_music_player.stream = stream
	if not _music_player.playing:
		_music_player.play()


func stop_boss_music() -> void:
	if _music_player and _music_player.playing:
		_music_player.stop()


func _on_boss_appeared(boss_name: String, _max_health: int) -> void:
	if boss_name == "Devium":
		play_boss_music(DEVIUM_COMBAT_MUSIC)
