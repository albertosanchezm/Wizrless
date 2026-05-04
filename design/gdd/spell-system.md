# Spell System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: Spell Alchemy (primary), Earned Truth (support), Controlled Ascension (support)

## Overview

The Spell System is the Core-layer system that defines what a spell is, how the wizard casts it, and what it produces in the world. It owns the spell data model (`SpellResource`), the cast flow (input → mana check → animation → projectile spawn → cooldown), the mana resource, and the library of spells available in the game. It does not own spell slot management (which spells are currently equipped — that is the Spell Slot System) or interaction resolution (what happens when two spells interact — that is the Spell Interaction Engine). It provides the event interface both downstream systems hook into.

At MVP, the wizard has access to six spells: **Fireball**, **Ice Shard**, **Light Bolt**, **Shadow Tendril**, **Conjure**, and **Rupture**. Each spell has a defined element, projectile behavior, mana cost, and cast animation frame. Spells are defined as `SpellResource` data files — not hardcoded in the player script. The active spell is set by the Spell Slot System; the Spell System executes whichever spell is active without knowledge of the slot count or equip logic.

Casting always costs mana. Mana is a shared resource across all spells: spend it, wait for regeneration, or reach a decision point where the next cast is impossible. At MVP there are no per-spell cooldowns — the single cast cooldown (`ATTACK_COOLDOWN`) and the mana pool together gate cast frequency. The player's resource is time and positioning, not a per-spell cooldown timer.

The Spell System does not own enemy damage, hit reactions, or interaction effects. It fires a projectile into the world; what the projectile does on contact is defined in the projectile scene. What happens when two spells interact is the Interaction Engine's domain.

## Player Fantasy

Spells are not tools. They are a language the wizard did not know he was fluent in until the order stopped protecting him from himself.

The first spell came easily — the order taught it. It was called a utility exercise. It was called safe. He knows now it was neither. Each new spell he finds in a locked room, torn from the hands of someone sent to end him, arrives not as acquisition but as recognition. He has always been able to do this. He simply needed someone to try hard enough to kill him.

Casting should feel **decisive**. Not rapid-fire. Not frantic. The wizard raises his hand, and something happens that should not happen — and mana drains, because this costs something real. The cost should register. An empty mana pool is not a timeout. It is the moment the wizard must rely on distance, positioning, movement — the body, not the power. That alternation between spell and footwork is the texture of every fight.

When the player equips a new spell for the first time, they should pause before firing it. Not because the UI prompts them to — because the visual, the sound, and the way it leaves the wizard's hand together create a moment of "what does this *do*?" The answer is not in a tooltip. The answer is in the enemy.

## Detailed Design

### SpellResource Data Model

Each spell is a Godot `Resource` subclass (`SpellResource`). The player script holds a reference to the active spell; the Spell Slot System swaps it. No spell logic lives in the player script — the player script reads from the resource.

```
SpellResource
  id:               StringName    # unique identifier e.g. &"fireball"
  display_name:     String        # "Fireball"
  element:          SpellElement  # enum: FIRE, ICE, LIGHT, SHADOW, CONJURE, RUPTURE
  projectile_scene: PackedScene   # scene to instantiate on cast
  mana_cost:        float         # cost per cast (default 25.0)
  cast_frame:       int           # animation frame at which projectile spawns
  cast_animation:   StringName    # animation name to play on cast (default &"attack")
  spawn_offset:     Vector2       # offset from player position at spawn
  icon:             Texture2D     # HUD icon
  lore_key:         StringName    # key into lore database (Earned Truth hook)
```

`SpellElement` enum lives in a shared autoload or `SpellResource` inner class so both the Spell System and Interaction Engine can reference it without circular dependency.

---

### Cast Flow

Each physics frame the player checks `wants_attack()` in the active movement state. When true:

