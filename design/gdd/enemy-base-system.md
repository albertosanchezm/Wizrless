# Enemy Base System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-09
> **Implements Pillar**: Controlled Ascension (support), Earned Truth (support)

## Overview

The Enemy Base System defines the contract that all combatants in Wizrless conform to: damage reception, health tracking, death flow, hitbox structure, group membership, and the signal interface the rest of the game uses to observe enemy state. It does not own AI behavior (Enemy AI System), boss-specific mechanics (Boss System), or the damage numbers visual (which is a shared utility). It is the floor on which those systems stand.

At implementation level, the system provides a `BaseEnemy` GDScript class that all enemy scenes extend. The class handles `take_damage()`, health state, death dispatch, and signal emission. Enemy AI states are implemented as LimboAI `LimboState` nodes that read and write to the enemy via the `agent` reference, exactly as the player's state machine does.

Two enemy categories exist: **regular enemies** (traversal threats in zones — patrol, aggro, attack, die) and **bosses** (narrative encounters — intro sequence, phase structure, unique attack patterns, combat barrier). Regular enemies extend `BaseEnemy` directly. Bosses extend `BaseEnemy` and add phase/intro logic in their own class. Devium (`class_name Devium`) is the first boss and the reference implementation.

**Status effects are owned by the Spell Interaction Engine** (`spell-interaction-engine.md`), not BaseEnemy. The projectile calls `take_damage(amount, element)` with an element StringName; BaseEnemy routes through `SpellInteractionEngine.process_hit()` which decides what status to apply, what interaction fires, and what final damage lands. BaseEnemy carries the `active_statuses` dictionary and reacts to `status_applied`/`status_expired` signals to manage side effects (BURNING tick timer, FROZEN speed modifier).

**Revision 2026-05-09:** The previous per-enemy `on_fire_hit() / on_ice_hit() / ...` handler pattern is **superseded** by the centralized engine. Devium's hardcoded BURN logic is replaced by the global BURNING status. See "Status Effect Pattern" section below.

## Player Fantasy

The enemies in Wizrless are not hazards. The regular ones are what happens to a wizard when he stops being a person — hollow shells of former initiates, reduced to the thing the order trained them to do without the self that decided to do it. They are not difficult. They are not meant to be. They are atmosphere and pressure. They make the wizard move.

The bosses are different. The bosses are still people.

When a regular enemy dies, the feedback should be clean and complete: it registered, it answered, it is done. No lingering. No spectacle. The wizard is still moving. The bosses, when they die, should feel like something has ended that cannot be undone — and the wizard is still standing, which means something.

## Detailed Design

### BaseEnemy Class

All enemy scenes extend `BaseEnemy extends CharacterBody2D`. The class provides the shared contract; subclasses override what they need.

```
BaseEnemy
  # Config (set per enemy in subclass or inspector)
  max_health:   int

  # Runtime state
  health:           int
  is_dead:          bool                 # true once death dispatched; blocks further damage
  player:           CharacterBody2D      # resolved in _ready() from group &"player"
  active_statuses:  Dictionary           # { StringName: float expiry_time }, owned by Spell Interaction Engine
  speed_modifier:   float = 1.0          # multiplied into AI velocity each frame; FROZEN sets 0.0, SLOWED sets 0.5

  # Required child nodes
  @onready anim:    AnimatedSprite2D     # or AnimationPlayer
  @onready hitbox:  Area2D               # receives player projectiles + player melee
  @onready burn_timer: Timer             # used by BURNING DOT; started/stopped via status signals

  # Signals
  signal died
  signal health_changed(current: int, maximum: int)

  # Core methods
  func take_damage(amount: int, element: StringName = &"") -> void
  func die() -> void          # override in subclass for cleanup; call super()
  func face_player() -> void  # flips anim.flip_h toward player

  # Status side-effect handlers (connected to SpellInteractionEngine signals in _ready)
  func _on_status_applied(enemy: BaseEnemy, status: StringName, duration: float) -> void
  func _on_status_expired(enemy: BaseEnemy, status: StringName) -> void
```

---

### Damage Reception Flow

