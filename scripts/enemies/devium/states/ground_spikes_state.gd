extends LimboState
## Oleada de pinchos que barre el ancho de la pantalla hacia el player.
## En todo momento solo se ven 3: uno subiendo, el central en el pico, uno bajando.

const GROUND_SPIKE_SCENE := preload("res://scenes/hazards/ground_spike.tscn")

var _d: Devium
var _timer        := 0.0
var _spike_index  := 0
var _next_spike_t := 0.0
var _positions    : Array[float] = []
var _floor_y      := 0.0

const WINDUP    := 0.5    # s — pausa antes de iniciar la ola
const WAVE_T    := 0.18   # s — tiempo de subida/pico/bajada de cada pincho
                          #      igual al stagger → patrón subiendo/pico/bajando simultáneo
const NUM_SPIKES := 18
const ROOM_LEFT  := 48.0
const ROOM_RIGHT := 592.0
const DURATION   := WINDUP + WAVE_T * (NUM_SPIKES + 2)


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_timer        = 0.0
	_spike_index  = 0
	_next_spike_t = WINDUP
	_floor_y      = _detect_floor_y()
	_d.velocity   = Vector2.ZERO
	_d.face_player()
	_d.sprite.play(&"levitate_phase2_attack")
	_build_positions()


func _build_positions() -> void:
	_positions.clear()
	var step := (ROOM_RIGHT - ROOM_LEFT) / float(NUM_SPIKES - 1)
	for i in NUM_SPIKES:
		_positions.append(ROOM_LEFT + step * i)
	# La ola se dirige hacia el player: empieza desde el lado opuesto
	if _d.player and _d.player.global_position.x > (ROOM_LEFT + ROOM_RIGHT) * 0.5:
		_positions.reverse()


func _update(delta: float) -> void:
	_timer += delta

	if _spike_index < NUM_SPIKES and _timer >= _next_spike_t:
		_spawn_spike(_positions[_spike_index])
		_spike_index  += 1
		_next_spike_t += WAVE_T

	if _timer >= DURATION:
		dispatch(&"end_attack")


func _detect_floor_y() -> float:
	var space := _d.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(_d.global_position.x, 0.0),
		Vector2(_d.global_position.x, 800.0),
		1  # collision layer 1 = terrain
	)
	query.exclude = [_d.get_rid()]
	var result := space.intersect_ray(query)
	return result.position.y + 16.0 if result else 350.0


func _spawn_spike(x: float) -> void:
	var spike: Area2D = GROUND_SPIKE_SCENE.instantiate()
	spike.appear_time  = WAVE_T
	spike.active_time  = WAVE_T
	spike.retract_time = WAVE_T
	spike.global_position = Vector2(x, _floor_y)
	_d.get_level().add_child(spike)
