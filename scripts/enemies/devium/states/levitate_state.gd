extends LimboState

var _d: Devium
var _timer    := 0.0
var _reached  := false

const LEVITATE_Y    := -80.0   # altura relativa al punto de origen
const LEVITATE_SPEED := 60.0
const HOVER_DURATION := 0.8    # segundos suspendido antes de elegir ataque


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_timer   = 0.0
	_reached = false
	_d.face_player()
	# TODO: reproducir animación levitar


func _update(delta: float) -> void:
	if not _reached:
		# Subir hasta la posición de levitación
		var target_y := _d.position.y + LEVITATE_Y
		_d.velocity.y = -LEVITATE_SPEED
		if _d.global_position.y <= target_y:
			_d.velocity.y = 0.0
			_reached = true
	else:
		_d.velocity = Vector2.ZERO
		_timer += delta
		if _timer >= HOVER_DURATION:
			dispatch(_choose_attack())


func _choose_attack() -> StringName:
	# Ataques siempre disponibles
	var pool: Array[StringName] = [&"atk_ice_ball", &"atk_ice_rocks"]

	# Ataques de fase 2: solo cuando vida <= 60%
	if _d.is_phase2:
		pool.append(&"atk_ground_spikes")
		pool.append(&"atk_parabolic")

	pool.shuffle()
	return pool[0]
