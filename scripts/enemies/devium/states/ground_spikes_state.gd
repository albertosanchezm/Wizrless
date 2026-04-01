extends LimboState
## FASE 2. Invoca pinchos desde el suelo bajo la posición del player.
## En fase 2 lanza dos oleadas: la segunda desplazada aleatoriamente.

const GROUND_SPIKE_SCENE := preload("res://scenes/hazards/ground_spike.tscn")

var _d: Devium
var _timer      := 0.0
var _spawned    := false
var _wave2_done := false

const WINDUP      := 0.8
const WAVE2_DELAY := 0.55   # segundos tras la primera oleada
const DURATION    := 2.4
const NUM_SPIKES  := 5
const SPREAD      := 32.0
const FLOOR_Y     := 352.0
const ROOM_LEFT   := 48.0
const ROOM_RIGHT  := 592.0


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_timer      = 0.0
	_spawned    = false
	_wave2_done = false
	_d.velocity = Vector2.ZERO
	_d.face_player()


func _update(delta: float) -> void:
	_timer += delta

	if not _spawned and _timer >= WINDUP:
		_spawn_spikes(0.0)
		_spawned = true

	# Segunda oleada desplazada, solo en fase 2
	if _d.is_phase2 and _spawned and not _wave2_done and _timer >= WINDUP + WAVE2_DELAY:
		_spawn_spikes(randf_range(-SPREAD * 1.5, SPREAD * 1.5))
		_wave2_done = true

	if _timer >= DURATION:
		dispatch(&"end_attack")


func _spawn_spikes(center_offset: float) -> void:
	if not _d.player:
		return
	var origin_x := _d.player.global_position.x + center_offset
	for i in NUM_SPIKES:
		var offset  := (i - NUM_SPIKES / 2.0) * SPREAD
		var spike_x := clampf(origin_x + offset, ROOM_LEFT, ROOM_RIGHT)
		var spike: Area2D = GROUND_SPIKE_SCENE.instantiate()
		spike.global_position = Vector2(spike_x, FLOOR_Y)
		_d.get_level().add_child(spike)
