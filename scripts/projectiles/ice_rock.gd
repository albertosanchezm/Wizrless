extends Area2D

const FALL_GRAVITY := 350.0
const DAMAGE       := 12
const WARNING_TIME := 0.6

## Y del suelo donde aparece la sombra de aviso.
@export var floor_y: float = 352.0

var _vy      := 0.0
var _falling := false
var _hit     := false


func _ready() -> void:
	# Visual de la roca: polígono irregular gris-azulado
	($Visual as Polygon2D).polygon = PackedVector2Array([
		Vector2(-10.0, -8.0), Vector2(8.0, -12.0), Vector2(12.0, 4.0),
		Vector2(6.0, 10.0),   Vector2(-8.0, 8.0)
	])

	# Sombra de aviso en el suelo — top_level para que no se mueva con la roca
	var shadow := $Shadow as Polygon2D
	var shadow_pts := PackedVector2Array()
	for i in 8:
		var a := i * TAU / 8.0
		shadow_pts.append(Vector2(cos(a) * 10.0, sin(a) * 4.0))
	shadow.polygon    = shadow_pts
	shadow.top_level  = true
	shadow.global_position = Vector2(global_position.x, floor_y - 4.0)

	$Visual.visible = false

	body_entered.connect(_on_body_entered)
	$LifeTimer.timeout.connect(queue_free)
	get_tree().create_timer(WARNING_TIME).timeout.connect(_start_falling)


func _start_falling() -> void:
	$Visual.visible = true
	$Shadow.visible = false
	_falling = true


func _physics_process(delta: float) -> void:
	if not _falling:
		return
	_vy      += FALL_GRAVITY * delta
	position.y += _vy * delta


func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	_hit = true
	if body.is_in_group(&"player"):
		GameManager.take_damage(DAMAGE)
	queue_free()
