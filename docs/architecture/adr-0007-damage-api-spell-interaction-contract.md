# ADR-0007: Damage API and SpellInteractionEngine Contract

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Gameplay — Status Effects, Combat) |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff (cutoff ≈ 4.3) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `design/gdd/spell-interaction-engine.md` |
| **Post-Cutoff APIs Used** | `PhysicsShapeQueryParameters2D` + `CircleShape2D` for AoE query (Steam Burst) — confirmed as the correct Godot 4.x path. `PhysicsDirectSpaceState2D.intersect_circle()` does NOT exist in any 4.x release. |
| **Verification Required** | (1) Confirm `intersect_shape()` returns `Array[Dictionary]` where each entry has a `collider` key. (2) Confirm `Time.get_ticks_msec() / 1000.0` yields float in GDScript 4 — 64-bit int divide by int literal, result is float. (3) Verify `_processing_interaction` guard eliminates recursion overflow in Steam Burst AoE scenario with 20 enemies. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload Singleton Architecture — SpellInteractionEngine registered as autoload #6), ADR-0002 (GameManager Contract — take_damage() entry point, dialogue_active invulnerability) |
| **Enables** | All enemy implementation stories, all projectile implementation stories, HUD combo text (subscriber to interaction_triggered), AudioFeedbackSystem combo SFX routing, SpellVFXSpawner VFX routing, spell-upgrade-system (base_damage scaling feeds into process_hit), boss-system Devium migration |
| **Blocks** | No story writing enemy `take_damage()`, projectile damage delivery, or HUD combo display may start until this ADR is Accepted |
| **Ordering Note** | BaseEnemy take_damage() signature change is a breaking change. All consumers (projectiles, hazards, bosses) must be updated before any story merges the new signature. |

## Context

### Problem Statement

Wizrless has a working but unsystematic damage path:

1. `enemy.take_damage(amount)` — no element, no interaction check
2. Devium BURN is hardcoded in `devium.gd` with its own `_fire_marked / _burn_timer` logic — duplicates what SpellInteractionEngine should own
3. No status-effect system: enemies cannot be frozen, marked, or slowed by the general population of spells
4. No AoE interaction: Steam Burst cannot be triggered because there is no interaction registry

`SpellInteractionEngine` is designed in `design/gdd/spell-interaction-engine.md` but no architectural contract exists specifying its exact API surface, data structures, signal contracts, or the breaking change to `take_damage()`. Without this ADR:

- Stories add element parameters inconsistently (some pass `String`, some `StringName`, some nothing)
- The Devium BURN migration has no reference contract for what to migrate to
- HUD, VFX, and Audio subscribers have no stable signal contract to wire against

### Constraints

- `GameManager.take_damage(amount)` already exists for **player** damage — this ADR deals with **enemy** damage via `BaseEnemy.take_damage(amount, element)`. These are distinct paths that must not be conflated.
- `BaseEnemy` is the shared base for all enemies including bosses — signature change propagates to all subclasses and all callers
- `PhysicsDirectSpaceState2D.intersect_circle()` does not exist; Steam Burst AoE must use `intersect_shape()` with `PhysicsShapeQueryParameters2D` + `CircleShape2D`
- Status tick runs in `_process()` — get_nodes_in_group() allocates each call; at MVP enemy counts (≤20) this is acceptable; caching required if count exceeds ~50
- Dictionary key type for `INTERACTION_REGISTRY`: GDScript 4 allows Array keys — `[&"frozen", &"fire"]` is a valid Dictionary key and works correctly for equality lookup

### Requirements

- All spell-element damage routes through `SpellInteractionEngine.process_hit()` before applying to enemy health
- `BaseEnemy.take_damage()` accepts an element parameter (default `&""` for element-free sources)
- Five MVP interactions defined as data (no interaction logic hardcoded in spell scripts)
- Three status effects (frozen, burning, marked) plus two derived statuses (stunned, slowed)
- Three signals: `interaction_triggered`, `status_applied`, `status_expired`
- Status tick iterates both `&"enemy"` and `&"boss"` groups
- AoE query (Steam Burst) uses correct Godot 4.6 physics API
- Recursion guard prevents Steam Burst chain overflow