1. Projectile's `body_entered` or `area_entered` fires.
2. Projectile calls `enemy.take_damage(damage_value, spell_element)` where `spell_element` is a `StringName` (e.g. `&"fire"`, `&"ice"`).
3. `take_damage()` checks `is_dead` — returns immediately if true.
4. **Routes through engine:** `var final := SpellInteractionEngine.process_hit(self, amount, element)` — engine resolves interactions, applies/refreshes statuses, returns final damage.
5. `health = max(0, health - final)`.
6. `health_changed` signal emitted.
7. `DamageNumber.spawn()` called at enemy position with `final`.
8. If `health == 0`: `is_dead = true` → `_hsm.dispatch(&"die")`.

Element hit handlers are no longer called from `take_damage()` — the engine + status signals replace them. Melee hits (player hitbox area): same flow with `element = &""` (no interaction). Projectile `queue_free()` is the projectile's own responsibility.

---

### Hitbox Structure

All enemies use a single `Area2D` named `Hitbox`:
- Collision layer: enemy layer (layer 4)
- Collision mask: player projectile layer (layer 6) + player melee layer (layer 5)
- `area_entered` → checks group `&"player_projectile"` or `&"player_hitbox"` → calls `take_damage()`

No separate hurtbox. Enemies have no invincibility frames — they take damage every hit. Bosses may implement i-frame logic in their subclass if needed.

---

### Group Membership

| Group | Members | Used by |
|-------|---------|---------|
| `&"enemy"` | All regular enemies | Player spells, AI System, Zone System |
| `&"boss"` | All boss instances | Combat barrier, GameManager signals, Boss System |
| `&"enemy_projectile"` | All enemy-fired projectiles | Player projectiles (cancel on contact), player hitbox |

Regular enemies: `&"enemy"` only. Bosses: `&"boss"` only. No enemy is in both.

---

### Death Flow

1. `take_damage()` sets `is_dead = true`, dispatches `&"die"` to HSM.
2. HSM enters DeathState (defined per enemy).
3. DeathState plays death animation, then calls `die()` on the enemy.
4. `BaseEnemy.die()`: emits `died` signal, calls `queue_free()` after animation.
5. Boss subclass overrides `die()`: also emits `GameManager.boss_defeated`, cleans up boss-specific nodes, then calls `super()`.

---

### Enemy Categories

**Regular enemies:**
- Extend `BaseEnemy` directly
- No intro sequence, no phases
- Health design range: 5–30 HP
- Respawn on room reload; death state not persisted at MVP
- Death: brief animation + `queue_free()`

**Bosses:**
- Extend `BaseEnemy` with named subclass (e.g. `class_name Devium`)
- Add: intro sequence, phase transitions, combat barrier, `GameManager.boss_appeared/defeated` signals
- Health design range: 100–300 HP
- Persistent death: once defeated, boss room stays clear (Save/Load tracks this)
- Death: full animation + `GameManager.boss_defeated` + barrier removal + lore payoff

---

### Status Effect Pattern

**Status effects are owned by the Spell Interaction Engine.** BaseEnemy is a passive participant: it carries `active_statuses` and reacts to `status_applied`/`status_expired` signals to manage side effects.

Three statuses at MVP — full spec in `spell-interaction-engine.md`:

| Status | Applied by | Side effect on BaseEnemy |
|--------|-----------|--------------------------|
| `&"frozen"` | ICE element (3.0s) | `speed_modifier = 0.0` while active; reset to 1.0 on expire |
| `&"burning"` | FIRE element (4.0s) | Start `burn_timer` at apply (1 dmg / 0.8s); stop on expire |
| `&"marked"` | CONJURE element (5.0s) | None — combo catalyst only |

Two derived statuses written by interaction effects (Cryoblast, Extinguish):

| Status | Applied by | Side effect |
|--------|-----------|-------------|
| `&"stunned"` | Cryoblast interaction (1.5s) | AI states must check `&"stunned"` and no-op; or `speed_modifier = 0.0 + attack suppression` |
| `&"slowed"` | Extinguish interaction (2.0s) | `speed_modifier = 0.5` while active; reset to 1.0 on expire |

**Side-effect handler skeleton:**

