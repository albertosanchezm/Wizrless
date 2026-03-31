extends LimboState

var _p: CharacterBody2D
var _dash_timer := 0.0
var _dash_dir   := 1.0


func _setup() -> void:
	_p = agent as CharacterBody2D


func _enter() -> void:
	# Dirección: input actual, o hacia donde mira el sprite
	var dir := Input.get_axis("move_left", "move_right")
	_dash_dir = dir if abs(dir) > 0.1 else (-1.0 if _p.anim.flip_h else 1.0)

	_dash_timer        = _p.DASH_DURATION
	_p.dash_cooldown   = _p.DASH_COOLDOWN
	_p.skip_gravity    = true
	_p.velocity        = Vector2(_dash_dir * _p.DASH_SPEED, 0.0)
	_p.anim.play("dash")


func _exit() -> void:
	_p.skip_gravity = false


func _update(delta: float) -> void:
	_dash_timer -= delta
	_p.velocity = Vector2(_dash_dir * _p.DASH_SPEED, 0.0)

	if _dash_timer <= 0.0:
		dispatch(&"end_dash")
