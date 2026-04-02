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
const DEVIUM_SPEED      := 95.0
const P1_MIN_PLAYER_DIST := 200.0  # px — distancia mínima al player en fase 1
const P1_VEL_SMOOTH     := 7.0    # factor de lerp para suavizar la velocidad

# ─── Límites del room ────────────────────────────────────────────────────────
const ROOM_LEFT   := 48.0
const ROOM_RIGHT  := 592.0
const ROOM_TOP    := 32.0
const ROOM_BOTTOM := 270.0

# ─── Banda de altura en fase 1 (a ras de suelo) ──────────────────────────────
const P1_Y_MIN := 280.0   # px — límite superior (más alto que puede subir)
const P1_Y_MAX := 318.0   # px — límite inferior (a ras de suelo)

# ─── Timing de ataque ────────────────────────────────────────────────────────
const HOVER_DURATION_P1 := 1.5
const HOVER_DURATION_P2 := 1.0
const DIST_FAR           := 200.0
const DIST_NEAR          := 120.0

# ─── Fase 2: órbita helicoidal ────────────────────────────────────────────────
const P2_ANGULAR_SPEED := 1.3     # rad/s — velocidad de rotación
const P2_TARGET_RADIUS := 150.0   # px   — distancia ideal al player
const P2_BREATH_AMP    := 40.0    # px   — amplitud del radio respirante
const P2_BREATH_FREQ   := 0.45    # rad/s
const P2_MOVE_SPEED    := 170.0   # px/s — velocidad hacia el ancla
const P2_DANGER_DIST   := 200.0   # px   — umbral para retroceder
const P2_RETREAT_SPEED := 250.0   # px/s
const P2_WALL_MARGIN   := 28.0    # px   — margen para detectar esquina sin espacio

var _time            := 0.0
var _orbit_center    := Vector2.ZERO
var _hover_timer     := 0.0
var _last_attack: StringName = &""
var _player_last_pos := Vector2.ZERO
var _still_time      := 0.0
var _p2_angle        := 0.0


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_time         = 0.0
	_hover_timer  = 0.0
	_still_time   = 0.0
	_orbit_center = _d.player.global_position if _d.player else _d.global_position
	_player_last_pos = _orbit_center
	# Inicializar ángulo desde la posición actual para evitar salto brusco
	if _d.player:
		var offset := _d.global_position - _d.player.global_position
		_p2_angle = atan2(offset.y, offset.x)
	_d.sprite.play(&"levitate_phase2" if _d.is_phase2 else &"levitate")


func _update(delta: float) -> void:
	_time        += delta
	_hover_timer += delta

	_d.face_player()
	if _d.is_phase2:
		_phase2_orbit(delta)
	else:
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
	anchor = anchor.clamp(Vector2(ROOM_LEFT, P1_Y_MIN), Vector2(ROOM_RIGHT, P1_Y_MAX))

	# Garantizar distancia mínima con el player
	var to_player_from_anchor := _d.player.global_position - anchor
	if to_player_from_anchor.length() < P1_MIN_PLAYER_DIST:
		anchor = _d.player.global_position - to_player_from_anchor.normalized() * P1_MIN_PLAYER_DIST
		anchor = anchor.clamp(Vector2(ROOM_LEFT, P1_Y_MIN), Vector2(ROOM_RIGHT, P1_Y_MAX))

	# Devium se mueve hacia el ancla con velocidad suavizada (aceleración progresiva)
	var to_anchor    := anchor - _d.global_position
	var target_vel   := to_anchor.normalized() * DEVIUM_SPEED if to_anchor.length() > 2.0 else Vector2.ZERO
	_d.velocity = _d.velocity.lerp(target_vel, delta * P1_VEL_SMOOTH)


func _phase2_orbit(delta: float) -> void:
	if not _d.player:
		_d.velocity = Vector2.ZERO
		return

	var player_pos := _d.player.global_position
	var to_player  := player_pos - _d.global_position
	var dist       := to_player.length()

	if dist < P2_DANGER_DIST:
		var retreat_dir := -to_player.normalized()
		var next_pos    := _d.global_position + retreat_dir * P2_RETREAT_SPEED * delta
		if _inside_room(next_pos):
			_d.velocity = retreat_dir * P2_RETREAT_SPEED
		else:
			# Sin espacio: cambiar de lado volteando el ángulo
			_p2_angle += PI
			_d.velocity = Vector2.ZERO
		return

	# Órbita helicoidal: ángulo avanza y radio respira
	_p2_angle += P2_ANGULAR_SPEED * delta
	var radius := P2_TARGET_RADIUS + P2_BREATH_AMP * sin(_time * P2_BREATH_FREQ)
	var anchor := player_pos + Vector2(cos(_p2_angle), sin(_p2_angle)) * radius
	anchor = anchor.clamp(Vector2(ROOM_LEFT, ROOM_TOP), Vector2(ROOM_RIGHT, ROOM_BOTTOM))

	var to_anchor := anchor - _d.global_position
	_d.velocity = to_anchor.normalized() * P2_MOVE_SPEED if to_anchor.length() > 2.0 else Vector2.ZERO


func _inside_room(pos: Vector2) -> bool:
	return pos.x >= ROOM_LEFT + P2_WALL_MARGIN and pos.x <= ROOM_RIGHT - P2_WALL_MARGIN \
		and pos.y >= ROOM_TOP + P2_WALL_MARGIN and pos.y <= ROOM_BOTTOM - P2_WALL_MARGIN


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
