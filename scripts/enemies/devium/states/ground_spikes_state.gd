extends LimboState
## FASE 2. Invoca pinchos desde el suelo bajo la posición del player.

var _d: Devium
var _timer      := 0.0
var _spawned    := false

const WINDUP    := 0.8
const DURATION  := 2.0
const NUM_SPIKES := 5
const SPREAD     := 32.0   # píxeles entre pinchos


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_timer   = 0.0
	_spawned = false
	_d.velocity = Vector2.ZERO
	_d.face_player()
	# TODO: animación de aviso (telegrafiar zona de pinchos)


func _update(delta: float) -> void:
	_timer += delta

	if not _spawned and _timer >= WINDUP:
		_spawn_spikes()
		_spawned = true

	if _timer >= DURATION:
		dispatch(&"end_attack")


func _spawn_spikes() -> void:
	if not _d.player:
		return
	var origin_x := _d.player.global_position.x
	# TODO: instanciar NUM_SPIKES pinchos centrados en origin_x con SPREAD entre ellos
	# Ejemplo:
	# for i in NUM_SPIKES:
	#     var spike = SPIKE_SCENE.instantiate()
	#     spike.global_position = Vector2(origin_x + (i - NUM_SPIKES / 2) * SPREAD, floor_y)
	#     _d.get_parent().add_child(spike)
	pass
