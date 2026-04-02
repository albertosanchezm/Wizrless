extends LimboState
## Fase 1: disparo parabólico dirigido a la posición del player.
## Fase 2: disparo recto.

const ICE_BALL_SCENE      := preload("res://scenes/projectiles/ice_ball.tscn")
const PARABOLIC_BALL_SCENE := preload("res://scenes/projectiles/parabolic_ball.tscn")

# Deben coincidir con los valores de parabolic_ball.gd
const PB_GRAVITY    := 400.0
const PB_BASE_SPEED := 200.0
# Velocidad horizontal fija que determina la apertura del arco
const PB_H_SPEED    := 130.0   # px/s — subir = arco más cerrado, bajar = más abierto
const PB_MIN_TIME   := 0.5     # s  — tiempo de vuelo mínimo (evita ángulos extremos)

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
	_d.sprite.play(&"levitate_phase2_attack" if _d.is_phase2 else &"levitate_attack")


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
	if _d.is_phase2:
		_fire_straight()
	else:
		_fire_parabolic()


func _fire_straight() -> void:
	var dir := (_d.player.global_position - _d.global_position).normalized()
	var ball: Area2D = ICE_BALL_SCENE.instantiate()
	ball.direction       = dir
	ball.global_position = _d.global_position
	_d.get_level().add_child(ball)


func _fire_parabolic() -> void:
	var origin := _d.global_position
	var target := _d.player.global_position
	var dx     := target.x - origin.x
	var dy     := target.y - origin.y

	# Tiempo de vuelo: basado en la distancia horizontal, con mínimo para evitar arcos bruscos
	var T  := maxf(absf(dx) / PB_H_SPEED, PB_MIN_TIME)
	var vx := dx / T
	var vy := (dy - 0.5 * PB_GRAVITY * T * T) / T

	var ball: Area2D = PARABOLIC_BALL_SCENE.instantiate()
	ball.direction       = Vector2(vx, vy) / PB_BASE_SPEED
	ball.global_position = origin
	_d.get_level().add_child(ball)
