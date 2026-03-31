extends CanvasLayer

const COLOR_HEART_FULL  := Color(0.85, 0.15, 0.15)
const COLOR_HEART_EMPTY := Color(0.25, 0.25, 0.25)

var _hearts: Array[ColorRect] = []
var _ability_labels: Dictionary = {}

@onready var _cooldown_bar: ProgressBar = $Control/TopRight/CooldownBar
@onready var _cooldown_label: Label     = $Control/TopRight/CooldownLabel


func _ready() -> void:
	for node in $Control/TopLeft/Hearts.get_children():
		_hearts.append(node as ColorRect)

	for node in $Control/BottomLeft/Abilities.get_children():
		_ability_labels[node.name] = node as Label
		(node as Label).modulate.a = 0.3

	GameManager.health_changed.connect(_on_health_changed)
	GameManager.ability_unlocked.connect(_on_ability_unlocked)
	GameManager.attack_cooldown_changed.connect(_on_attack_cooldown_changed)
	_on_health_changed(GameManager.current_health, GameManager.max_health)


func _on_health_changed(current: int, _maximum: int) -> void:
	for i in _hearts.size():
		_hearts[i].color = COLOR_HEART_FULL if i < current else COLOR_HEART_EMPTY


func _on_ability_unlocked(ability_name: String) -> void:
	if ability_name in _ability_labels:
		_ability_labels[ability_name].modulate.a = 1.0


func _on_attack_cooldown_changed(remaining: float, total: float) -> void:
	_cooldown_bar.value = 1.0 - (remaining / total)
	if remaining <= 0.0:
		_cooldown_label.text = "LISTA"
	else:
		_cooldown_label.text = "%.1fs" % remaining
