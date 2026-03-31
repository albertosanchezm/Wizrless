extends LimboState
## Lanza rocas de hielo que caen desde arriba en posiciones aleatorias.

var _d: Devium
var _timer       := 0.0
var _volley_timer := 0.0
var _volleys_done := 0

const WINDUP        := 0.5
const VOLLEY_INTERVAL := 0.4
const NUM_VOLLEYS   := 3
const ROCKS_PER_VOLLEY := 2


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_timer        = 0.0
	_volley_timer = 0.0
	_volleys_done = 0
	_d.velocity = Vector2.ZERO
	_d.face_player()
	# TODO: animación de carga de rocas


func _update(delta: float) -> void:
	_timer += delta

	if _timer < WINDUP:
		return

	_volley_timer += delta
	if _volleys_done < NUM_VOLLEYS and _volley_timer >= VOLLEY_INTERVAL:
		_volley_timer = 0.0
		_launch_volley()
		_volleys_done += 1

	if _volleys_done >= NUM_VOLLEYS and _volley_timer >= VOLLEY_INTERVAL:
		dispatch(&"end_attack")


func _launch_volley() -> void:
	if not _d.player:
		return
	for i in ROCKS_PER_VOLLEY:
		var offset_x := randf_range(-80.0, 80.0)
		var target_x  := _d.player.global_position.x + offset_x
		# TODO: instanciar roca de hielo que caiga desde arriba hacia target_x
		# Ejemplo:
		# var rock = ICE_ROCK_SCENE.instantiate()
		# rock.global_position = Vector2(target_x, _d.global_position.y - 100)
		# _d.get_parent().add_child(rock)
		pass
