# ADR-0010: Spell System Contract

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Spells) |
| **Knowledge Risk** | MEDIUM — Resource subclass API unchanged; AnimatedSprite2D unchanged; confirm `PackedScene.instantiate()` returns `Node` in 4.6 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `design/gdd/spell-system.md` |
| **Post-Cutoff APIs Used** | `Resource.new()` / `@export` on Resource subclass — unchanged. Confirm `PackedScene.instantiate()` return type in 4.6. |
| **Verification Required** | (1) Confirm `PackedScene.instantiate()` still returns `Node` (not `Node2D`) in Godot 4.6. (2) Confirm `AnimatedSprite2D.frame_changed` signal fires correctly mid-animation in 4.6. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Input System — `cast` action), ADR-0002 (GameManager — `mana_changed`, `spell_cast`, `attack_cooldown_changed` signals), ADR-0009 (Movement System — AttackState in HSM), ADR-0004 (Audio System — SFX pool for projectile audio) |
| **Enables** | ADR-0013 (Spell Slot System — sets `active_spell`), ADR-0007 (SIE — receives `spell_cast` signal for interaction tracking), ADR-0021 (HUD — mana bar, cooldown indicator) |
| **Blocks** | No projectile story may start until `SpellResource` class and cast flow are Accepted |

## Context

Spell casting is partially implemented (Fireball exists) but unsystematic. No `SpellResource` data model, no mana system, no cast flow contract. Stories would be written against an unstable interface without this ADR.

## Decision

Spells are data-driven via `SpellResource` (Godot Resource subclass). Casting follows a 7-step flow. Mana is owned by the player script. Six MVP spells are defined as `.tres` files.

### SpellResource Data Model

```gdscript
class_name SpellResource
extends Resource

@export var id:               StringName     # &"fireball"
@export var display_name:     String         # "Fireball"
@export var element:          SpellElement   # enum FIRE, ICE, LIGHT, SHADOW, CONJURE, RUPTURE
@export var projectile_scene: PackedScene    # scene to instantiate on cast
@export var mana_cost:        float = 25.0   # default 25.0
@export var cast_frame:       int = 3        # animation frame that spawns projectile
@export var cast_animation:   StringName = &"attack"
@export var spawn_offset:     Vector2        # offset from player position
@export var icon:             Texture2D      # HUD icon
@export var lore_key:         StringName     # lore database hook
```

`SpellElement` enum lives in `SpellResource` as an inner class so both Spell System and Interaction Engine can reference it without circular dependency.

### Cast Flow (7 steps, exact order)

```
1. wants_attack() check per physics frame in active movement state
   a. current_mana >= active_spell.mana_cost → fail silently if false
   b. attack_cooldown <= 0.0 → fail silently if false

2. HSM dispatches &"attack" → AttackState enters

3. AttackState._enter():
   a. Play active_spell.cast_animation on AnimatedSprite2D
   b. attack_cooldown = ATTACK_COOLDOWN
   c. player.use_mana(active_spell.mana_cost)

4. Animation reaches active_spell.cast_frame → _fire() called

5. _fire():
   a. Compute direction (horizontal or diagonal-up if move_up held; Rupture always horizontal)
   b. Instantiate active_spell.projectile_scene
   c. Set projectile position = player.global_position + spawn_offset (flipped for facing direction)
   d. Set projectile direction
   e. Add to parent scene

6. GameManager.spell_cast.emit(active_spell, direction)

7. Animation ends → AttackState dispatches back to Idle/Run/Fall
```

### Mana Resource

```gdscript
# On player script
var current_mana: float = MAX_MANA
var _mana_regen_timer: float = 0.0

const MAX_MANA:          float = 100.0
const MANA_REGEN_RATE:   float = 10.0   # pts/s
const MANA_REGEN_DELAY:  float = 1.5    # s before regen starts
const ATTACK_COOLDOWN:   float = 1.5    # s between casts

func use_mana(amount: float) -> void:
    current_mana = max(0.0, current_mana - amount)
    _mana_regen_timer = MANA_REGEN_DELAY  # reset delay on spend
    GameManager.mana_changed.emit(current_mana, MAX_MANA)

# In _physics_process(delta):
if _mana_regen_timer > 0.0:
    _mana_regen_timer -= delta
else:
    if current_mana < MAX_MANA:
        current_mana = min(MAX_MANA, current_mana + MANA_REGEN_RATE * delta)
        GameManager.mana_changed.emit(current_mana, MAX_MANA)
```