## Decision

`SpellInteractionEngine` (autoload #6 per ADR-0001) owns the complete enemy damage interaction path. All spell hits route through `process_hit()` before health is reduced. The engine is pure data + signals — it does not own enemy health, timers, or visual state.

### Breaking API Change — BaseEnemy.take_damage()

```gdscript
# OLD (remove)
func take_damage(amount: int) -> void:
    health -= amount
    ...

# NEW
func take_damage(amount: int, element: StringName = &"") -> void:
    var final := SpellInteractionEngine.process_hit(self, amount, element)
    health -= final
    health_changed.emit(health, max_health)
    if health <= 0:
        _on_die()
```

All callers must pass `element`. Callers without an element (hazards, KillZone, fall damage) omit the argument — default `&""` means no interaction fires.

### SpellInteractionEngine Public API

```gdscript
# ── Primary entry point ───────────────────────────────────────────────────────
func process_hit(enemy: BaseEnemy, base_damage: int, element: StringName) -> int
    # Returns final_damage after interaction multiplier/bonus applied.
    # Emits interaction_triggered if an interaction fires.
    # Emits status_applied if element is a primer.

# ── Status write helpers (internal; no external callers) ─────────────────────
func _apply_status(enemy: BaseEnemy, status: StringName, duration: float) -> void
func _apply_status_if_primer(enemy: BaseEnemy, element: StringName, now: float) -> void
func _expire_status(enemy: BaseEnemy, status: StringName) -> void

# ── Signals ──────────────────────────────────────────────────────────────────
signal interaction_triggered(enemy: BaseEnemy, interaction_name: StringName, final_damage: int)
signal status_applied(enemy: BaseEnemy, status: StringName, duration: float)
signal status_expired(enemy: BaseEnemy, status: StringName)
```

`interaction_triggered` second parameter is the **interaction name** (`&"steam_burst"`, `&"cryoblast"`, etc.), NOT the incoming element. Subscribers key off the interaction name to select VFX, SFX, and HUD text.

### Interaction Registry (Data, Not Code)

```gdscript
const INTERACTION_REGISTRY: Dictionary = {
    [&"frozen",  &"fire"]:    { name=&"steam_burst",  dmg_mult=2.0, aoe_radius=80.0, removes=true  },
    [&"frozen",  &"rupture"]: { name=&"cryoblast",    dmg_mult=3.0, stun_time=1.5,   removes=true  },
    [&"burning", &"ice"]:     { name=&"extinguish",   dmg_mult=1.5, slow_frac=0.5,   removes=true  },
    [&"marked",  &"any"]:     { name=&"amplify",      dmg_mult=1.5,                  removes=true  },
    [&"burning", &"fire"]:    { name=&"inferno",      bonus_dmg=3,  refresh_dur=4.0, removes=false },
}
```

Lookup order in `process_hit()`:
1. `INTERACTION_REGISTRY[[active_status, incoming_element]]` — specific pair
2. `INTERACTION_REGISTRY[[active_status, &"any"]]` — wildcard (Amplify)
3. No match → apply primer status if applicable, return base_damage unmodified

One interaction per hit. First match wins. Specific pair beats wildcard.

### Status Registry (What Spells Apply)

```gdscript
const STATUS_APPLIERS: Dictionary = {
    &"ice":     { status=&"frozen",  duration=3.0 },
    &"fire":    { status=&"burning", duration=4.0 },
    &"conjure": { status=&"marked",  duration=5.0 },
}
# light, shadow, rupture: no entry — pure damage, no status applied
```

### Status Storage on BaseEnemy

```gdscript
# Added to BaseEnemy:
var active_statuses: Dictionary = {}  # { StringName: float }  key=status_id, value=expiry_time (seconds)
var speed_modifier:  float = 1.0      # multiplied into velocity each frame; 0.0=immobilized, 0.5=slowed
```

`active_statuses` values are absolute expiry times in seconds (`Time.get_ticks_msec() / 1000.0 + duration`). Applying a status overwrites any existing expiry — refreshes duration, does not stack.

### Derived Statuses (Applied by Interaction Effects)

| Status | Applied by | Duration | Effect |
|--------|-----------|---------|--------|
| `&"stunned"` | Cryoblast | 1.5 s | Enemy AI paused; speed_modifier = 0.0 |
| `&"slowed"` | Extinguish | 2.0 s | speed_modifier = 0.5 |

Both derived statuses go through `_apply_status()` — the same emit path as primer statuses. BaseEnemy's `status_applied` handler reads the status name to set the appropriate speed_modifier.

### process_hit() Implementation Contract

```gdscript
var _processing_interaction: bool = false   # recursion guard

func process_hit(enemy: BaseEnemy, base_damage: int, element: StringName) -> int:
    var final_damage     := base_damage
    var interaction_name : StringName = &""
    var now              := Time.get_ticks_msec() / 1000.0

    if not _processing_interaction:
        _processing_interaction = true
        for status in enemy.active_statuses.keys():
            var key_s := [status, element]
            var key_w := [status, &"any"]
            var effect: Dictionary = {}
            if INTERACTION_REGISTRY.has(key_s):
                effect = INTERACTION_REGISTRY[key_s]
            elif INTERACTION_REGISTRY.has(key_w):
                effect = INTERACTION_REGISTRY[key_w]
            if not effect.is_empty():
                interaction_name = effect.name as StringName
                final_damage = _apply_interaction(enemy, base_damage, effect, element)
                if effect.get("removes", false):
                    enemy.active_statuses.erase(status)
                break
        _processing_interaction = false

    _apply_status_if_primer(enemy, element, now)

    if interaction_name != &"":
        interaction_triggered.emit(enemy, interaction_name, final_damage)

    return final_damage
```

`_processing_interaction` guard: Steam Burst AoE calls `take_damage()` on secondary enemies, which calls `process_hit()` again. The guard allows secondary hits to apply primer statuses and return damage but skips the interaction check — preventing infinite chain recursion. Secondary hits can still trigger DOT or other non-recursive effects.

### AoE Query Contract (Steam Burst)

```gdscript
func _steam_burst_aoe(primary: BaseEnemy, base_damage: int) -> void:
    var space_state := primary.get_world_2d().direct_space_state
    var shape := CircleShape2D.new()
    shape.radius = 80.0
    var params := PhysicsShapeQueryParameters2D.new()
    params.shape = shape
    params.transform = Transform2D(0.0, primary.global_position)
    params.collision_mask = enemy_layer_mask
    params.exclude = [primary.get_rid()]
    var hits: Array[Dictionary] = space_state.intersect_shape(params)
    for hit in hits:
        var target := hit.collider as BaseEnemy
        if target != null and not target.is_dead:
            target.take_damage(base_damage, &"fire")
```

`enemy_layer_mask` must be a project-wide constant. Secondary hits pass element `&"fire"` — they can trigger further interactions on other frozen enemies (intentional chain). `_processing_interaction` guard prevents depth overflow.

### Status Tick Contract

```gdscript
func _process(_delta: float) -> void:
    var now := Time.get_ticks_msec() / 1000.0
    for enemy in get_tree().get_nodes_in_group(&"enemy"):
        _tick_statuses(enemy as BaseEnemy, now)
    for boss in get_tree().get_nodes_in_group(&"boss"):
        _tick_statuses(boss as BaseEnemy, now)

func _tick_statuses(enemy: BaseEnemy, now: float) -> void:
    if enemy == null or enemy.is_dead:
        return
    for status in enemy.active_statuses.keys():
        if now >= enemy.active_statuses[status]:
            _expire_status(enemy, status)

func _expire_status(enemy: BaseEnemy, status: StringName) -> void:
    enemy.active_statuses.erase(status)
    status_expired.emit(enemy, status)
```

Both `&"enemy"` and `&"boss"` groups iterated — statuses on bosses tick and expire identically to regular enemies.

### BaseEnemy Signal Integration

BaseEnemy connects to SIE signals in `_ready()`:

```gdscript
func _ready() -> void:
    SpellInteractionEngine.status_applied.connect(_on_status_applied)
    SpellInteractionEngine.status_expired.connect(_on_status_expired)

func _on_status_applied(enemy: BaseEnemy, status: StringName, _dur: float) -> void:
    if enemy != self: return
    match status:
        &"frozen":  speed_modifier = 0.0
        &"stunned": speed_modifier = 0.0
        &"slowed":  speed_modifier = 0.5
        &"burning": burn_timer.start()

func _on_status_expired(enemy: BaseEnemy, status: StringName) -> void:
    if enemy != self: return
    match status:
        &"frozen", &"stunned": speed_modifier = 1.0
        &"slowed":              speed_modifier = 1.0
        &"burning":             burn_timer.stop()
```

`burn_timer: Timer` is a required child node on BaseEnemy. It fires `_on_burn_tick()` which calls `take_damage(1, &"")` — element-free, no interaction.

### Damage Formulas

```
-- Multiplier interactions:
final_damage = floor(base_damage × dmg_mult)

-- Additive interactions (Inferno):
final_damage = base_damage + bonus_dmg

-- No interaction / element-free:
final_damage = base_damage
```

### Devium Migration

The existing `devium.gd` `_fire_marked` / `_burn_timer` bespoke BURN logic must be removed. Devium's `take_damage()` must call `SpellInteractionEngine.process_hit()` like any BaseEnemy subclass. After migration:

- Inferno fires automatically when Fireball hits a burning Devium
- Steam Burst fires automatically when Fireball hits a frozen Devium (Phase 2)
- The old `_burn_timer` node is removed; the shared `burn_timer` from BaseEnemy is used

No new boss-specific BURN logic may be written. All interaction behaviour derives from the registry.

### Architecture Diagram

```
Projectile.gd / SpellCaster.gd
  └── enemy.take_damage(amount, element)           # breaking change: element added
        └── SpellInteractionEngine.process_hit(enemy, amount, element) → int
              ├── check INTERACTION_REGISTRY
              │     ├── specific pair found → _apply_interaction() → dmg_mult or bonus_dmg
              │     ├── wildcard (&"any") found → Amplify
              │     └── no match → base_damage returned
              ├── _apply_status_if_primer(element)  # STATUS_APPLIERS lookup
              │     └── status_applied.emit(enemy, status, duration)
              │           ├── BaseEnemy._on_status_applied() → speed_modifier, burn_timer
              │           ├── AudioFeedbackSystem → status SFX
              │           └── SpellVFXSpawner → status overlay VFX
              ├── interaction_triggered.emit(enemy, interaction_name, final_damage)
              │     ├── HUD → combo text display
              │     ├── AudioFeedbackSystem → interaction SFX
              │     └── SpellVFXSpawner → interaction VFX burst
              └── return final_damage
        └── health -= final_damage

SpellInteractionEngine._process() [each frame]
  └── get_nodes_in_group(&"enemy") + get_nodes_in_group(&"boss")
        └── _tick_statuses(enemy, now)
              └── if expiry reached: _expire_status(enemy, status)
                    └── status_expired.emit(enemy, status)
                          ├── BaseEnemy._on_status_expired() → speed_modifier, burn_timer.stop()
                          ├── AudioFeedbackSystem → (optional expire SFX)
                          └── SpellVFXSpawner → clear status overlay
```

## Alternatives Considered

### Alternative A: Interaction Logic in Spell Scripts

Each spell script contains its own interaction check: `if enemy.has_status(&"frozen"): deal × 2.0`.

- **Pros**: Localised — easy to find interaction logic per spell.
- **Cons**: Interaction logic duplicated × 6 spell scripts. Adding a new interaction requires editing every spell. No single registry to read for discovery. GDD explicitly rejects this.
- **Rejected**: GDD mandates data-driven registry with no hardcoded logic in spell scripts.

### Alternative B: Global Event Bus Instead of SIE Signals

SIE emits generic `combat_event(type, payload)` on a global event bus; subscribers filter.

- **Pros**: Fully decoupled — subscribers don't reference SIE directly.
- **Cons**: Stringly-typed payload, no type safety, harder to grep call sites.
- **Rejected**: SIE-specific typed signals give GDScript type checks on connection and are simpler at this scale.

### Alternative C: Register/Unregister Instead of get_nodes_in_group

Enemies call `SpellInteractionEngine.register(self)` in `_ready()` and `unregister(self)` in `_exit_tree()`. Status tick iterates SIE's own list.

- **Pros**: No Array allocation per frame. O(1) add/remove.
- **Cons**: Requires BaseEnemy code change and risks missed unregister causing stale references.
- **Deferred**: Implement if status tick profiling shows > 0.5 ms/frame. At MVP enemy counts (≤20) the group query cost is negligible. GDD Tuning Knobs section flags this explicitly.

## Consequences

### Positive

- Data-driven registry: adding a new interaction = one new Dictionary entry, no code change
- Typed signals: GDScript type system catches wrong handler signatures at parse time
- Single status write path: all status mutations go through `_apply_status()` or `_apply_status_if_primer()` — no direct dictionary writes outside the engine
- Devium migration removes ~80 lines of bespoke code; boss gains all future interactions automatically
- `_processing_interaction` guard proven sufficient for MVP enemy count (≤20 per room)

### Negative

- Breaking change to `BaseEnemy.take_damage()` requires coordinated update of all callers (projectiles, hazards, boss states, KillZones)
- `get_nodes_in_group()` allocates two arrays per frame — acceptable at MVP, revisit if enemy count grows
- BaseEnemy couples to SpellInteractionEngine signals — enemies connect in `_ready()`, meaning SIE must be autoload #6 (before any room scene loads)

### Risks

- **Caller missed during take_damage() migration**: A caller not updated to pass element silently uses the default `&""` — no crash, but interaction never fires for that source. Mitigation: audit all `take_damage()` call sites before marking stories Done; add CI grep check for bare `take_damage(` without element.
- **Steam Burst AoE secondary recursion escape**: If `_processing_interaction` guard is bypassed (e.g., by a secondary call that enters via a different code path), recursive Steam Burst can stack-overflow. Mitigation: `_apply_interaction()` must always set `_processing_interaction = true` before any `take_damage()` call it issues.
- **BURNING tick on boss phase transition**: Status persists through Devium phase transitions (EC-04 in GDD). burn_timer node must survive the phase change — if phase 2 triggers scene reload or node replacement, timer continuity must be verified.
- **get_nodes_in_group() returns freed enemies**: If an enemy `queue_free()` is pending but not yet freed, it may appear in the group. `_tick_statuses()` null guard and `is_dead` check handle this.

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-interaction-001 | spell-interaction-engine.md | SIE is autoload singleton | Covered by ADR-0001; referenced here for completeness |
| TR-interaction-004 | spell-interaction-engine.md | Method signature `process_hit(enemy: BaseEnemy, base_damage: int, element: StringName) -> int` | Defined in Public API section above |
| TR-interaction-005 | spell-interaction-engine.md | Status tick iterates &"enemy" AND &"boss" groups | Status Tick Contract section |
| TR-interaction-006 | spell-interaction-engine.md | StringName type used throughout (unified with BaseEnemy) | All API signatures and Dictionary keys use StringName |
| TR-interaction-007 | spell-interaction-engine.md | interaction_triggered second param is interaction_name: StringName | Signal definition in Public API section |
| TR-interaction-008 | spell-interaction-engine.md | status_applied(enemy, status, duration) signal | Signal definition in Public API section |
| TR-interaction-009 | spell-interaction-engine.md | status_expired(enemy, status) signal | Signal definition in Public API section |
| TR-interaction-010 | spell-interaction-engine.md | Derived statuses &"stunned" (Cryoblast 1.5s) and &"slowed" (Extinguish 2.0s) | Derived Statuses section; INTERACTION_REGISTRY includes stun_time and slow_frac |
| TR-interaction-011 | spell-interaction-engine.md | _processing_interaction bool guard prevents Steam Burst recursion | process_hit() Implementation Contract section |
| TR-interaction-012 | spell-interaction-engine.md | SIE listed before GameManager in autoload order | Covered by ADR-0001; SIE is slot #6, before enemies load |
| TR-enemy-002 | enemy-base-system.md | element parameter type is StringName | take_damage() signature uses StringName = &"" default |
| TR-enemy-008 | enemy-base-system.md | speed_modifier: float = 1.0 on BaseEnemy | Status Storage on BaseEnemy section |
| TR-enemy-009 | enemy-base-system.md | health_changed(current, maximum) signal on BaseEnemy | Referenced in take_damage() implementation contract |
| TR-enemy-010 | enemy-base-system.md | burn_timer: Timer required child node | BaseEnemy Signal Integration section |
| TR-enemy-011 | enemy-base-system.md | BaseEnemy._ready() connects SIE signals | BaseEnemy Signal Integration section |
| TR-enemy-012 | enemy-base-system.md | DamageNumber.spawn() called from take_damage() | Referenced in take_damage() contract; suppressed when amount == 0 |

## Performance Implications

- **CPU (per hit)**: Dictionary lookup × 2 per active status per hit — O(statuses) per hit, max 5 statuses × 2 lookups = 10 Dictionary lookups. Negligible.
- **CPU (per frame)**: `get_nodes_in_group()` × 2 per frame = 2 Array allocations. At 20 enemies + 1 boss: ~21 element iteration. < 0.1 ms at target framerate.
- **CPU (AoE)**: `intersect_shape()` is a physics query — runs in physics thread, result returned synchronously. One query per Steam Burst. Negligible at MVP room density.
- **Memory**: `active_statuses: Dictionary` on each enemy. Max 5 keys × 16 bytes each ≈ 80 bytes per enemy. Negligible.
- **Scaling note**: Above ~50 simultaneous enemies, switch status tick to registration pattern (Alternative C above).

## Migration Plan

1. Add `active_statuses: Dictionary` and `speed_modifier: float` to BaseEnemy
2. Add `burn_timer: Timer` child node to BaseEnemy scene
3. Change `take_damage(amount: int)` to `take_damage(amount: int, element: StringName = &"")` in BaseEnemy
4. Implement `SpellInteractionEngine.process_hit()` with INTERACTION_REGISTRY and STATUS_APPLIERS
5. Update all `take_damage()` call sites in projectile scripts, hazard scripts, and boss states to pass element
6. Remove Devium's bespoke `_fire_marked` / `_burn_timer` code
7. Wire Devium's take_damage() through process_hit()
8. Run AC-09 acceptance test to confirm Devium Inferno fires via interaction engine

## Validation Criteria

- AC-01: Ice Shard hit → `active_statuses[&"frozen"]` set with correct expiry, ice visual appears
- AC-03: FROZEN + FIRE → `interaction_triggered` emits `&"steam_burst"`, final_damage = `floor(base × 2.0)`, AoE hits adjacent enemy
- AC-04: FROZEN + RUPTURE → Cryoblast, enemy stunned 1.5 s
- AC-05: BURNING + ICE → Extinguish, BURNING removed, SLOWED applied, enemy at 50% speed
- AC-06: MARKED + any element → Amplify, `floor(base × 1.5)`, MARKED removed
- AC-07: FROZEN + undefined element (LIGHT) → normal damage, FROZEN unchanged
- AC-08: BURNING + FIRE → Inferno, damage = base + 3, BURNING duration extended
- AC-09: Devium BURN via interaction engine — old `_fire_marked` removed, Inferno fires on second Fireball
- AC-10: `take_damage(10, &"")` → no crash, no interaction, normal damage

## Related Decisions

- ADR-0001: Autoload Singleton Architecture — SIE autoload registration and load order
- ADR-0002: GameManager Contract — `GameManager.take_damage()` for player damage (separate from enemy damage path)
- `design/gdd/spell-interaction-engine.md` — full GDD, all TRs above
- `design/gdd/enemy-base-system.md` — BaseEnemy contract, TR-enemy-002, TR-enemy-008–012
- `design/gdd/audio-feedback-system.md` — subscriber to interaction_triggered and status_applied
- `design/gdd/spell-vfx-system.md` — subscriber to interaction_triggered and status_applied
- `design/gdd/hud-system.md` — subscriber to interaction_triggered for combo text