```gdscript
func _ready() -> void:
    # ... existing setup ...
    SpellInteractionEngine.status_applied.connect(_on_status_applied)
    SpellInteractionEngine.status_expired.connect(_on_status_expired)

func _on_status_applied(target: BaseEnemy, status: StringName, _duration: float) -> void:
    if target != self: return
    match status:
        &"frozen", &"stunned":
            speed_modifier = 0.0
        &"slowed":
            speed_modifier = 0.5
        &"burning":
            burn_timer.start(BURN_TICK)
        &"marked":
            pass   # visual only — handled by VFX system

func _on_status_expired(target: BaseEnemy, status: StringName) -> void:
    if target != self: return
    match status:
        &"frozen", &"stunned", &"slowed":
            speed_modifier = 1.0
        &"burning":
            burn_timer.stop()
        &"marked":
            pass

func _on_burn_tick() -> void:
    take_damage(BURN_TICK_DAMAGE, &"")   # element="" → no further interaction
```

**Devium burn migration:** Devium's previous bespoke `_fire_marked`/`_burn_timer` two-hit-mark logic is **removed**. Devium uses the global BURNING status applied by any FIRE hit. Two-hit-mark mechanic is gone — every fire hit primes burning. The Inferno interaction (BURNING + FIRE) replaces the old "second fire hit triggers burn" rule with "second fire hit refreshes BURNING and adds +3 instant damage".

---

### Interactions with Other Systems

| System | Direction | Exchange |
|--------|-----------|---------|
| Spell System | Spell → Enemy | Projectile calls `take_damage(amount: int, element: StringName = &"")`; BaseEnemy routes through `SpellInteractionEngine.process_hit()` |
| Spell Interaction Engine | Engine → Enemy | Engine writes `active_statuses` + emits `status_applied`/`status_expired`; BaseEnemy handlers react with side effects (timers, speed modifier) |
| Enemy AI System | AI → Enemy | States read/write enemy velocity, health, `player` ref via HSM `agent` |
| Boss System | Boss extends Enemy | Boss subclasses add phase/intro logic on top of `BaseEnemy` |
| Save/Load System | Enemy → Save | Boss defeat state saved; regular enemy state not persisted at MVP |
| Zone/Room System | Zone owns Enemy | Room scene owns enemy instances; room reload respawns regular enemies |
| GameManager | Enemy → | `boss_appeared`, `boss_health_changed`, `boss_defeated` (boss subclass only) |

## Formulas

### Health Thresholds

```
-- Phase trigger (boss):
phase2_threshold_hp = max_health × PHASE2_THRESHOLD
  Devium: 200 × 0.6 = 120 HP

-- Death trigger:
health == 0  →  die()
```

### Burn (BURNING status — owned by Spell Interaction Engine)

```
-- Activation:
any FIRE hit → SpellInteractionEngine applies &"burning" for BURN_DURATION (4.0s)

-- Tick damage:
ticks = floor(BURN_DURATION / BURN_TICK) = floor(4.0 / 0.8) = 5 ticks
total_burn_damage = 5 × BURN_TICK_DAMAGE = 5 × 1 = 5 HP

-- Inferno interaction (BURNING + FIRE again):
direct = base_fire_damage + 3 (additive)
BURNING duration refreshed to 4.0s, tick counter continues
```

`FIREBALL_DAMAGE = 20 HP` per direct hit (canonical value from `spell-system.md`). Devium's previous two-hit-mark logic has been removed — every fire hit primes BURNING immediately.

### Damage Number Color Convention

| Source | Color |
|--------|-------|
| Default / physical | White `Color.WHITE` |
| Fire / burn | Orange `Color(1.0, 0.55, 0.1, 1.0)` |
| Ice | Light blue `Color(0.4, 0.8, 1.0, 1.0)` |
| Light | Bright yellow `Color(1.0, 1.0, 0.4, 1.0)` |
| Shadow | Purple `Color(0.7, 0.3, 1.0, 1.0)` |
| Conjure | Teal `Color(0.2, 0.9, 0.7, 1.0)` |
| Rupture | Dark red `Color(0.8, 0.1, 0.1, 1.0)` |

*Colors are design targets — final values set in art pass.*

### Variable Definitions

| Variable | Value | Owner | Description |
|----------|-------|-------|-------------|
| `max_health` | Per enemy | Subclass | Total health pool |
| `PHASE2_THRESHOLD` | 0.6 | Devium | HP ratio that triggers phase 2 |
| `BURN_DURATION` | 4.0 s | Spell Interaction Engine | How long BURNING lasts |
| `BURN_TICK` | 0.8 s | Spell Interaction Engine | Interval between burn damage ticks |
| `BURN_TICK_DAMAGE` | 1 HP | Spell Interaction Engine | Damage per burn tick |
| `FIREBALL_DAMAGE` | 20 HP | Spell System | Canonical Fireball direct damage (was 10 — corrected per W-08) |

