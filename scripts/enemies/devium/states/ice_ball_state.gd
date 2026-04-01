extends LimboState
## Lanza una bola de hielo en línea recta hacia el player.

const ICE_BALL_SCENE := preload("res://scenes/projectiles/ice_ball.tscn")

var _d: Devium
var _timer   := 0.0
var _fired   := false

const WINDUP   := 0.6
const DURATION := 1.2


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_timer = 0.0
	_fired = false
	_d.velocity = Vector2.ZERO
	_d.face_player()
	_d.sprite.play(&"levitate_attack")


func _update(delta: float) -> void:
	_timer += delta

	if not _fired and _timer >= WINDUP:
		_fire()
		_fired = true

	if _timer >= DURATION:
		dispatch(&"end_attack")


func _fire() -> void:
	if not _d.player:
		return
	var dir := (_d.player.global_position - _d.global_position).normalized()
	var ball: Area2D = ICE_BALL_SCENE.instantiate()
	ball.direction        = dir
	ball.global_position  = _d.global_position
	_d.get_level().add_child(ball)
