extends CanvasLayer

var _ability_labels: Dictionary = {}

@onready var _health_bar:      ProgressBar = $Control/TopLeft/HealthRow/HealthBar
@onready var _mana_bar:        ProgressBar = $Control/TopLeft/ManaRow/ManaBar
@onready var _cooldown_bar:    ProgressBar = $Control/TopRight/CooldownBar
@onready var _cooldown_label:  Label       = $Control/TopRight/CooldownLabel
@onready var _boss_container:  VBoxContainer = $Control/BossContainer
@onready var _boss_name:       Label       = $Control/BossContainer/BossName
@onready var _boss_bar:        ProgressBar = $Control/BossContainer/BossBar


func _ready() -> void:
	for node in $Control/BottomLeft/Abilities.get_children():
		_ability_labels[node.name] = node as Label
		(node as Label).modulate.a = 0.3

	GameManager.health_changed.connect(_on_health_changed)
	GameManager.mana_changed.connect(_on_mana_changed)
	GameManager.ability_unlocked.connect(_on_ability_unlocked)
	GameManager.attack_cooldown_changed.connect(_on_attack_cooldown_changed)
	GameManager.boss_appeared.connect(_on_boss_appeared)
	GameManager.boss_health_changed.connect(_on_boss_health_changed)
	GameManager.boss_defeated.connect(_on_boss_hidden)
	GameManager.player_died.connect(_on_boss_hidden)
	_on_health_changed(GameManager.current_health, GameManager.max_health)
	_on_mana_changed(100.0, 100.0)


func _on_health_changed(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value     = current


func _on_mana_changed(current: float, maximum: float) -> void:
	_mana_bar.max_value = maximum
	_mana_bar.value     = current


func _on_ability_unlocked(ability_name: String) -> void:
	if ability_name in _ability_labels:
		_ability_labels[ability_name].modulate.a = 1.0


func _on_attack_cooldown_changed(remaining: float, total: float) -> void:
	_cooldown_bar.value = 1.0 - (remaining / total)
	_cooldown_label.text = "LISTA" if remaining <= 0.0 else "%.1fs" % remaining


func _on_boss_appeared(boss_name: String, max_health: int) -> void:
	_boss_name.text = boss_name.to_upper()
	_boss_bar.max_value = max_health
	_boss_bar.value = max_health
	_boss_container.visible = true


func _on_boss_health_changed(current: int, maximum: int) -> void:
	_boss_bar.max_value = maximum
	_boss_bar.value = current


func _on_boss_hidden() -> void:
	_boss_container.visible = false
