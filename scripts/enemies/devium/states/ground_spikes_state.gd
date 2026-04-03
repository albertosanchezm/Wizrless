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

const WINDUP         := 1.0    # s — pausa antes de iniciar la ola
const SHAKE_STEP     := 0.055  # s — intervalo entre cada nuevo offset de shake
const SHAKE_STRENGTH := 3.5    # px — intensidad máxima al final del windup
const SHAKE_DURATION := 0.5    # s — duración total del shake (primera mitad del windup)
const WAVE_T    := 0.2    # s — tiempo de subida/pico/bajada de cada pincho
                          #      igual al stagger → patrón subiendo/pico/bajando simultáneo
const NUM_SPIKES := 56
const ROOM_LEFT  := 48.0
const ROOM_RIGHT := 592.0
const ROOM_TOP   := 32.0
const ROOM_BOTTOM := 270.0
const DURATION   := WINDUP + WAVE_T * (NUM_SPIKES + 2)

# ─── Movimiento helicoidal (igual que levitate_state fase 2) ─────────────────
const P2_ANGULAR_SPEED := 1.3
const P2_TARGET_RADIUS := 150.0
const P2_BREATH_AMP    := 40.0
const P2_BREATH_FREQ   := 0.45
const P2_MOVE_SPEED    := 170.0
const P2_DANGER_DIST   := 200.0
const P2_SAFE_DIST     := 260.0   # distancia para dejar de retroceder (histéresis)
const P2_RETREAT_SPEED := 250.0
const P2_WALL_MARGIN   := 28.0

var _time       := 0.0
var _p2_angle   := 0.0
var _retreating := false


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_timer        = 0.0
	_spike_index  = 0
	_next_spike_t = WINDUP
	_floor_y      = _detect_floor_y()
	_d.face_player()
	_d.sprite.play(&"levitate_phase2_attack")
	_build_positions()
	_start_shake()
	_time       = 0.0
	_retreating = false
	if _d.player:
		var offset := _d.global_position - _d.player.global_position
		_p2_angle = atan2(offset.y, offset.x)


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
	_time  += delta

	_d.face_player()
	_move(delta)

	if _spike_index < NUM_SPIKES and _timer >= _next_spike_t:
		_spawn_spike(_positions[_spike_index])
		_spike_index  += 1
		_next_spike_t += WAVE_T

	if _timer >= DURATION:
		dispatch(&"end_attack")


func _move(delta: float) -> void:
	if not _d.player:
		_d.velocity = Vector2.ZERO
		return

	var player_pos := _d.player.global_position
	var to_player  := player_pos - _d.global_position
	var dist       := to_player.length()

	# Histéresis: entra en retirada a <200px, sale a >260px
	if dist < P2_DANGER_DIST:
		_retreating = true
	elif dist > P2_SAFE_DIST:
		_retreating = false

	if _retreating:
		var retreat_dir := -to_player.normalized()
		var next_pos    := _d.global_position + retreat_dir * P2_RETREAT_SPEED * delta
		if _inside_room(next_pos):
			_d.velocity = retreat_dir * P2_RETREAT_SPEED
		else:
			var room_center := Vector2((ROOM_LEFT + ROOM_RIGHT) * 0.5, (ROOM_TOP + ROOM_BOTTOM) * 0.5)
			var to_center   := (room_center - _d.global_position).normalized()
			_d.velocity = to_center * P2_RETREAT_SPEED
			_p2_angle += PI
		return

	_p2_angle += P2_ANGULAR_SPEED * delta
	var radius := P2_TARGET_RADIUS + P2_BREATH_AMP * sin(_time * P2_BREATH_FREQ)
	var anchor := player_pos + Vector2(cos(_p2_angle), sin(_p2_angle)) * radius
	anchor = anchor.clamp(Vector2(ROOM_LEFT, ROOM_TOP), Vector2(ROOM_RIGHT, ROOM_BOTTOM))

	var to_anchor := anchor - _d.global_position
	_d.velocity = to_anchor.normalized() * P2_MOVE_SPEED if to_anchor.length() > 2.0 else Vector2.ZERO


func _inside_room(pos: Vector2) -> bool:
	return pos.x >= ROOM_LEFT + P2_WALL_MARGIN and pos.x <= ROOM_RIGHT - P2_WALL_MARGIN \
		and pos.y >= ROOM_TOP + P2_WALL_MARGIN and pos.y <= ROOM_BOTTOM - P2_WALL_MARGIN


func _start_shake() -> void:
	var camera := _d.get_viewport().get_camera_2d()
	if camera == null:
		return
	var tween := _d.create_tween()
	var steps := int(SHAKE_DURATION / SHAKE_STEP)
	for i in steps:
		var t := float(i + 1) / float(steps)
		var strength := SHAKE_STRENGTH * t
		tween.tween_property(camera, "offset",
			Vector2(randf_range(-strength, strength), randf_range(-strength, strength)),
			SHAKE_STEP)
	# Resetea la cámara con tiempo suficiente antes de que aparezcan los pinchos
	tween.tween_property(camera, "offset", Vector2.ZERO, SHAKE_STEP)


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