## Edge Cases

**EC-01 — Damage received while dead.**
`take_damage()` checks `is_dead` first — returns immediately if true. No health change, no signal, no damage number, no element handler. In-flight projectiles colliding after death are silently ignored.

**EC-02 — (Removed)**
Two-hit-mark mechanic deprecated 2026-05-09. Every FIRE hit primes BURNING immediately via Spell Interaction Engine.

**EC-03 — Fire hit during active BURNING.**
Inferno interaction fires (`BURNING + FIRE`): adds +3 instant damage and refreshes BURNING duration to 4.0s. Tick timer continues — no double-tick, no double DOT. Sustained fire barrage keeps enemy BURNING indefinitely with +3 bonus per refresh hit.

**EC-04 — Enemy killed by burn tick.**
Burn tick calls `take_damage(BURN_DAMAGE)`. If `health` reaches 0, `is_dead = true` and `&"die"` dispatches normally. Death flow identical to direct hit.

**EC-05 — Player dies while fighting a regular enemy.**
Regular enemy does not react to `GameManager.player_died`. AI loop continues. Room reloads from checkpoint — enemy respawns fresh. Boss subclasses connect explicitly (e.g. combat barrier removal).

**EC-06 — Two projectiles hit the same frame.**
Both `area_entered` callbacks fire in the same physics frame. First call: `is_dead` false, damage applies. If enemy dies, `is_dead = true`. Second call: returns immediately. One death dispatch only.

**EC-07 — Element hit handler not implemented.**
`BaseEnemy` no-op returns immediately. No error. Direct damage from `take_damage()` still applied. Status effect absent. Correct: only enemies designed to support a given element implement the handler.

**EC-08 — Boss health crosses phase 2 threshold mid-attack.**
`take_damage()` checks threshold after health update. Dispatches `&"phase2_start"` — ANYSTATE transition in HSM. Current attack state exits via `_exit()`. Phase 2 transition begins. Clean interruption by design.

**EC-09 — Conjure spell hit (0 damage).**
`take_damage(0)` called. Health unchanged. `DamageNumber.spawn()` must be suppressed when `amount == 0` — showing a "0" is misleading. `on_conjure_hit()` fires regardless: the interaction is the point, not the damage.

**EC-10 — Enemy loaded before player enters scene.**
`get_first_node_in_group(&"player")` returns null. `face_player()` guards null. All AI states that reference `player` return early if `not _e.player`. Enemy idles safely until player is present.

## Dependencies

### Systems this requires

| System | What Enemy Base needs |
|--------|----------------------|
| **LimboAI addon** | `LimboHSM` and `LimboState` — HSM runtime for all enemy AI |
| **DamageNumber utility** | `DamageNumber.spawn(parent, amount, position, color)` — called from `take_damage()` |
| **GameManager autoload** | `boss_appeared`, `boss_health_changed`, `boss_defeated`, `player_died` signals (boss subclasses only) |
| **Spell System** | `SpellElement` enum — passed into `take_damage()` to route element handlers |

Note: `BaseEnemy` does not depend on the player Health System — enemies manage their own health pools independently.

### Systems that require this

| System | What it needs from Enemy Base |
|--------|------------------------------|
| **Enemy AI System** | `BaseEnemy` class; `health`, `is_dead`, `player`, `face_player()` via HSM `agent` |
| **Boss System** | Extends `BaseEnemy`; relies on `take_damage()`, `die()`, `died` signal, HSM dispatch |
| **Spell System** | Projectile scenes call `enemy.take_damage(amount, element)` + element hit handlers |
| **Zone/Room System** | Owns enemy scene instances; respawns regular enemies on room reload |
| **Save/Load System** | Reads boss defeat state to keep boss rooms clear after first defeat |
| **HUD System** | Boss subclass emits `GameManager.boss_health_changed` — boss health bar reads this |
| **Hazard System** | Hazards damage the player only — they do not call `take_damage()` on enemies |

### Hard blockers (must exist before Enemy Base is testable)

