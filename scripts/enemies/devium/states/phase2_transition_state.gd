extends LimboState

var _d: Devium

const ROOM_CENTER  := Vector2(320.0, 151.0)
const MOVE_SPEED   := 150.0
const ARRIVE_DIST  := 8.0
const HOLD_TIME    := 0.6   # s — tiempo mostrando la animación antes de continuar

var _arrived       := false
var _hold_timer    := 0.0


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_arrived      = false
	_hold_timer   = 0.0
	_d.velocity   = Vector2.ZERO


func _update(delta: float) -> void:
	if _arrived:
		_hold_timer += delta
		if _hold_timer >= HOLD_TIME:
			dispatch(&"end_transition")
		return

	var to_center := ROOM_CENTER - _d.global_position
	if to_center.length() <= ARRIVE_DIST:
		_d.velocity = Vector2.ZERO
		_d.global_position = ROOM_CENTER
		_d.sprite.play(&"levitate_phase2")
		_arrived = true
	else:
		_d.velocity = to_center.normalized() * MOVE_SPEED
