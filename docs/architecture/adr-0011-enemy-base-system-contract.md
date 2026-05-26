# ADR-0011: Enemy Base System Contract

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Enemy) |
| **Knowledge Risk** | HIGH — LimboAI addon; CharacterBody2D unchanged |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `design/gdd/enemy-base-system.md` |
| **Post-Cutoff APIs Used** | `LimboHSM` / `LimboState` (LimboAI addon) — same addon dependency as player. `CharacterBody2D.move_and_slide()` — unchanged. |
| **Verification Required** | Same as ADR-0009: LimboAI addon must be verified compatible with Godot 4.6. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0007 (SIE — `SpellInteractionEngine.process_hit()` + status signals), ADR-0002 (GameManager — `boss_appeared`, `boss_defeated` signals) |
| **Enables** | ADR-0014 (Enemy AI System — extends BaseEnemy), ADR-0020 (Boss System — Devium extends BaseEnemy) |
| **Blocks** | No enemy story may start until BaseEnemy class is Accepted. All projectile stories depend on `take_damage(amount, element)` signature. |

## Context

Per-enemy element handlers (`on_fire_hit`, `on_ice_hit`) were the prior approach but are superseded by the Spell Interaction Engine (ADR-0007). This ADR formalises the unified BaseEnemy contract with status effect integration.

## Decision

All enemies extend `class_name BaseEnemy extends CharacterBody2D`. The class owns damage reception, health, death dispatch, group membership, and status effect signal integration. AI behavior lives in LimboHSM state nodes.

### BaseEnemy Class Contract

```gdscript
class_name BaseEnemy
extends CharacterBody2D

# Config (set in inspector or subclass _ready)
@export var max_health: int = 10

# Runtime state
var health:          int
var is_dead:         bool = false
var player:          CharacterBody2D  # resolved in _ready() via group &"player"
var active_statuses: Dictionary = {}  # { StringName: float expiry_time }
var speed_modifier:  float = 1.0      # 0.0=frozen/stunned, 0.5=slowed, 1.0=normal

# Required child nodes
@onready var anim:       AnimatedSprite2D  # or AnimationPlayer
@onready var hitbox:     Area2D            # receives projectiles + player melee
@onready var burn_timer: Timer            # BURNING DOT timer (1 dmg / 0.8s)

# Signals
signal died
signal health_changed(current: int, maximum: int)
```

### Damage Reception Flow

```gdscript
func take_damage(amount: int, element: StringName = &"") -> void:
    if is_dead:
        return
    var final := SpellInteractionEngine.process_hit(self, amount, element)
    health = max(0, health - final)
    health_changed.emit(health, max_health)
    if final > 0:  # EC-09: suppress damage number when amount == 0
        DamageNumber.spawn(self, final, global_position + Vector2(randf_range(-12, 12), -40),
                           _get_damage_color(element))
    if health == 0:
        is_dead = true
        _hsm.dispatch(&"die")
```

### Group Membership

| Group | Members | Consumers |
|-------|---------|-----------|
| `&"enemy"` | Regular enemies only | SIE status tick, player spells, Zone System |
| `&"boss"` | Boss instances only | GameManager signals, combat barrier, SIE status tick |
| `&"player"` | Player CharacterBody2D | Enemies resolve `player` ref in `_ready()` |

Regular enemies: `&"enemy"` only. Bosses: `&"boss"` only. Never both.

### Hitbox Structure

```
Area2D named "Hitbox"
  Collision layer: 4 (enemy layer)
  Collision mask: 6 (player projectile) + 5 (player melee)
  area_entered signal → check group "player_projectile" or "player_hitbox" → take_damage()
```

No invincibility frames on regular enemies. Bosses may add i-frame logic in subclass.

### Status Effect Integration

```gdscript
func _ready() -> void:
    health = max_health
    player = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
    SpellInteractionEngine.status_applied.connect(_on_status_applied)
    SpellInteractionEngine.status_expired.connect(_on_status_expired)

func _on_status_applied(target: BaseEnemy, status: StringName, _dur: float) -> void:
    if target != self: return
    match status:
        &"frozen", &"stunned":  speed_modifier = 0.0
        &"slowed":              speed_modifier = 0.5
        &"burning":             burn_timer.start(0.8)  # BURN_TICK = 0.8s

func _on_status_expired(target: BaseEnemy, status: StringName) -> void:
    if target != self: return
    match status:
        &"frozen", &"stunned", &"slowed":  speed_modifier = 1.0
        &"burning":                         burn_timer.stop()

func _on_burn_tick() -> void:
    take_damage(1, &"")  # 1 HP per tick, no element
```

`burn_timer: Timer` child node configured: `wait_time = 0.8`, `one_shot = false`.

### Death Flow

```
1. take_damage() → is_dead = true → _hsm.dispatch(&"die")
2. HSM enters DeathState → plays death animation → calls die()
3. BaseEnemy.die(): emit died; call queue_free() after animation
4. Boss subclass override: also emit GameManager.boss_defeated(id); cleanup barrier; call super()
```