1. **Mana check** — `current_mana >= active_spell.mana_cost`. Fails silently if false.
2. **Cooldown check** — `attack_cooldown <= 0.0`. Fails silently if false.
3. **State transition** — Movement HSM dispatches `&"attack"` → AttackState enters.
4. **AttackState `_enter()`** — plays `active_spell.cast_animation`, sets `attack_cooldown = ATTACK_COOLDOWN`, calls `player.use_mana(active_spell.mana_cost)`.
5. **Animation reaches `active_spell.cast_frame`** — `_fire()` called. Instantiates `active_spell.projectile_scene`, sets position + direction, adds to parent scene.
6. **Spell cast signal emitted** — `GameManager.spell_cast.emit(active_spell, direction)`. Interaction Engine listens here.
7. **Animation ends** — AttackState dispatches back to Idle / Run / Fall.

---

### Mana Resource

Mana is owned by the player script. It is spell-element-agnostic — all spells draw from the same pool.

- Pool: `MAX_MANA = 100.0`
- Cost per cast: read from `active_spell.mana_cost` (default `25.0` → max 4 casts from full)
- Regen: begins after `MANA_REGEN_DELAY = 1.5s` of no casting
- Regen rate: `MANA_REGEN_RATE = 10.0` points/s
- Refill time from empty: `100 / 10 = 10s` (no casting during regen)
- Signal: `GameManager.mana_changed(current, maximum)` — emitted on spend and each regen tick

---

### MVP Spell Library

Six spells at MVP. Three defined interactions (see Spell Interaction Engine GDD).

| ID | Name | Element | Base Damage | Mana Cost | Behavior |
|----|------|---------|-------------|-----------|----------|
| `fireball` | Fireball | FIRE | 20 | 25 | Straight horizontal projectile. Destroys on contact. |
| `ice_shard` | Ice Shard | ICE | 15 | 25 | Straight horizontal, slower than fireball. Applies brief slow on hit. |
| `light_bolt` | Light Bolt | LIGHT | 18 | 25 | Straight horizontal, faster than fireball. Passes through terrain. |
| `shadow_tendril` | Shadow Tendril | SHADOW | 12 | 25 | Short-range arc, curves downward. Higher damage at close range. |
| `conjure` | Conjure | CONJURE | 0 | 25 | Spawns stationary arcane orb at cast point. Persists 3s. No direct damage — interaction trigger only. |
| `rupture` | Rupture | RUPTURE | 25 | 35 | Slow, high-damage projectile. Short lifetime. Cannot be aimed diagonally. |

*Base damage values are design targets — final values set via tuning and balance passes.*

---

### Cast Direction

Direction computed at fire moment in `_fire()`:

- **Horizontal**: facing direction `(flip_h ? -1 : 1, 0)`
- **Diagonal up**: if `move_up` held at fire moment `(flip_h ? -1 : 1, -1)`, normalized
- **No diagonal down** — wizard does not cast downward. Prevents trivial floor-target abuse; consistent with platformer convention.

Direction passed to projectile scene as `Vector2`. Projectile scenes own their own movement logic.

---

### Interactions with Other Systems

| System | Direction | Exchange |
|--------|-----------|---------|
| Spell Slot System | → Spell | Sets `player.active_spell: SpellResource` |
| Movement System | Bidirectional | AttackState part of Movement HSM; cast input checked in movement states |
| Spell Interaction Engine | Spell → | `GameManager.spell_cast(spell, direction)` — Engine tracks cast history |
| Audio System | Spell → | Each projectile scene owns its own `AudioStreamPlayer`; no central audio dispatch |
| HUD System | Spell → | `GameManager.mana_changed`, `GameManager.attack_cooldown_changed` |
| Progression System | → Spell | New spells added to known library on unlock via `GameManager.spell_unlocked` |

## Formulas

### Mana Economy