- LimboAI addon: installed and active
- `DamageNumber` utility: autoload or static method available
- `SpellElement` enum: defined (Spell System dependency)
- `BaseEnemy` class written and at least one subclass scene created

## Tuning Knobs

### Regular Enemy Knobs (per enemy subclass)

| Knob | Design Range | Gameplay Effect |
|------|-------------|-----------------|
| `max_health` | 5–30 HP | Survivability. Below 5: dies in one hit (acceptable for weak enemies). Above 30: regular enemy becomes a damage sponge, breaks traversal pace. |
| Direct hit damage | 5–25 HP/hit | Set in projectile scenes. Target: 2–4 hits to kill a regular enemy. Tune `max_health` relative to spell damage, not independently. |

### Boss Knobs (per boss subclass)

| Knob | Current (Devium) | Design Range | Gameplay Effect |
|------|-----------------|-------------|-----------------|
| `max_health` | 200 HP | 100–300 | Fight length. At 200 HP + 10 HP/hit: 20 direct hits minimum. Too low: patterns not readable before fight ends. Too high: attrition without drama. |
| `PHASE2_THRESHOLD` | 0.6 | 0.4–0.7 | Phase 2 trigger point. 0.6 gives roughly equal phase lengths. Lower = longer phase 1; higher = phase 2 dominates. |

### Burn Status Effect Knobs (Devium)

| Knob | Current | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `BURN_WINDOW` | 2.5 s | 1.5–4.0 | Burn activation difficulty. Shorter = requires rapid double-tap. Longer = forgiving. |
| `BURN_DURATION` | 4.0 s | 2.0–6.0 | Burn payoff window. Shorter = must re-apply often. Longer = one activation dominates. |
| `BURN_TICK` | 0.8 s | 0.4–1.5 | Damage cadence. Shorter = faster total damage + more visual feedback. |
| `BURN_DAMAGE` | 1 HP/tick | 1–5 | Per-tick damage. At 1 HP: burn is a minor bonus. At 5 HP: burn becomes the primary source. Keep low — direct hits should remain the priority. |
| `FIREBALL_DAMAGE` | 10 HP | 5–20 | Direct fire hit damage. Target: 8–12% of boss `max_health` per hit. |

### Interaction Between Knobs

- `BURN_DAMAGE × ticks` should stay below `FIREBALL_DAMAGE × 2` — burn rewards the combo but direct hits stay primary.
- `BURN_WINDOW` vs cast cadence: at 2.5s window + 1.5s cooldown, the player has one cast to confirm the second hit. Tighten for challenge, loosen for accessibility.
- Boss `max_health` should survive a full-mana player burst: `floor(100/25) × 10 = 40 HP` per mana cycle. At 200 HP: 5 full cycles minimum — enough time to read all attack patterns.

## Visual/Audio Requirements

### Damage Numbers

Shared `DamageNumber` scene utility. Spawns at enemy position on `take_damage()`, floats upward, fades out.

- Color driven by element (see Formulas — color convention table)
- Amount `0` suppressed — Conjure hits show nothing
- Spawn offset: `global_position + Vector2(randf_range(-12, 12), -40)` — adjust Y for tall sprites

### Hit Flash

All enemies need a white modulate flash on `take_damage()` to confirm damage registered:
- Duration: ~0.08s on sprite modulate
- **Not yet implemented on BaseEnemy** — must be added to base class
- Bosses may use element-tinted flash for dramatic emphasis

### Death Animations

**Regular enemies:**
- Single animation on `AnimatedSprite2D`, duration 0.3–0.6s
- `queue_free()` immediately on animation end — no lingering
- Polish addition: brief dissolve particle burst

**Bosses:**
- Full death animation, 1–3s duration
- Screen effects (flash, brief slow-mo) are Boss System scope
- `queue_free()` after animation + Boss System cleanup completes

### Status Effect Visuals

| Effect | Visual | Status |
|--------|--------|--------|
| Burn | `BurnIndicator` node above head — animated flame sprite | Implemented (Devium) |
| Ice slow | Blue tint on sprite modulate | Not implemented |
| Light blind | Yellow aura flicker | Not implemented |
| Shadow weaken | Desaturation on sprite modulate | Not implemented |
| Armor break (Rupture) | Crack overlay or brief red flash | Not implemented |

### Sound Effects

