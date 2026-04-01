extends Area2D

const SPEED := 220.0

var direction := Vector2.RIGHT


func _ready() -> void:
	# Dibuja un círculo naranja como visual
	var poly := $Visual as Polygon2D
	var pts := PackedVector2Array()
	for i in 12:
		var a := i * TAU / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 6.0)
	poly.polygon = pts

	# Configura el rastro de fuego
	var trail := $Trail as CPUParticles2D
	trail.direction = -direction
	trail.color_ramp = _make_fire_gradient()
	trail.emitting = true

	add_to_group(&"player_projectile")
	$LifeTimer.timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta


func _on_body_entered(_body: Node2D) -> void:
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group(&"enemy_projectile"):
		queue_free()


func _make_fire_gradient() -> Gradient:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(1.0, 0.8, 0.2, 1.0))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(0.8, 0.1, 0.0, 0.0))
	return g
