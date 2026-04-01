extends Area2D

const SPEED  := 180.0
const DAMAGE := 15
const FRAGMENT_SCENE := preload("res://scenes/projectiles/ice_ball_fragment.tscn")
const FRAGMENT_ANGLES := [-30.0, 90.0, -90.0]

var direction := Vector2.RIGHT
var _hit      := false


func _ready() -> void:
	var poly := $Visual as Polygon2D
	var pts  := PackedVector2Array()
	for i in 8:
		var a := i * TAU / 8.0
		pts.append(Vector2(cos(a), sin(a)) * 8.0)
	poly.polygon = pts

	body_entered.connect(_on_body_entered)
	$LifeTimer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta


func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	_hit = true
	if body.is_in_group(&"player"):
		GameManager.take_damage(DAMAGE)
	_spawn_fragments()
	queue_free()


func _spawn_fragments() -> void:
	for deg in FRAGMENT_ANGLES:
		var frag: Area2D = FRAGMENT_SCENE.instantiate()
		frag.global_position = global_position
		frag.direction = direction.rotated(deg_to_rad(deg))
		get_parent().add_child(frag)