| Event | SFX | Status |
|-------|-----|--------|
| Take damage | Impact grunt/thud per enemy type | Not standardized |
| Death (regular) | Short end sound | Not implemented |
| Death (boss) | Weighted, final impact | Not implemented |
| Burn activation | Ignition crackle | Not implemented |
| Burn ticking | Soft crackle loop | Not implemented |

## UI Requirements

### Regular Enemies

No HUD elements. Damage numbers are the only feedback. Intentional — regular enemies are traversal pressure, not resource puzzles. A health bar would invite attrition thinking over movement.

### Boss Health Bar

Owned by HUD System GDD. Enemy Base specifies signal contract only:

- `GameManager.boss_appeared(id: StringName, name: String, max_hp: int)` — HUD shows bar
- `GameManager.boss_health_changed(current: int, maximum: int)` — HUD updates bar
- `GameManager.boss_defeated(id: StringName)` — HUD hides bar

Bar appears on `boss_appeared`, persists through fight, disappears on `boss_defeated` or `player_died`.

### Phase Transition Feedback

Boss System concern. No HUD element at MVP — visual change in boss behavior and animation is the signal. "Phase 2" text flash is a polish addition only.

### Status Effect Indicators

Communicated through world-space visuals on the enemy sprite (burn indicator node, modulate tints). No HUD element tracks enemy status at MVP.

### Nothing else required

Enemy Base System does not drive any player-facing HUD element.

## Acceptance Criteria

**AC-01 — Projectile deals damage.**
Fire Fireball at a regular enemy. Health decreases by `FIREBALL_DAMAGE`. Damage number appears at enemy position in orange. Pass: correct HP reduction, colored number visible.

**AC-02 — Damage blocked after death.**
Kill enemy. Fire another projectile at the corpse during death animation. Health does not change. No second damage number. Pass: `is_dead` guard works; no double-death dispatch.

**AC-03 — Hit flash on damage.**
Hit any enemy. Sprite briefly flashes white (~0.08s). Pass: flash visible on every hit, correct duration.

**AC-04 — Enemy dies at zero health.**
Deal enough damage to reduce health to 0. Death animation plays. Enemy removed after animation ends. Pass: no stuck enemy, clean scene removal.

**AC-05 — Regular enemy has no health bar.**
Engage a regular enemy at any health value. No health bar appears on HUD. Pass: zero HUD elements added.

**AC-06 — Boss health bar appears on engagement.**
Enter Devium fight. `boss_appeared` fires. Boss health bar appears showing full health. Pass: bar visible with correct max value.

**AC-07 — Boss health bar tracks damage.**
Deal 10 damage to Devium. Boss health bar decreases by 5% (10/200). Pass: bar reflects every `take_damage()` call in real time.

**AC-08 — Boss health bar disappears on defeat.**
Defeat Devium. `boss_defeated` fires. Boss health bar disappears. Pass: bar gone within one frame of signal.

**AC-09 — Burn activates on two fire hits within window.**
Hit Devium with Fireball. Wait less than 2.5s. Hit again. Burn indicator appears. Damage numbers tick at ~0.8s interval. Pass: indicator visible, ticking begins.

**AC-10 — Burn mark expires if second hit is too slow.**
Hit Devium with Fireball. Wait more than 2.5s. Hit again. No burn activates. Pass: second hit deals direct damage only; no burn indicator.

**AC-11 — Burn deals correct tick count.**
Activate burn. Count damage numbers over 4s. Five ticks appear. Pass: exactly 5 ticks at ~0.8s intervals.

**AC-12 — Phase 2 triggers at health threshold.**
Reduce Devium to below 120 HP (60% of 200). Phase 2 transition fires immediately. Pass: triggers at correct threshold; does not fire at 121 HP.

**AC-13 — Conjure hit shows no damage number.**
Hit Devium with Conjure (0 damage). No damage number appears. Pass: zero-damage hits produce no number.

**AC-14 — Unimplemented element handler causes no crash.**
Hit an enemy without `on_ice_hit()` with Ice Shard. Enemy takes direct damage. No crash. No status effect. Pass: `take_damage()` completes cleanly; no errors in log.

**AC-15 — Enemy idles safely without player in scene.**
Load enemy scene with no player node present. Enemy does not crash. Idle state runs. Pass: no null reference errors in output log.