```
max_casts_per_pool(spell) = floor(MAX_MANA / spell.mana_cost)

-- Default spell (mana_cost = 25):
max_casts = floor(100 / 25) = 4

-- Rupture (mana_cost = 35):
max_casts = floor(100 / 35) = 2

refill_time_from_empty = MAX_MANA / MANA_REGEN_RATE
                       = 100 / 10
                       = 10.0s

time_to_next_cast(current_mana, spell) =
  if current_mana >= spell.mana_cost: 0s (cast available now)
  else: MANA_REGEN_DELAY + (spell.mana_cost - current_mana) / MANA_REGEN_RATE
```

### Cast Cadence

```
-- Minimum time between casts (cooldown is binding at full mana):
min_cast_interval = ATTACK_COOLDOWN = 1.5s

-- Casts before mana empties (default spell):
casts_before_empty = floor(MAX_MANA / mana_cost) = 4

-- Time for mana pool to recover after emptying:
recovery_time = MANA_REGEN_DELAY + MAX_MANA / MANA_REGEN_RATE
              = 1.5 + 10.0
              = 11.5s

-- Burst rhythm (default spell): 4 casts over 6s → 11.5s recovery → repeat
-- Effective sustained rate: 4 / 17.5s ≈ 13.7 casts/min
```

### Projectile Speed Reference

| Spell | Speed (px/s) | Notes |
|-------|-------------|-------|
| Fireball | 220 | Current implementation |
| Ice Shard | 160 | ~27% slower than Fireball |
| Light Bolt | 300 | ~36% faster than Fireball |
| Shadow Tendril | 100 | Short range; curves downward |
| Conjure | 0 | Stationary at spawn point |
| Rupture | 120 | Slow; high damage payoff |

*Speeds are design targets — tuned per projectile scene.*

### Projectile Lifetime → Effective Range

```
effective_range(spell) = spell.speed × projectile_lifetime

-- Fireball (speed=220, lifetime=2.5s):  range = 550 px
-- Rupture  (speed=120, lifetime=1.5s):  range = 180 px
```

### Variable Definitions

| Variable | Value | Unit | Description |
|----------|-------|------|-------------|
| `MAX_MANA` | 100.0 | points | Total mana pool |
| `MANA_COST` | 25.0 | points | Default cast cost (overridden per `SpellResource`) |
| `MANA_REGEN_RATE` | 10.0 | points/s | Regen speed after delay expires |
| `MANA_REGEN_DELAY` | 1.5 | s | Idle time before regen begins |
| `ATTACK_COOLDOWN` | 1.5 | s | Minimum time between casts |

## Edge Cases

**EC-01 — Cast input with zero mana.**
`wants_attack()` checks `current_mana >= active_spell.mana_cost` before dispatching. No state transition occurs. No animation plays. No audio. Input is silently consumed. Mana bar on HUD communicates the block — no separate "can't cast" feedback needed at MVP.

**EC-02 — Mana regen delay reset mid-regen.**
Player casts while mana is regenerating. `use_mana()` resets `_mana_regen_timer` to `MANA_REGEN_DELAY`. Regen restarts from zero delay after the new cast. Partial regen already accumulated is kept — only the timer resets, not `current_mana`.

**EC-03 — Active spell swapped mid-cast.**
AttackState committed to the previous spell's animation and projectile at `_enter()`. Slot System swap takes effect on the next cast. If swap happens before `cast_frame` is reached, the new spell fires. This is acceptable — slot swap timing is the player's responsibility.

**EC-04 — Conjure cast when an orb already exists.**
A second orb spawns. Two orbs can exist simultaneously. Maximum orb count is not enforced by the Spell System — it is an Interaction Engine concern if stacking creates exploitable interactions. Design target: two simultaneous orbs acceptable at MVP.

**EC-05 — Rupture cast while airborne with move_up held.**
Rupture cannot be aimed diagonally by design. Cast direction is forced horizontal inside `_fire()` when `active_spell.element == RUPTURE`, regardless of `move_up` input.