### Boss Subclass Additions

Boss classes add:
- `boss_id: StringName` — stable identifier
- `_ready()` calls `GameManager.boss_appeared(boss_id, display_name, max_health)`
- `take_damage()` override: call super(), check phase threshold, dispatch `&"phase2_start"` if below threshold
- `die()` override: `GameManager.boss_defeated.emit(boss_id)` then `super()`
- `health_changed` → `GameManager.boss_health_changed.emit(health, max_health)`

### Damage Number Color Convention

```gdscript
func _get_damage_color(element: StringName) -> Color:
    match element:
        &"fire":    return Color(1.0, 0.55, 0.1, 1.0)  # orange
        &"ice":     return Color(0.4, 0.8, 1.0, 1.0)   # light blue
        &"light":   return Color(1.0, 1.0, 0.4, 1.0)   # bright yellow
        &"shadow":  return Color(0.7, 0.3, 1.0, 1.0)   # purple
        &"conjure": return Color(0.2, 0.9, 0.7, 1.0)   # teal
        &"rupture": return Color(0.8, 0.1, 0.1, 1.0)   # dark red
        _:          return Color.WHITE
```

### Architecture Diagram

```
Projectile.body_entered → enemy.take_damage(damage, element)
  └── SpellInteractionEngine.process_hit(self, damage, element)
        ├── interaction check + status apply
        └── returns final_damage
  └── health -= final_damage → health_changed.emit
  └── DamageNumber.spawn()
  └── health == 0 → is_dead = true → _hsm.dispatch(&"die") → DeathState → die()

SpellInteractionEngine signals:
  status_applied(enemy, status, duration) → _on_status_applied()
    └── speed_modifier set; burn_timer started
  status_expired(enemy, status) → _on_status_expired()
    └── speed_modifier reset; burn_timer stopped
```

## Consequences

### Positive
- Unified damage path: all projectiles call `take_damage(amount, element)` regardless of element
- Status effects are data-driven from SIE — BaseEnemy just reacts to signals
- Devium migration: remove bespoke `_fire_marked/_burn_timer` code; Devium inherits BaseEnemy behavior automatically

### Negative
- All enemies connect SIE signals in `_ready()` — if scene has many enemies, O(N) signal connections per frame. Acceptable at MVP (≤20 enemies per room).
- `active_statuses` is a Dictionary on every enemy — entries managed by SIE, not by BaseEnemy directly

### Risks

- **_hsm null in take_damage()**: If HSM is not yet initialized when `take_damage()` is called, `_hsm.dispatch()` crashes. Mitigation: guard `if _hsm != null` before dispatch.
- **Two projectiles in same frame**: First call sets `is_dead = true`; second returns immediately (EC-06 — correct behavior, documented in GDD).

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-enemy-001 | enemy-base-system.md | BaseEnemy extends CharacterBody2D; LimboHSM for AI | BaseEnemy Class Contract section |
| TR-enemy-002 | enemy-base-system.md | take_damage(amount: int, element: StringName = &"") | Damage Reception Flow (also in ADR-0007) |
| TR-enemy-003 | enemy-base-system.md | Group membership: &"enemy" for regular, &"boss" for bosses | Group Membership table |
| TR-enemy-004 | enemy-base-system.md | Hitbox Area2D structure; layer/mask | Hitbox Structure section |
| TR-enemy-005 | enemy-base-system.md | Death flow: is_dead guard, HSM die event, die() virtual | Death Flow section |
| TR-enemy-006 | enemy-base-system.md | Boss subclass: boss_appeared, boss_defeated signals | Boss Subclass Additions section |
| TR-enemy-007 | enemy-base-system.md | DamageNumber.spawn() on take_damage; suppressed when 0 | Damage Reception Flow (EC-09) |
| TR-enemy-008 | enemy-base-system.md | speed_modifier: float = 1.0 | BaseEnemy Class Contract (also in ADR-0007) |
| TR-enemy-009 | enemy-base-system.md | health_changed(current, maximum) signal | BaseEnemy Class Contract |
| TR-enemy-010 | enemy-base-system.md | burn_timer: Timer child node | Status Effect Integration + required child nodes |
| TR-enemy-011 | enemy-base-system.md | BaseEnemy._ready() connects SIE signals | Status Effect Integration |
| TR-enemy-012 | enemy-base-system.md | DamageNumber.spawn() called from take_damage(); suppressed when 0 | Damage Reception Flow (also in ADR-0007) |

## Related Decisions

- ADR-0007: Damage API & SIE — process_hit() contract; status signals
- ADR-0014: Enemy AI System — LimboHSM states extend BaseEnemy
- ADR-0020: Boss System — boss subclasses, phase transitions
- `design/gdd/enemy-base-system.md` — full GDD
