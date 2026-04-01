extends Node2D
class_name DamageNumber

const LIFETIME := 0.75
const GRAVITY  := 55.0    # frena el ascenso progresivamente

var _amount := 0
var _color  := Color.WHITE
var _vel    := Vector2.ZERO
var _timer  := 0.0


static func spawn(parent: Node, amount: int, world_pos: Vector2, color: Color) -> void:
	var n: DamageNumber = (load("res://scenes/effects/damage_number.tscn") as PackedScene).instantiate()
	parent.add_child(n)
	n.global_position = world_pos
	n._setup(amount, color)


func _setup(amount: int, color: Color) -> void:
	_amount = amount
	_color  = color
	_vel    = Vector2(randf_range(-18.0, 18.0), -55.0)


func _process(delta: float) -> void:
	_timer     += delta
	position   += _vel * delta
	_vel.y     += GRAVITY * delta
	modulate.a  = 1.0 - (_timer / LIFETIME)
	queue_redraw()
	if _timer >= LIFETIME:
		queue_free()


func _draw() -> void:
	var font      := ThemeDB.fallback_font
	var text      := str(_amount)
	var font_size := 14
	# Sombra para legibilidad
	draw_string(font, Vector2(1.0, 1.0), text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.0, 0.0, 0.0, 0.55))
	# Texto principal
	draw_string(font, Vector2.ZERO, text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, _color)