**EC-06 — Cast during death transition.**
`die` is an ANYSTATE HSM transition. AttackState exits immediately. Any projectile already instantiated is not recalled — it continues and can still hit enemies. Mana was already spent. Correct behavior: the spell was cast; death happened after.

**EC-07 — New spell unlocked with no slot available.**
Spell added to known library. If no slot is free, it is available in inventory but not equipped. Spell Slot System handles equip logic. Spell System and Movement System are unaffected — they only act on `active_spell`, which is unchanged.

**EC-08 — `active_spell` is null.**
`wants_attack()` guards against null `active_spell` — check fails immediately, no cast, no crash. Null is a transient initialization state only. Spell Slot System guarantees `active_spell` is set before the first physics frame.

**EC-09 — Projectile travels off-screen without hitting anything.**
Each projectile scene owns a `LifeTimer`. On timeout, `queue_free()`. Spell System has no awareness of this — responsibility ended at fire. No mana refund. No signal emitted.

**EC-10 — Two casts on consecutive frames.**
`ATTACK_COOLDOWN = 1.5s` set at AttackState `_enter()`. Second cast cannot fire until cooldown reaches zero. No cast buffer exists (unlike jump buffer) — attack input is checked live each frame, not pre-buffered. No double-cast exploit.

## Dependencies

### Systems this requires

| System | What Spell System needs |
|--------|------------------------|
| **Input System** | `attack` action in InputMap; `move_up` action for diagonal aim |
| **Audio System** | Audio bus active — each projectile scene routes SFX through it |
| **Movement System** | AttackState inside Movement HSM; `player.active_spell`, `player.use_mana()`, `player.attack_cooldown` owned by player script |
| **GameManager autoload** | `mana_changed`, `attack_cooldown_changed`, `spell_cast` signals; `spell_unlocked` for library updates |

### Systems that require this

| System | What it needs from Spell System |
|--------|--------------------------------|
| **Spell Slot System** | `SpellResource` data model; `player.active_spell` reference to write |
| **Spell Interaction Engine** | `GameManager.spell_cast(spell, direction)` signal; `SpellElement` enum; cast history for pair detection |
| **HUD System** | `GameManager.mana_changed`, `GameManager.attack_cooldown_changed` |
| **Progression System** | `SpellResource` files to grant on unlock; `GameManager.spell_unlocked` to trigger library update |
| **Boss System** | `SpellElement` enum — boss resistances and vulnerabilities reference it |
| **Audio Feedback System** | Spell identity and projectile SFX conventions per spell |
| **Spell VFX System** | Spell identity and projectile visual conventions per spell |

### Hard blockers (must exist before Spell System is testable)

- Input System: `attack` and `move_up` actions in InputMap
- `GameManager`: `spell_cast` signal added (`mana_changed` and `attack_cooldown_changed` already present)
- `SpellResource` class defined and at least one `.tres` file created
- Movement System: AttackState updated to read from `active_spell` instead of hardcoded fireball

## Tuning Knobs

### Mana Economy Knobs

| Knob | Current | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `MAX_MANA` | 100.0 | 60–150 | Total burst capacity. Lower = more frequent empty states, more punishing. Higher = less resource pressure. |
| `MANA_COST` (default) | 25.0 | 15–40 | Casts per pool. At 25: 4 casts. At 15: 6 casts. At 40: 2 casts. Drives aggression rhythm. |
| `MANA_REGEN_RATE` | 10.0 pts/s | 6–20 | Recovery speed. Below 6: empty pool is 16s+ punishment. Above 20: mana pressure disappears. |
| `MANA_REGEN_DELAY` | 1.5 s | 0.5–3.0 | Gap before regen starts. Rewards burst-then-retreat. Above 3.0: feels punishing on last cast. |

### Cast Cadence Knobs

| Knob | Current | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `ATTACK_COOLDOWN` | 1.5 s | 0.8–2.5 | Cast rate ceiling. Below 0.8: mana becomes the only gate — repositioning rhythm breaks down. Above 2.5: combat feels sluggish. |

