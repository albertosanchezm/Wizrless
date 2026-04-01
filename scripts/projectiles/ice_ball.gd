extends Area2D

const SPEED         := 180.0
const DAMAGE        := 15
const FRAGMENT_SCENE := preload("res://scenes/projectiles/ice_ball_fragment.tscn")

var direction := Vector2.RIGHT
var _hit      := false


func _ready() -> void:
	var poly := $Visual as Polygon2D
	var pts  := PackedVector2Array()
	for i in 8:
		var a := i * TAU / 8.0
		pts.append(Vector2(cos(a), sin(a)) * 8.0)
	poly.polygon = pts

	add_to_group(&"enemy_projectile")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	$LifeTimer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta


func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	_hit = true
	if body.is_in_group(&"player"):
		GameManager.take_damage(DAMAGE)
		DamageNumber.spawn(get_parent(), DAMAGE, global_position, Color(1.0, 0.25, 0.25, 1.0))
	_spawn_fragments()
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _hit:
		return
	if area.is_in_group(&"player_projectile"):
		_hit = true
		queue_free()


func _spawn_fragments() -> void:
	var normal := _surface_normal()
	# 3 fragmentos distribuidos en un arco de 90° centrado en la normal de impacto.
	# Base: -45°, 0°, +45° con jitter aleatorio de ±15° para no ser predecibles.
	for base_deg in [-45.0, 0.0, 45.0]:
		var deg: float = base_deg + randf_range(-15.0, 15.0)
		var frag: Area2D = FRAGMENT_SCENE.instantiate()
		frag.global_position = global_position
		frag.direction = normal.rotated(deg_to_rad(deg))
		get_parent().add_child(frag)


func _surface_normal() -> Vector2:
	# Estima la normal de la superficie golpeada a partir de la dirección de viaje.
	# Si el movimiento es más vertical → suelo/techo; si es más horizontal → pared.
	if abs(direction.y) >= abs(direction.x):
		return Vector2(0.0, -sign(direction.y))
	return Vector2(-sign(direction.x), 0.0)
