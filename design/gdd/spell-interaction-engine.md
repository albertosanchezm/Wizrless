# Spell Interaction Engine

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-03
> **Implements Pillar**: Spell Alchemy (primary) + Controlled Ascension (discovery reward)

## Overview

The Spell Interaction Engine defines how spells combine to produce effects greater than their individual parts. It is the mechanical core of the Spell Alchemy pillar and the primary source of replayability.

The engine works through **status effects**. Certain spells apply a status to an enemy on hit. Subsequent spells that hit that same enemy check the status against an **interaction registry** — a data table mapping `(status, incoming_element)` pairs to named effects. If a pair is found: the interaction fires. If not: normal damage applies and the status is preserved. Undefined pairs are not bugs — they are a deliberate designed state meaning "no special reaction."

**Five MVP interactions are defined.** With 6 spell elements, there are 30 ordered pairs. Defining 5 means 25 are deliberately undefined at MVP. That ratio is intentional — the discovery of what works and what does not is itself gameplay. Post-MVP iterations add more pairs as new spells and elements are introduced.

Order matters. Ice Shard hitting a burning enemy triggers Extinguish. Fireball hitting a frozen enemy triggers Steam Burst. These are different reactions because the status on the target is different — no global cast-history queue is needed. The target carries the context.

The engine requires one breaking change to the existing damage API: `take_damage(amount, element)` must accept an element parameter. All callers must be updated.

## Player Fantasy

The player casts Ice Shard. The enemy stops moving, encased in frost. The player sees it. Pauses. Then fires Fireball.

The world explodes.

Not because the player read a tooltip. Because they made a guess — "ice and fire should interact" — and the game validated that intuition with a spectacular effect. The first discovery feels like finding a secret. The second feels like understanding a rule. The third feels like mastery.

Every element pair the player has not yet tried is a question mark. Every question mark is a reason to experiment. The game never runs out of questions to ask.

## Detailed Design

### Engine Architecture

`SpellInteractionEngine` is an autoload singleton. It owns:
- The **status registry**: what each spell element applies on hit
- The **interaction registry**: `(active_status, incoming_element) → InteractionEffect`
- The **status tick loop**: processes ongoing DOT/slow effects each frame
- The **query method**: called by every `take_damage()` invocation

```
Enemy.take_damage(amount, element)
  → SpellInteractionEngine.process_hit(enemy, amount, element)
    → check active_statuses for interaction with element
    → if interaction found:  fire effect, remove/refresh status
    → if this element is a status applier:  add status
    → return final_damage to caller
  → enemy.health -= final_damage
```

`take_damage()` must be updated to accept `element: StringName = &""`. All callers updated. Empty string means "no element" — environmental hazards, fall damage. No interaction fires.

---

### Status Effects (What Spells Apply)

Three status effects at MVP. Each applied by one spell element on hit.

| Status ID | Applied by | Duration | Ongoing Effect | Visual |
|-----------|-----------|---------|----------------|--------|
| `&"frozen"` | ICE | 3.0 s | Speed = 0 (immobilized) | Ice crystal overlay on enemy sprite |
| `&"burning"` | FIRE | 4.0 s | 1 dmg / 0.8 s (5 ticks) | Flame particles above enemy |
| `&"marked"` | CONJURE | 5.0 s | None — combo catalyst only | Pulsing sigil above enemy head |

**Status rules:**
- One instance per status per enemy. Applying same status again on active: refreshes duration, does not stack.
- Multiple different statuses can coexist on same enemy (enemy can be both FROZEN and MARKED).
- Status removed when: duration expires, interaction fires (see table below), or enemy dies.
- `active_statuses: Dictionary = {}` on each enemy. Key: `StringName`, value: `float` (expiry time, using `Time.get_ticks_msec()`).

**LIGHT, SHADOW, and RUPTURE** do not apply statuses at MVP. They are pure damage dealers — effective at consuming existing statuses (Rupture + FROZEN = Cryoblast) but do not prime enemies themselves. This asymmetry is intentional: Ice, Fire, and Conjure are primers; Light, Shadow, Rupture are detonators.

---

### Interaction Registry (5 MVP Pairs)

All interactions defined as data. No interaction logic hardcoded in individual spell scripts.