### Per-Spell Knobs (in `SpellResource` `.tres` files)

| Knob | Applies To | Notes |
|------|-----------|-------|
| `mana_cost` | Per spell | Override default 25.0. Rupture uses 35. High-cost spells force real decisions. |
| Projectile `SPEED` | Per projectile scene | Drives range and reaction window. See Formulas for speed→range relationship. |
| Projectile `LifeTimer` duration | Per projectile scene | Direct range control. Tune paired with speed. |
| Base damage | Per projectile scene | Design target values in MVP spell table. Final via balance pass. |
| Conjure orb lifetime | Conjure projectile scene | 3.0s design target. Shorter = less interaction window. Longer = trivially easy setups. |

### Interaction Between Knobs

- Increasing `ATTACK_COOLDOWN` while decreasing `MANA_COST`: slower cast rate, deeper pool — favors patient players.
- Increasing `MANA_REGEN_RATE` while increasing `ATTACK_COOLDOWN`: quick recovery but slow cast — reduces mana as meaningful resource.
- Keep `MANA_REGEN_DELAY >= ATTACK_COOLDOWN × 0.8` to prevent regen starting before the player could cast again.

## Visual/Audio Requirements

### Cast Animation

Single `attack` animation on `AnimatedSprite2D`. All six MVP spells share this animation at MVP — per-spell cast animations are a polish-layer addition. `cast_frame` in `SpellResource` controls when the projectile fires; tuneable without new animations.

Post-MVP: unique cast animations per element (heavier wind-up for Rupture, snap gesture for Light Bolt, etc.).

### Projectile Visuals

Each spell requires a distinct, immediately readable visual identity. The wizard's spells are the only color in most scenes — visual differentiation is functional, not decorative.

| Spell | Visual Direction | Color Anchor |
|-------|-----------------|--------------|
| Fireball | Pulsing sphere + fire trail (CPUParticles2D) | Warm orange/red |
| Ice Shard | Elongated crystalline shard + ice fragment trail | Cold blue/white |
| Light Bolt | Thin bright beam with short leading glow | Bright white/gold |
| Shadow Tendril | Wispy dark arc with trailing smoke | Deep purple/black |
| Conjure | Pulsing stationary orb with slow rotation aura | Teal/emerald |
| Rupture | Dense dark mass, no trail, visible weight | Dark crimson |

**Rule**: any two spells placed side by side must be distinguishable at a glance. If color alone is insufficient for colorblind players, shape must carry the difference.

### Sound Effects

Each projectile scene owns its own `AudioStreamPlayer`. No central spell audio dispatch.

| Spell | SFX Character | Status |
|-------|--------------|--------|
| Fireball | Whoosh + low crackle on launch | Implemented |
| Ice Shard | Sharp crystalline crack on launch | Not implemented |
| Light Bolt | High-pitched zip on launch | Not implemented |
| Shadow Tendril | Low wet slither on launch | Not implemented |
| Conjure | Resonant hum on spawn; soft pulse during lifetime | Not implemented |
| Rupture | Deep thud / tectonic groan on launch | Not implemented |

Impact SFX (on hit/expire) are owned by projectile scenes, not the Spell System. Each scene needs both launch and impact SFX.

### Mana Feedback

- Mana bar color shift when below 25 (one cast remaining) — visual urgency signal
- Silent failure (no cast) when mana empty is sufficient at MVP
- Polish addition: brief "empty" audio cue on blocked cast input

## UI Requirements

### Mana Bar

Displays `current_mana / MAX_MANA`. Reads `GameManager.mana_changed(current, maximum)`.

- Visible at all times during gameplay
- Drains on cast, refills on regen
- Color shift below 25 points (one default cast remaining) — design target: amber or red tint
- Owned by HUD System GDD — Spell System specifies signal interface only

### Active Spell Display

