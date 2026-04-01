extends LimboState

var _d: Devium

# ─── Centro de órbita ────────────────────────────────────────────────────────
const CENTER_FOLLOW_SPEED := 55.0

# ─── Osciladores duales (Lissajous) ──────────────────────────────────────────
const OSC_X_FREQ  := 1.1    # rad/s  — ratio irracional con Y → path nunca se repite
const OSC_Y_FREQ  := 1.7    # rad/s

# ─── Radios que respiran ─────────────────────────────────────────────────────
const BASE_RX     := 110.0
const VAR_R       := 60.0
const BREATH_FREQ := 0.4
const ELLIPSE_Y   := 0.85
const Y_OFFSET    := -30.0

# ─── Reactividad: contrae radio cuando el player está quieto ─────────────────
const STILL_THRESHOLD   := 8.0    # px — umbral para considerar que el player no se mueve
const STILL_TIME_MAX    := 2.0    # s  — tiempo hasta llegar al radio mínimo
const MIN_RADIUS_FACTOR := 0.45   # BASE_RX * 0.45 ≈ 50 px de radio mínimo

# ─── Movimiento de Devium hacia el ancla ─────────────────────────────────────
const DEVIUM_SPEED := 95.0

# ─── Límites del room ────────────────────────────────────────────────────────
const ROOM_LEFT   := 48.0
const ROOM_RIGHT  := 592.0
const ROOM_TOP    := 32.0
const ROOM_BOTTOM := 270.0

# ─── Timing de ataque ────────────────────────────────────────────────────────
const HOVER_DURATION_P1 := 1.5
const HOVER_DURATION_P2 := 1.0
const DIST_FAR           := 200.0
const DIST_NEAR          := 120.0

var _time            := 0.0
var _orbit_center    := Vector2.ZERO
var _hover_timer     := 0.0
var _last_attack: StringName = &""
var _player_last_pos := Vector2.ZERO
var _still_time      := 0.0


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_time         = 0.0
	_hover_timer  = 0.0
	_still_time   = 0.0
	_orbit_center = _d.player.global_position if _d.player else _d.global_position
	_player_last_pos = _orbit_center
	_d.sprite.play(&"levitate")


func _update(delta: float) -> void:
	_time        += delta
	_hover_timer += delta

	_d.face_player()
	_track_stillness(delta)
	_orbit(delta)

	var hover_dur := HOVER_DURATION_P2 if _d.is_phase2 else HOVER_DURATION_P1
	if _hover_timer >= hover_dur:
		_hover_timer = 0.0
		dispatch(_choose_attack())


func _track_stillness(delta: float) -> void:
	if not _d.player:
		return
	var moved := _d.player.global_position.distance_to(_player_last_pos)
	if moved < STILL_THRESHOLD:
		_still_time = min(_still_time + delta, STILL_TIME_MAX + 1.0)
	else:
		# Si el player se mueve, el contador baja el doble de rápido de lo que subió
		_still_time = max(0.0, _still_time - delta * 2.0)
	_player_last_pos = _d.player.global_position


func _orbit(delta: float) -> void:
	if not _d.player:
		_d.velocity = Vector2.ZERO
		return

	# Centro de órbita sigue al player a velocidad limitada (inercia)
	_orbit_center += (_d.player.global_position - _orbit_center).limit_length(CENTER_FOLLOW_SPEED * delta)

	# Radio base que respira lentamente
	var rx_base: float = BASE_RX + VAR_R * sin(_time * BREATH_FREQ)

	# Factor de contracción: si el player está quieto, Devium se acerca
	var still_factor  := clampf(_still_time / STILL_TIME_MAX, 0.0, 1.0)
	var radius_factor := lerpf(1.0, MIN_RADIUS_FACTOR, still_factor)
	var rx            := rx_base * radius_factor
	var ry            := rx * ELLIPSE_Y

	# Ancla Lissajous: dos osciladores independientes en X e Y
	var anchor := _orbit_center + Vector2(
		cos(_time * OSC_X_FREQ) * rx,
		sin(_time * OSC_Y_FREQ) * ry + Y_OFFSET
	)
	anchor = anchor.clamp(Vector2(ROOM_LEFT, ROOM_TOP), Vector2(ROOM_RIGHT, ROOM_BOTTOM))

	# Devium se mueve hacia el ancla a velocidad constante
	var to_anchor := anchor - _d.global_position
	_d.velocity = to_anchor.normalized() * DEVIUM_SPEED if to_anchor.length() > 2.0 else Vector2.ZERO


func _choose_attack() -> StringName:
	var pool: Array[StringName] = [&"atk_ice_ball", &"atk_ice_rocks"]
	if _d.is_phase2:
		pool.append(&"atk_ground_spikes")
		pool.append(&"atk_parabolic")

	if pool.size() > 1:
		pool.erase(_last_attack)

	if _d.player:
		var dist := _d.global_position.distance_to(_d.player.global_position)
		if dist > DIST_FAR and pool.has(&"atk_ice_ball") and randf() < 0.65:
			_last_attack = &"atk_ice_ball"
			return &"atk_ice_ball"
		if dist < DIST_NEAR and pool.has(&"atk_ice_rocks") and randf() < 0.65:
			_last_attack = &"atk_ice_rocks"
			return &"atk_ice_rocks"

	pool.shuffle()
	_last_attack = pool[0]
	return pool[0]
