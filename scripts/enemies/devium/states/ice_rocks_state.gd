extends LimboState
## Lanza rocas de hielo que caen desde arriba en posiciones aleatorias.

const ICE_ROCK_SCENE := preload("res://scenes/projectiles/ice_rock.tscn")

var _d: Devium
var _timer        := 0.0
var _volley_timer := 0.0
var _volleys_done := 0

const WINDUP           := 0.5
const VOLLEY_INTERVAL  := 0.5
const NUM_VOLLEYS      := 3
const ROCKS_PER_VOLLEY := 2
const SPAWN_Y          := 35.0   # justo encima del techo del room
const FLOOR_Y          := 352.0  # superficie del suelo para la sombra
const ROOM_LEFT        := 48.0
const ROOM_RIGHT       := 592.0


func _setup() -> void:
	_d = agent as Devium


func _enter() -> void:
	_timer        = 0.0
	_volley_timer = 0.0
	_volleys_done = 0
	_d.velocity = Vector2.ZERO
	_d.face_player()
	_d.sprite.play(&"levitate_attack2")


func _update(delta: float) -> void:
	_timer += delta

	if _timer < WINDUP:
		return

	_volley_timer += delta
	if _volleys_done < NUM_VOLLEYS and _volley_timer >= VOLLEY_INTERVAL:
		_volley_timer = 0.0
		_launch_volley()
		_volleys_done += 1

	if _volleys_done >= NUM_VOLLEYS and _volley_timer >= VOLLEY_INTERVAL:
		dispatch(&"end_attack")


func _launch_volley() -> void:
	if not _d.player:
		return
	for i in ROCKS_PER_VOLLEY:
		var offset_x := randf_range(-80.0, 80.0)
		var target_x := clampf(_d.player.global_position.x + offset_x, ROOM_LEFT, ROOM_RIGHT)
		var rock: Area2D = ICE_ROCK_SCENE.instantiate()
		rock.floor_y          = FLOOR_Y
		rock.global_position  = Vector2(target_x, SPAWN_Y)
		_d.get_level().add_child(rock)