Shows currently equipped spell icon (`active_spell.icon`) and name.

- Single slot at MVP
- Updates when Spell Slot System changes `active_spell`
- Signal: `GameManager.active_spell_changed(spell: SpellResource)` — emitted by Spell Slot System on swap
- Owned by HUD System GDD

### Cast Cooldown Indicator

Shows remaining cooldown on active spell slot icon. Reads `GameManager.attack_cooldown_changed(remaining, total)`.

- Overlay or radial fill on spell icon
- Signal already present in GameManager
- Owned by HUD System GDD

### Spell Unlock Notification

When `GameManager.spell_unlocked` fires, brief on-screen notification: spell name, element, icon. ~3s duration, non-blocking. Owned by HUD/Progression — Spell System only emits the signal.

### Nothing else required

Spell System does not own damage numbers, enemy health bars, or boss bars.

## Acceptance Criteria

**AC-01 — Fireball fires on attack input.**
Stand still, full mana. Press attack. Fireball spawns at wizard's chest height, travels horizontally in facing direction. Pass: projectile visible, moves, despawns on wall contact or lifetime expiry.

**AC-02 — Cast costs mana.**
Start full mana (100). Cast once — bar shows 75. Cast four times total — bar shows 0. Pass: each cast deducts 25; bar reflects change immediately.

**AC-03 — Cast blocked at zero mana.**
Empty pool (4 casts). Press attack immediately. Nothing happens — no animation, no projectile, no sound. Pass: fifth cast attempt produces no response.

**AC-04 — Mana regenerates after delay.**
Empty pool. Wait 1.4s — no regen. Wait to 1.5s — bar begins filling. Full pool after ~10s no casting. Pass: delay then regen, correct timing.

**AC-05 — Cast during regen resets delay.**
Empty pool. Wait 5s (partial regen). Cast once. Regen does not resume for another 1.5s. Pass: delay resets on cast; no instant regen after spending.

**AC-06 — Diagonal cast upward.**
Hold `move_up`, press attack — projectile travels up-forward ~45°. Release `move_up`, press attack — projectile travels horizontally. Pass: direction follows input at fire moment.

**AC-07 — All six MVP spells fire correctly.**
Equip each spell via Spell Slot System. Fire each. Pass: distinct projectile visual and sound per spell; all travel correct direction; all despawn correctly.

**AC-08 — Rupture cannot be aimed diagonally.**
Equip Rupture. Hold `move_up`. Press attack. Projectile travels horizontally. Pass: forced horizontal regardless of aim input.

**AC-09 — Conjure orb persists then expires.**
Equip Conjure. Cast. Stationary orb appears at cast point. After 3s orb disappears. Pass: orb visible ~3s, no movement, then gone.

**AC-10 — Spell swap takes effect on next cast.**
Mid-combat, switch active spell. Cast. New spell fires. Previous in-flight projectile unaffected. Pass: swap immediate for next cast only.

**AC-11 — Attack cooldown enforced.**
Cast. Immediately press attack. Nothing. Wait 1.5s. Press attack. Fires. Pass: one cast per cooldown window.

**AC-12 — Cast while airborne.**
Jump. Press attack mid-air. Spell fires, animation plays, projectile spawns. Pass: casting available in Jump and Fall states.

**AC-13 — New spell unlock available without restart.**
Trigger `GameManager.spell_unlocked("light_bolt")` via debug console. Open inventory. Light Bolt present. Equip and cast. Pass: no scene reload required; immediately usable.

**AC-14 — Mana bar color changes at low mana.**
Drain to 26 points — bar normal color. Cast once (25 cost) → 1 point — bar shifts amber/red. Regen to 26 — bar returns to normal. Pass: threshold color change correct.

**AC-15 — Death during cast does not freeze state.**
Trigger player death while cast animation plays. Death animation plays immediately. No stuck AttackState. In-flight projectile continues. Pass: clean state exit, no freeze.