| # | Required Status | Incoming Element | Interaction Name | Effect | Removes Status? |
|---|----------------|-----------------|-----------------|--------|----------------|
| 1 | `&"frozen"` | FIRE | **Steam Burst** | ×2.0 dmg to primary target + 80 px AoE dealing base dmg to nearby enemies | Yes |
| 2 | `&"frozen"` | RUPTURE | **Cryoblast** | ×3.0 dmg, stuns enemy 1.5 s (velocity = 0, no attack) | Yes |
| 3 | `&"burning"` | ICE | **Extinguish** | ×1.5 dmg, removes BURNING, applies SLOWED 50% for 2.0 s | Yes |
| 4 | `&"marked"` | any | **Amplify** | ×1.5 dmg to the triggering hit | Yes |
| 5 | `&"burning"` | FIRE | **Inferno** | +3 instant damage, BURNING duration reset to 4.0 s | No (refreshed) |

**Undefined-pair behavior**: Spell deals normal damage. Active status on enemy is unchanged. No crash, no log spam. Player receives no indication that the pair was undefined — the spell just does normal damage. Discovery of what *is* defined comes from experimentation.

**Amplify interaction (#4)**: MARKED interacts with *any* element. It is the universal catalyst. Conjure's design role is to set up Amplify, then the player fires whatever spell they have for a guaranteed bonus. This makes Conjure useful in every loadout regardless of the player's other equipped spell.

---

### Interaction Data Structure

Defined as a constant dictionary in `SpellInteractionEngine`:

```gdscript
const INTERACTION_REGISTRY: Dictionary = {
    [&"frozen",  &"fire"]:    { name=&"steam_burst",  dmg_mult=2.0, aoe_radius=80.0, removes=true  },
    [&"frozen",  &"rupture"]: { name=&"cryoblast",    dmg_mult=3.0, stun_time=1.5,   removes=true  },
    [&"burning", &"ice"]:     { name=&"extinguish",   dmg_mult=1.5, slow_frac=0.5,   removes=true  },
    [&"marked",  &"any"]:     { name=&"amplify",      dmg_mult=1.5,                  removes=true  },
    [&"burning", &"fire"]:    { name=&"inferno",      bonus_dmg=3,  refresh_dur=4.0, removes=false },
}
```

`[&"marked", &"any"]` uses the sentinel key `&"any"` — engine checks for MARKED first, then falls through to the `any` key if no specific element match found. This ensures Amplify fires for all elements without duplicating 6 rows.

**Lookup order** in `process_hit()`:
1. Check `INTERACTION_REGISTRY[[active_status, incoming_element]]` — specific pair
2. Check `INTERACTION_REGISTRY[[active_status, &"any"]]` — wildcard
3. No match → apply status if this element is a primer, else normal damage

---

### Process Hit Method

```gdscript
# SpellInteractionEngine.gd (autoload)

func process_hit(enemy: BaseEnemy, base_damage: int, element: StringName) -> int:
    var final_damage := base_damage
    var now         := Time.get_ticks_msec() / 1000.0

    # 1. Check active statuses for interaction
    for status in enemy.active_statuses.keys():
        var key_specific := [status, element]
        var key_wildcard := [status, &"any"]
        var effect: Dictionary = {}

        if INTERACTION_REGISTRY.has(key_specific):
            effect = INTERACTION_REGISTRY[key_specific]
        elif INTERACTION_REGISTRY.has(key_wildcard):
            effect = INTERACTION_REGISTRY[key_wildcard]

        if not effect.is_empty():
            final_damage = _apply_interaction(enemy, base_damage, effect, element)
            if effect.get("removes", false):
                enemy.active_statuses.erase(status)
            break  # one interaction per hit

    # 2. Apply status if this element is a primer
    _apply_status_if_primer(enemy, element, now)

    # 3. Emit signal for HUD/VFX/audio
    if final_damage != base_damage:
        interaction_triggered.emit(enemy, element, final_damage)

    return final_damage
```

One interaction per hit. If enemy has both FROZEN and MARKED and player fires Fireball: check statuses in order (deterministic iteration). First match wins. FROZEN wins over MARKED for FIRE element because FROZEN+FIRE = Steam Burst exists as a specific pair. Amplify (wildcard) only fires if no specific pair matches first.

---

### Interaction Effects Implementation

Each named effect maps to a method in `SpellInteractionEngine`:

**Steam Burst (FROZEN + FIRE):**
- Primary target: `base_damage × 2.0`
- AoE: `PhysicsDirectSpaceState2D` overlap query, radius 80 px, enemy layer
- Each enemy in radius: `take_damage(base_damage, &"fire")` — no element interaction, raw damage
- Visual: explosion particle burst at target position
- Sound: `sfx_steam_burst`

**Cryoblast (FROZEN + RUPTURE):**
- Primary target: `base_damage × 3.0`
- Stun: `enemy.add_status(&"stunned", 1.5)` — enemy AI state paused
- Visual: ice shard explosion outward
- Sound: `sfx_cryoblast`

**Extinguish (BURNING + ICE):**
- Primary target: `base_damage × 1.5`
- Removes BURNING status (ongoing tick stops)
- Applies SLOWED: `enemy.active_statuses[&"slowed"] = now + 2.0`, movement speed × 0.5
- Visual: steam cloud, fire extinguished
- Sound: `sfx_extinguish`

**Amplify (MARKED + any):**
- Primary target: `base_damage × 1.5`
- Removes MARKED
- Visual: sigil flash at hit point
- Sound: `sfx_amplify`

**Inferno (BURNING + FIRE):**
- Primary target: `base_damage + 3` (additive, not multiplied)
- BURNING duration refreshed to 4.0 s from now
- BURNING tick damage unchanged
- Visual: flame burst intensifies
- Sound: `sfx_inferno` (heavier crackle)

---

### Status Application

Each element's status-applying behavior:

```gdscript
const STATUS_APPLIERS: Dictionary = {
    &"ice":     { status=&"frozen",  duration=3.0 },
    &"fire":    { status=&"burning", duration=4.0 },
    &"conjure": { status=&"marked",  duration=5.0 },
}
# light, shadow, rupture: not in STATUS_APPLIERS — no status applied

func _apply_status_if_primer(enemy: BaseEnemy, element: StringName, now: float) -> void:
    if not STATUS_APPLIERS.has(element): return
    var entry  := STATUS_APPLIERS[element]
    var status := entry.status as StringName
    enemy.active_statuses[status] = now + entry.duration
```

Applying a status the enemy already has simply overwrites the expiry — extends duration. Does not double-apply the ongoing effect.

---

### Status Tick Processing

`SpellInteractionEngine._process(delta)` iterates all living enemies:

```gdscript
func _process(_delta: float) -> void:
    var now := Time.get_ticks_msec() / 1000.0
    for enemy in get_tree().get_nodes_in_group(&"enemies"):
        _tick_statuses(enemy as BaseEnemy, now)

func _tick_statuses(enemy: BaseEnemy, now: float) -> void:
    for status in enemy.active_statuses.keys():
        if now >= enemy.active_statuses[status]:
            _expire_status(enemy, status)
            enemy.active_statuses.erase(status)
```

BURNING tick damage is a separate `Timer` on the enemy — started when BURNING applied, stopped when BURNING removed or expired. `SpellInteractionEngine` signals the enemy to start/stop the burn timer; the enemy's own `Timer` node fires the DOT.

FROZEN immobilizes by setting `enemy.current_speed_modifier = 0.0` — enemy AI reads this modifier before setting velocity. On expiry: modifier reset to `1.0`.

---

### Enemy Integration Requirements

Every enemy that can receive status effects needs:

```gdscript
# BaseEnemy additions:
var active_statuses: Dictionary = {}   # { StringName: float expiry_time }
var speed_modifier:  float = 1.0       # multiplied into velocity each frame

# In take_damage(), replace:
#   GameManager.take_damage(amount)
# With:
#   var final := SpellInteractionEngine.process_hit(self, amount, element)
#   health -= final
#   ...existing death/damage logic
```

`take_damage()` signature change: `func take_damage(amount: int, element: StringName = &"") -> void`

This is the breaking API change mentioned in Overview. Every call site (hazards, boss states, projectile scripts) must pass element. Calls without element (e.g., KillZone) pass default `&""` — no interaction fires.

---

### Signals

```gdscript
# SpellInteractionEngine signals:
signal interaction_triggered(enemy: BaseEnemy, element: StringName, final_damage: int)
signal status_applied(enemy: BaseEnemy, status: StringName, duration: float)
signal status_expired(enemy: BaseEnemy, status: StringName)
```

HUD/VFX system subscribes to `interaction_triggered` for combo text. Audio subscribes for combo sounds. No caller needs to know what interaction fired — the signal carries what happened.

---

### Devium BURN Refactor

The existing hardcoded BURN logic in `devium.gd` (the `_fire_marked` / `_burn_timer` pattern) must be **replaced** by the interaction engine's BURNING status. Devium's `take_damage()` must call `SpellInteractionEngine.process_hit()` like any regular enemy. The Inferno and Steam Burst interactions automatically work on Devium once he is wired up.

This is the primary migration path from the prototyped system to the generalized one.

---

### Interaction Discovery (No Tutorial)

Players are never told which interactions exist. Discovery is the reward. The only hint system is the status visual — seeing an enemy freeze is information. The pulsing MARKED sigil is information. The player connects the dots.

Post-MVP: a "grimoire" UI could display discovered interactions. At MVP: none. If a player never discovers Steam Burst, that is fine — they still have all the base spells.

## Formulas

### Final Damage Calculation

```
-- Multiplier interactions (Steam Burst, Cryoblast, Extinguish, Amplify):
final_damage = floor(base_damage × dmg_mult)

-- Additive interactions (Inferno):
final_damage = base_damage + bonus_dmg

-- No interaction:
final_damage = base_damage

Examples:
  Fireball (base 20) hits FROZEN enemy → Steam Burst:
    final = floor(20 × 2.0) = 40

  Rupture (base 25) hits FROZEN enemy → Cryoblast:
    final = floor(25 × 3.0) = 75

  Ice Shard (base 15) hits BURNING enemy → Extinguish:
    final = floor(15 × 1.5) = 22

  Any spell (base N) hits MARKED enemy → Amplify:
    final = floor(N × 1.5)

  Fireball (base 20) hits BURNING enemy → Inferno:
    final = 20 + 3 = 23  (plus burn DOT refresh)
```

### BURNING Tick Damage

```
tick_damage   = 1 HP
tick_interval = 0.8 s
duration      = 4.0 s
total_ticks   = floor(4.0 / 0.8) = 5
total_dot_dmg = 5 × 1 = 5 HP over 4 s

Inferno refresh: resets duration, same tick rate.
Max DOT from Inferno chain: player must reapply before 4s window expires.
```

### FROZEN Immobilization

```
frozen_speed_modifier = 0.0   (movement suppressed)
frozen_duration       = 3.0 s
attack_suppressed     = false  (frozen enemy can still attack — just can't move)
```

### AoE Query (Steam Burst)

```
AoE radius   = 80 px
Query method = PhysicsDirectSpaceState2D.intersect_circle(origin, radius, exclude=[primary])
Damage dealt = base_damage (no multiplier for secondary targets)
Element      = &"fire"  (secondary hits can trigger interactions on other frozen enemies)
```

### Status Duration Precedence

```
Apply:   active_statuses[status] = now + duration
Refresh: same line — overwrites expiry, extends if remaining > 0, resets if expired
Stack:   NOT supported. One instance per status per enemy.
```

### Variable Definitions

| Variable | Default | Description |
|----------|---------|-------------|
| `frozen` duration | 3.0 s | FROZEN status lifetime |
| `burning` duration | 4.0 s | BURNING status lifetime |
| `marked` duration | 5.0 s | MARKED status lifetime |
| `stunned` duration | 1.5 s | Cryoblast stun duration |
| `slowed` fraction | 0.5 | Extinguish speed multiplier |
| `slowed` duration | 2.0 s | Extinguish slow lifetime |
| Steam Burst AoE | 80 px | Secondary target radius |
| Steam Burst dmg mult | 2.0× | Primary target multiplier |
| Cryoblast dmg mult | 3.0× | Primary target multiplier |
| Extinguish dmg mult | 1.5× | Primary target multiplier |
| Amplify dmg mult | 1.5× | Universal catalyst multiplier |
| Inferno bonus | +3 | Flat damage bonus on BURNING+FIRE |

## Edge Cases

**EC-01 — Enemy has two statuses; spell matches both.**
`process_hit()` iterates `active_statuses.keys()`. First match wins. Specific pair beats wildcard. Between two specific matches: iteration order is insertion order (GDScript 4 Dictionary guarantees). Design rule: do not place an enemy in a situation where two specific-pair matches can fire on the same hit. Status visuals show player what is active — player chooses which to detonate.

**EC-02 — Interaction's AoE (Steam Burst) hits another FROZEN enemy.**
Secondary `take_damage()` call includes element `&"fire"`. That secondary enemy checks its own `active_statuses`. If it is also FROZEN: another Steam Burst fires on it. Chain reaction is valid and intentional. In practice, two FROZEN enemies adjacent is a rare level design scenario.

**EC-03 — Enemy dies during status tick.**
`_expire_status()` checks `enemy.is_dead` — if dead, skips tick and removes status. No damage after death. `active_statuses` is cleared in enemy `_on_die()`. No dangling timers.

**EC-04 — Devium enters Phase 2 while BURNING.**
Status persists through phase transition. BURNING tick timer continues. Phase 2 entry does not clear `active_statuses`. Correct — continuous status should not reward phase transitions.

**EC-05 — Player fires Conjure, MARKED applied. Player switches spell before MARKED expires.**
MARKED has 5s duration. Player can apply MARKED, switch to Rupture, fire Rupture at MARKED enemy → Amplify (1.5×) fires. Intended combo path. No guard needed.

**EC-06 — `element = &""` from a hazard or KillZone.**
`_apply_status_if_primer()`: `STATUS_APPLIERS.has(&"") = false` → no status applied. Interaction lookup: `INTERACTION_REGISTRY.has([status, &""])` → false. Normal damage, no interaction. Correct.

**EC-07 — FROZEN applied then enemy pathed into KillZone.**
Enemy dies instantly. `active_statuses` cleared. Status tick abandoned. No issue.

**EC-08 — interaction_triggered signal causes AoE recursion depth overflow.**
Steam Burst AoE hits enemies, each calling `take_damage()`, each calling `process_hit()`, each potentially triggering more Steam Bursts. Mitigated by: AoE damage does NOT trigger status application (secondary hits pass raw damage after checking interactions — no new FROZEN applied). Chain depth is bounded by enemy count in radius. Max enemies per room = 20. Worst case = 20 chained Steam Bursts in one frame. Acceptable. Guard: set `_processing_interaction = true` in `process_hit()` → secondary calls skip interaction check.

**EC-09 — Status visual not cleaned up when status removed mid-room.**
Status expire signal → enemy clears visual modifier. Signal `status_expired.emit(enemy, status)` → enemy's visual script clears overlay. If enemy `queue_free()` fires before signal: no crash (signal discarded, visual freed with enemy). Correct.

**EC-10 — `take_damage()` called before `SpellInteractionEngine` autoload is ready.**
Autoload order in `project.godot` must place `SpellInteractionEngine` before any enemy or room scene loads. Use `get_node_or_null("/root/SpellInteractionEngine")` with null guard in early calls. Engine autoloads in declaration order — ensure this autoload is listed before GameManager or add check.

## Dependencies

| System | Direction | What this system needs |
|--------|-----------|----------------------|
| **Spell System** | Reads | Spell element (`StringName`) from SpellResource used as `incoming_element` in interaction lookup |
| **Spell Slot System** | Reads | Currently equipped spell determines element passed to `process_hit()` |
| **Enemy Base System** | Modifies | Adds `active_statuses: Dictionary` and `speed_modifier: float` to BaseEnemy. Replaces `take_damage()` signature. |
| **Health System** | Downstream | Final damage from `process_hit()` feeds into the same health reduction path |
| **Boss System** | Consumer | Devium's existing BURN logic replaced by this engine. All boss enemies wire into `process_hit()`. |
| **HUD / Spell VFX System** | Subscriber | `interaction_triggered` signal drives combo text and VFX |
| **Audio Feedback System** | Subscriber | `interaction_triggered` drives combo-specific SFX |

**Reverse dependencies:**
- Spell Upgrade System may increase `base_damage` before it enters `process_hit()` — multipliers then apply on top of upgraded base.
- Boss System: every boss fight should be designed knowing which interactions are possible, so bosses provide situations where discovery is rewarded.

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `frozen` duration | 3.0 s | 1.5–5.0 s | Below 1.5: no time to react and follow up. Above 5.0: trivializes positioning. 3.0 gives enough time for a spell to be cast. |
| `burning` duration | 4.0 s | 2.0–6.0 s | Shorter = less DOT but faster Inferno window. Longer = more DOT, less pressure to combo. |
| `marked` duration | 5.0 s | 3.0–8.0 s | Should always be long enough for player to switch and fire. 5.0 is generous. |
| Steam Burst AoE | 80 px | 40–140 px | 40: barely catches adjacent enemies. 140: catches enemies two screens apart. 80 is one enemy-width generous. |
| Steam Burst mult | 2.0× | 1.5–3.0× | Below 1.5: not worth the effort. Above 3.0: trivializes boss fights. |
| Cryoblast mult | 3.0× | 2.0–4.0× | Highest single-hit combo. Should feel exceptional — save for boss phases. |
| Amplify mult | 1.5× | 1.25–2.0× | Universal catalyst bonus. High enough to feel worth using Conjure. Low enough not to make other spells irrelevant. |
| Inferno bonus | +3 flat | +1–+8 | Small bonus — the real value is DOT refresh for sustained pressure. |
| Stun duration (Cryoblast) | 1.5 s | 0.8–3.0 s | Long enough to dodge or reposition. Above 3.0: trivializes boss. |
| Slow fraction (Extinguish) | 0.5 | 0.25–0.75 | 0.5 = half speed. 0.25 = quarter (too subtle). 0.75 = nearly stopped (too close to FROZEN). |

## Acceptance Criteria

**AC-01 — Status applied on hit.**
Enemy hit by Ice Shard projectile: `active_statuses[&"frozen"]` set with expiry `now + 3.0`. Ice crystal visual appears over enemy. Verified by: fire Ice Shard at enemy, check `active_statuses` in debugger.

**AC-02 — Status expires naturally.**
Enemy has FROZEN. 3.0 s passes with no follow-up hit. `active_statuses` no longer contains `&"frozen"`. Visual clears. Enemy resumes normal movement speed. Verified by: freeze enemy, wait, observe movement resume.

**AC-03 — Steam Burst fires on FROZEN + FIRE.**
Enemy has FROZEN. Fireball hits: `interaction_triggered` emits with name `&"steam_burst"`. Final damage = `floor(fireball_base × 2.0)`. AoE query runs — any enemy within 80 px takes `fireball_base` damage. FROZEN removed from primary target. Verified by: freeze enemy, shoot fireball, check damage value, check AoE on adjacent enemy.

**AC-04 — Cryoblast fires on FROZEN + RUPTURE.**
Enemy has FROZEN. Rupture hits: final damage = `floor(rupture_base × 3.0)`. Enemy `active_statuses[&"stunned"]` set. Enemy AI halted for 1.5 s. FROZEN removed. Verified by: freeze enemy, fire Rupture, observe stun.

**AC-05 — Extinguish fires on BURNING + ICE.**
Enemy has BURNING (tick timer running). Ice Shard hits: final damage = `floor(ice_base × 1.5)`. BURNING removed (tick timer stopped). `active_statuses[&"slowed"]` set for 2.0 s. Enemy speed at 50%. Verified by: burn enemy, fire Ice Shard, verify burn stops and slow activates.

**AC-06 — Amplify fires on MARKED + any element.**
Enemy has MARKED. ANY player spell hits: final damage = `floor(base × 1.5)`. MARKED removed. Verified: mark enemy with Conjure, fire each of 5 other spell elements in turn — all show ×1.5 damage.

**AC-07 — Undefined pair: normal damage, status preserved.**
Enemy has FROZEN. Light Bolt hits (LIGHT + FROZEN = undefined). Damage = Light Bolt base, unmodified. FROZEN remains on enemy, duration unchanged. Verified by: freeze enemy, fire Light Bolt, check status still active and damage value.

**AC-08 — Inferno fires on BURNING + FIRE.**
Enemy has BURNING. Fireball hits: damage = `fireball_base + 3`. BURNING expiry reset to `now + 4.0` (not removed). Verified by: burn enemy, immediately fire second Fireball, check burn duration extends.

**AC-09 — Devium BURN replaced.**
Devium's `_fire_marked` and `_burn_timer` code removed. Devium `take_damage()` calls `SpellInteractionEngine.process_hit()`. Two Fireball hits in sequence produce Inferno interaction (not the old bespoke logic). BURNING visual on Devium matches global status visual. Verified by: fight Devium, hit twice with Fireball, confirm Inferno fires via `interaction_triggered` signal log.

**AC-10 — No crash on undefined interaction or missing element.**
`take_damage(10, &"")` called (hazard, no element): no interaction fires, no crash. `take_damage(10, &"unknown_element")` called: no crash, normal damage. Enemy with `active_statuses = {}` hit by any element: no crash. Verified by: unit tests on all three null/edge cases.
