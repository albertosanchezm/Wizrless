# ADR-0015: Hazard System Contract

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Feature (Environmental Hazards) |
| **Knowledge Risk** | LOW — Area2D, CollisionShape2D, Timer APIs unchanged |
| **References Consulted** | `design/gdd/hazard-system.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0008 (Health System — `GameManager.take_damage()`), ADR-0012 (Zone/Room — hazards live in `Hazards` node) |
| **Enables** | ADR-0020 (Boss System — spawns GroundSpike scene with overridden timing) |
| **Blocks** | No level design placement of hazards until scene contracts are Accepted |

## Context

Three hazard types are needed for MVP environmental threat. `GroundSpike` already exists; `DamageZone` and `KillZone` are new. All hazards must share one collision layer, route damage through Health System, and provide a visible cue before harming the player.

## Decision

All three hazard types extend `Area2D`. All damage routes through `GameManager.take_damage()`. Hazard code is responsible only for detecting player overlap and calling take_damage — the Health System owns iframe logic, death detection, and signal emission.

### Collision Architecture (All Hazards)

```
collision_layer = 16   (bit 4 — "Hazard" layer; not overlapping enemy or terrain)
collision_mask  = 2    (bit 1 — detects Player body only)
```

No hazard should interact with enemies, projectiles, or terrain.

### GroundSpike (existing — reference spec)

```
GroundSpike (Area2D)
├─ Visual (Sprite2D)         -- spike_root.png, y-offset −26.5 px
└─ CollisionShape2D          -- RectangleShape2D 18×46 px, y-offset −23.0 px
```

```gdscript
# scripts/hazards/ground_spike.gd
const DAMAGE: int = 2   # not exported — change requires code or subclass

@export var appear_time:  float = 0.15
@export var active_time:  float = 1.2
@export var retract_time: float = 0.15

func _ready() -> void:
    _set_collision_active(false)
    _start_lifecycle()

func _start_lifecycle() -> void:
    # Appear phase (no collision)
    await _tween_appear()
    _set_collision_active(true)
    body_entered.connect(_on_body_entered)
    # Active phase
    await get_tree().create_timer(active_time).timeout
    _set_collision_active(false)
    body_entered.disconnect(_on_body_entered)
    # Retract phase
    await _tween_retract()
    queue_free()

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group(&"player"):
        GameManager.take_damage(DAMAGE)

func _set_collision_active(active: bool) -> void:
    $CollisionShape2D.disabled = not active
```

**EC-03/EC-06 guard**: Collision shape disabled during appear and retract phases — `body_entered` cannot fire during windup/retract.

### DamageZone (new)

```
DamageZone (Area2D)
└─ CollisionShape2D           -- shape set per instance in inspector
```

```gdscript
# scripts/hazards/damage_zone.gd
@export var damage_on_enter: int   = 1
@export var tick_damage:     int   = 0      # 0 = no tick damage
@export var tick_interval:   float = 1.0
@export var visual_color:    Color = Color(1.0, 0.4, 0.0, 0.35)

var _tick_timer: Timer

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    _tick_timer = Timer.new()
    _tick_timer.wait_time = tick_interval
    _tick_timer.one_shot = false
    _tick_timer.timeout.connect(_on_tick)
    add_child(_tick_timer)

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group(&"player"): return
    GameManager.take_damage(damage_on_enter)
    if tick_damage > 0: _tick_timer.start()

func _on_body_exited(body: Node2D) -> void:
    if body.is_in_group(&"player"):
        _tick_timer.stop()

func _on_tick() -> void:
    GameManager.take_damage(tick_damage)
```

DamageZone renders a `ColorRect` overlay (child of the scene, sized to match collision shape bounds) modulated to `visual_color`. Level designer adds this child in scene editor.

### KillZone (new)

```
KillZone (Area2D)
└─ CollisionShape2D           -- covers full pit opening
```

```gdscript
# scripts/hazards/kill_zone.gd
func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group(&"player"):
        GameManager.take_damage(GameManager.max_health)
```

No exported variables — KillZone is always instant. Removes all HP; Health System handles death.

**Debug note (EC-04)**: If debug HP floor `current_health = max(1, ...)` is active in GameManager, KillZone cannot kill. Remove floor before testing KillZone.

### Placement Rules (Level Design Contract)

```
Room (Node2D)
└─ Hazards (Node2D)     ← all static hazards placed here
    ├─ GroundSpike
    ├─ DamageZone
    └─ KillZone
```

- Boss-spawned GroundSpike instances added to level root (not `Hazards` node) — they must survive room cleanup.
- Minimum `appear_time` = 0.10s for player-placed spikes (below 0.10s only for boss-scripted waves where animation telegraphs).
- KillZone must cover full pit opening + 8 px margin on each side.
- Checkpoint placement must not overlap DamageZones or KillZones (design convention, no code guard).

### Damage Routing Summary

```
Hazard body_entered
  → GameManager.take_damage(amount)
    → Health System 7-step flow
    → health_changed.emit() → HUD
    → player_damaged.emit() → Audio/Camera
    → iframe_timer set
    → player_died.emit() if health == 0
```

## Consequences

### Positive
- Three hazard types cover all MVP environmental threat
- All damage routes through one entry point — iframe deduplication and dialogue invulnerability handled automatically

### Negative
- GroundSpike `DAMAGE` is a constant (not exported) — per-placement damage variation requires subclassing
- KillZone relies on Health System not having a debug HP floor — coordination required during development

### Risks

- **DamageZone tick fires after death**: Health System `take_damage()` must guard `if is_dead: return` at the caller level. Health System ADR-0008 specifies this is the calling system's responsibility — this is an inter-system risk.
- **GroundSpike with overridden timing (boss)**: Boss uses very short `appear_time` (0.05–0.15s). This is valid per spec — low warning time is acceptable only when boss animation telegraphs the attack.

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-hazard-001 | hazard-system.md | Three hazard types: GroundSpike (timed), DamageZone (persistent tick), KillZone (instant) | All three hazard class contracts |
| TR-hazard-002 | hazard-system.md | All hazard damage routes through GameManager.take_damage() | Damage Routing section |
| TR-hazard-003 | hazard-system.md | Hazard damage values calibrated against Health System 6–14 HP scale | Damage values: GroundSpike=2, DamageZone=1 enter + optional tick, KillZone=max_health |

## Related Decisions

- ADR-0008: Health System — `take_damage()` is the single damage entry point
- ADR-0012: Zone/Room System — `Hazards` node in room scene tree
- ADR-0020: Boss System — spawns GroundSpike as attack primitive
- `design/gdd/hazard-system.md` — full GDD
