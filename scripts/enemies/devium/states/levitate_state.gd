extends LimboState

var _d: Devium

# ─── Centro de órbita (sigue al player lentamente) ───────────────────────────
const CENTER_FOLLOW_SPEED := 55.0

# ─── Órbita ───────────────────────────────────────────────────────────────────
const ORBIT_SPEED       := 1.4
const ORBIT_BASE_RADIUS := 130.0
const ORBIT_RADIUS_VAR  := 35.0
const ORBIT_RADIUS_FREQ := 0.6
const ORBIT_ELLIPSE_Y   := 0.55
const ORBIT_Y_OFFSET    := -30.0

# ─── Movimiento de Devium hacia el ancla ─────────────────────────────────────
const DEVIUM_SPEED := 95.0

# ─── Límites del room ─────────────────────────────────────────────────────────
const ROOM_LEFT   := 48.0
const ROOM_RIGHT  := 592.0
const ROOM_TOP    := 32.0
const ROOM_BOTTOM := 270.0

# ─── Timing de ataque ─────────────────────────────────────────────────────────
const HOVER_DURATION_P1 := 1.5   # segundos entre ataques en fase 1
const HOVER_DURATION_P2 := 1.0   # más rápido en fase 2

# ─── Distancias para selección contextual ────────────────────────────────────
const DIST_FAR  := 200.0   # prefiere ice_ball
const DIST_NEAR := 120.0   # prefiere ice_rocks

var _time          := 0.0
var _orbit_angle   := 0.0
var _orbit_center  := Vector2.ZERO
var _hover_timer   := 0.0
var _last_attack: StringName = &""


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_time        = 0.0
	_hover_timer = 0.0
	_orbit_center = _d.player.global_position if _d.player else _d.global_position
	_orbit_angle  = (_d.global_position - _orbit_center).angle()
	_d.sprite.play(&"levitate")


func _update(delta: float) -> void:
	_time        += delta
	_hover_timer += delta

	_d.face_player()
	_orbit(delta)

	var hover_duration := HOVER_DURATION_P2 if _d.is_phase2 else HOVER_DURATION_P1
	if _hover_timer >= hover_duration:
		_hover_timer = 0.0
		dispatch(_choose_attack())


func _orbit(delta: float) -> void:
	if not _d.player:
		_d.velocity = Vector2.ZERO
		return

	var to_player: Vector2 = _d.player.global_position - _orbit_center
	var max_step: float    = CENTER_FOLLOW_SPEED * delta
	_orbit_center += to_player.limit_length(max_step)

	_orbit_angle += ORBIT_SPEED * delta

	var radius: float  = ORBIT_BASE_RADIUS + ORBIT_RADIUS_VAR * sin(_time * ORBIT_RADIUS_FREQ)
	var center_offset := Vector2(0.0, ORBIT_Y_OFFSET)
	var anchor: Vector2 = _orbit_center + center_offset + Vector2(
		cos(_orbit_angle) * radius,
		sin(_orbit_angle) * radius * ORBIT_ELLIPSE_Y
	)
	anchor = anchor.clamp(Vector2(ROOM_LEFT, ROOM_TOP), Vector2(ROOM_RIGHT, ROOM_BOTTOM))

	var to_anchor: Vector2 = anchor - _d.global_position
	if to_anchor.length() > 2.0:
		_d.velocity = to_anchor.normalized() * DEVIUM_SPEED
	else:
		_d.velocity = Vector2.ZERO


func _choose_attack() -> StringName:
	var pool: Array[StringName] = [&"atk_ice_ball", &"atk_ice_rocks"]
	if _d.is_phase2:
		pool.append(&"atk_ground_spikes")
		pool.append(&"atk_parabolic")

	# Anti-repetición: eliminar el último ataque si hay más opciones
	if pool.size() > 1:
		pool.erase(_last_attack)

	# Selección contextual por distancia al player
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