### GameManager Signals (Spell System's contribution)

```gdscript
signal spell_cast(spell: SpellResource, direction: Vector2)
signal mana_changed(current: float, maximum: float)         # emitted by use_mana + regen
signal attack_cooldown_changed(remaining: float, total: float)  # emitted per frame during cooldown
```

### MVP Spell Library

| ID | Element | Base Damage | Mana | Behavior |
|----|---------|-------------|------|----------|
| `fireball` | FIRE | 20 | 25 | Horizontal, destroys on contact |
| `ice_shard` | ICE | 15 | 25 | Horizontal, slower, applies brief slow on hit |
| `light_bolt` | LIGHT | 18 | 25 | Horizontal, faster, passes through terrain |
| `shadow_tendril` | SHADOW | 12 | 25 | Short arc, curves downward |
| `conjure` | CONJURE | 0 | 25 | Stationary orb, 3s lifetime, interaction trigger only |
| `rupture` | RUPTURE | 25 | 35 | Slow, high damage, horizontal forced |

Each spell is a `.tres` file in `res://resources/spells/`. Projectile scenes own their movement logic, SFX, and lifetime.

### Cast Direction

```gdscript
func _get_cast_direction() -> Vector2:
    var facing := Vector2(-1 if anim.flip_h else 1, 0)
    if active_spell.element == SpellElement.RUPTURE:
        return facing                              # forced horizontal
    if Input.is_action_pressed("move_up"):
        return (facing + Vector2(0, -1)).normalized()
    return facing
```

### Architecture Diagram

```
Input ("cast" action, attack_cooldown <= 0, mana >= cost)
  └── wants_attack() → HSM dispatches &"attack"
        └── AttackState
              ├── Play animation; set cooldown; use_mana()
              ├── cast_frame reached → _fire()
              │     └── Instantiate projectile_scene at spawn_offset
              │           └── Projectile → enemy.take_damage(damage, element)
              └── GameManager.spell_cast.emit(spell, direction)
                    └── SpellInteractionEngine tracks cast history

GameManager.mana_changed → HUD mana bar
GameManager.attack_cooldown_changed → HUD cooldown indicator
```

## Consequences

### Positive
- Data-driven spells: new spell = new `.tres` file, no code change
- Six spells share the same cast flow; per-spell differences live in the Resource
- Mana system creates resource pressure without per-spell cooldowns

### Negative
- Mana lives on the player script — not in an autoload or separate system; save/load of mana state must be handled in player's save provider
- All MVP spells share the same cast animation — per-spell animations deferred to polish

### Risks
- **cast_frame out of sync with animation length**: If animation is shorter than `cast_frame`, `_fire()` never executes. Mitigation: each SpellResource `.tres` must have `cast_frame ≤ animation_frame_count - 1` for its `cast_animation`.
- **active_spell null on first frame**: Spell Slot System guarantees `active_spell` is set before first physics frame. If null, `wants_attack()` guard returns false — no crash.

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-spell-001 | spell-system.md | SpellResource data model with id, element, projectile_scene, mana_cost, cast_frame | SpellResource Data Model section |
| TR-spell-002 | spell-system.md | 7-step cast flow: mana check → cooldown → HSM → animation → spawn → signal | Cast Flow section |
| TR-spell-003 | spell-system.md | Mana pool: 100 pts, 25 default cost, 10/s regen after 1.5s delay | Mana Resource section |
| TR-spell-004 | spell-system.md | ATTACK_COOLDOWN = 1.5s between casts | Constants in Mana Resource |
| TR-spell-005 | spell-system.md | 6 MVP spells as data files | MVP Spell Library table |
| TR-spell-006 | spell-system.md | GameManager.spell_cast signal | GameManager Signals section (also in ADR-0002) |
| TR-spell-007 | spell-system.md | Cast direction: horizontal default, diagonal-up optional, Rupture forced horizontal | Cast Direction section |

## Related Decisions

- ADR-0007: SIE receives `spell_cast` signal for interaction tracking
- ADR-0009: Movement System — AttackState in HSM; player script owns mana
- ADR-0013: Spell Slot System — sets `player.active_spell`
- `design/gdd/spell-system.md` — full GDD
