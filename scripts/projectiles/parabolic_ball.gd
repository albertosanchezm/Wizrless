extends Area2D

const BASE_SPEED   := 200.0
const GRAVITY      := 400.0
const DAMAGE       := 10

var direction := Vector2.RIGHT
var _vel      := Vector2.ZERO
var _hit      := false


func _ready() -> void:
	var poly := $Visual as Polygon2D
	var pts  := PackedVector2Array()
	for i in 6:
		var a := i * TAU / 6.0
		pts.append(Vector2(cos(a), sin(a)) * 6.0)
	poly.polygon = pts

	_vel = direction * BASE_SPEED

	body_entered.connect(_on_body_entered)
	$LifeTimer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	_vel.y  += GRAVITY * delta
	position += _vel * delta


func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	_hit = true
	if body.is_in_group(&"player"):
		GameManager.take_damage(DAMAGE)
		DamageNumber.spawn(get_parent(), DAMAGE, global_position, Color(1.0, 0.25, 0.25, 1.0))
	queue_free()
