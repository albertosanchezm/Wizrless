# Health System

> **Status**: In Review
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-04-23
> **Implements Pillar**: Controlled Ascension, Earned Truth

## Overview

The Health System is the Core-layer infrastructure that owns the wizard's life resource: `current_health` (the amount of health remaining), `max_health` (the ceiling, upgradeable through progression), and the transitions between alive and dead. It is the single source of truth for whether the wizard can continue. No other system may read or write health state except through this system's interface.

The system is player-only — enemies have their own damage model managed by the Enemy Base System. Health is a continuous integer: `current_health` decreases by the damage value of each incoming hit and cannot go below 0. `max_health` starts at a tuned default and increases when the player finds health upgrades in the world. Both values are persisted via the Save/Load System under key `"health"` between sessions.

The Health System emits the signals that other systems subscribe to: `player_damaged` (consumed by the Camera System for shake, the Audio Feedback System for SFX, and the HUD for visual feedback), `health_changed` (consumed by the HUD for bar updates), and `player_died` (consumed by the Checkpoint/Respawn System to trigger respawn, and by the Camera System for T-11 cleanup). It receives damage calls from external sources — the Hazard System, Enemy Base System, and Boss System — through a single public method. It does not initiate damage on its own. Invincibility frames are owned by this system: after taking damage, the wizard is briefly immune to further hits, preventing multi-hit death bursts.

What this system makes possible: the wizard is genuinely fragile. Life is scarce enough to make every hit matter and every health upgrade feel earned — Controlled Ascension applied to survival.

## Player Fantasy

The Health System has no player fantasy of its own. The wizard never thinks about it — and that is the design goal. What the player experiences is not a health bar: it is the weight of each blow and the question of how many more the wizard can take.

What this system makes possible: a boss fight where the wizard enters damaged feels qualitatively different from the same fight at full health. A single hit from an unfamiliar enemy telegraphs its threat level more honestly than any tooltip could. The moment before the last hit of a boss fight — `current_health` down to a sliver, one mistake from losing the encounter — is one of the few moments in any game where a player truly holds their breath. The Health System does not create that moment. It simply keeps score honestly enough that the moment is real.

The player fantasy lives in the Boss System, the Combat loop, and Controlled Ascension. This system is the ledger.

## Detailed Design

### Core Rules

The system exposes a single public entry point: `take_damage(amount: int)`. All external systems call this method and nothing else — no system reads or writes `current_health` or `max_health` directly.

**Damage Intake Flow** — executed in this exact order, no exceptions:

1. If `iframe_timer > 0`, discard the hit and return. No signal is emitted.
2. Clamp `amount` to `max(0, amount)`. Negative damage is silently ignored.
3. Reduce current health: `current_health = max(0, current_health - amount)`.
4. Emit `health_changed(current_health, max_health)`.
5. Emit `player_damaged(amount)`.
6. Set `iframe_timer = IFRAME_DURATION`.
7. If `current_health == 0`, emit `player_died` and return. No further processing.

**Invincibility Frames**: `iframe_timer` is a `float` decremented each `_physics_process(delta)` call. When it reaches `0.0` the wizard is vulnerable again. The countdown is not paused by any game state other than scene reload (reload resets it to `0.0`).

**Respawn**: Called by the Checkpoint/Respawn System after it handles `player_died`. Sets `current_health = max_health`, resets `iframe_timer = 0.0`, emits `health_changed(current_health, max_health)`. Does not emit `player_damaged` or `player_died`.

**Max Health Upgrade**: When the player collects a health upgrade, the Progression System calls `add_max_health(UPGRADE_INCREMENT)`. This: increments `max_health` by `UPGRADE_INCREMENT`, increments `current_health` by the same amount (the upgrade also heals the gap), clamps `current_health` to `max_health`, emits `health_changed(current_health, max_health)`.

**Damage Values** (authoritative source: the system dealing damage, not this system):

| Source | Amount |
|---|---|
| Enemy hit | 1 |
| Hazard contact | 1 |
| Boss hit | 2 |
| Boss special attack | 3 |

**No regeneration**: `current_health` never increases except through `respawn()` or `add_max_health()`. No passive regen, no healing pickups beyond upgrades.

### States and Transitions

| State | Active When | Entry Action | Exit Condition | Exit To |
|---|---|---|---|---|
| ALIVE | `current_health > 0` and `iframe_timer <= 0` | — | `take_damage()` called with unblocked hit | INVINCIBLE (if health > 0) or DEAD |
| INVINCIBLE | `current_health > 0` and `iframe_timer > 0` | `iframe_timer = IFRAME_DURATION` | `iframe_timer` reaches `0.0` | ALIVE |
| DEAD | `current_health == 0` | Emit `player_died` | `respawn()` called | ALIVE |

INVINCIBLE is a substate of ALIVE — health is positive, the wizard simply cannot be hit. DEAD is terminal until Checkpoint/Respawn calls `respawn()`.

### Interactions with Other Systems

**Upstream — systems that call into the Health System:**

| Caller | Method | Payload |
|---|---|---|
| Enemy Base System | `take_damage(1)` | amount: int |
| Hazard System | `take_damage(1)` | amount: int |
| Boss System | `take_damage(2)` or `take_damage(3)` | amount: int |
| Checkpoint/Respawn System | `respawn()` | — |
| Progression System | `add_max_health(UPGRADE_INCREMENT)` | increment: int |

**Downstream — systems that subscribe to Health System signals:**

| Signal | Subscriber | What the subscriber does |
|---|---|---|
| `health_changed(current, max)` | HUD System | Updates health bar display |
| `player_damaged(amount)` | Camera System | Triggers Damage Shake |
| `player_damaged(amount)` | Audio Feedback System | Plays hurt SFX |
| `player_died` | Checkpoint/Respawn System | Begins respawn sequence |
| `player_died` | Camera System | Begins T-11 hold sequence |

**Save/Load System:**
- Registration call: `register_save_provider("health", _save_health, _load_health)`
- Save payload: `{ "current_health": int, "max_health": int }`
- Load guard: clamp loaded `current_health` to `[1, max_health]` to survive corrupted saves. If loaded `max_health` falls outside `[BASE_HEALTH, BASE_HEALTH + N_UPGRADES × UPGRADE_INCREMENT]`, reset to `BASE_HEALTH`.

## Formulas

### F-1. Max Health Ceiling

```
max_health(n) = BASE_HEALTH + n × UPGRADE_INCREMENT
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `n` | int | [0, N_UPGRADES] | Number of health upgrades collected |
| `BASE_HEALTH` | int | — | Starting max health (tuning knob) |
| `UPGRADE_INCREMENT` | int | — | HP gained per upgrade (tuning knob) |
| `N_UPGRADES` | int | — | Total upgrades available in the world (tuning knob) |
| `max_health(n)` | int | [6, 14] | Health ceiling at upgrade count n |

**Example calculations:**

| n | max_health |
|---|---|
| 0 | 6 |
| 1 | 8 |
| 2 | 10 |
| 3 | 12 |
| 4 | 14 |

With default tuning values (`BASE_HEALTH = 6`, `UPGRADE_INCREMENT = 2`, `N_UPGRADES = 4`), the wizard starts with 6 HP and caps at 14 HP after all upgrades.

### F-2. Iframe Countdown

```
iframe_timer -= delta          (each _physics_process frame)
iframe_timer = max(0.0, iframe_timer)
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `iframe_timer` | float | [0.0, IFRAME_DURATION] | Seconds of invincibility remaining |
| `delta` | float | > 0 | Frame time from `_physics_process` |
| `IFRAME_DURATION` | float | [0.4, 1.5] | Duration of one iframe window (tuning knob) |

At 60 fps with default `IFRAME_DURATION = 0.8`, the wizard is invincible for approximately **48 frames** after each hit.

**Boundary check**: At minimum `IFRAME_DURATION = 0.4` and max delta of `~0.05` (20 fps floor), invincibility lasts at least 8 frames — enough to prevent two-hit death from a single enemy in any realistic frame rate.

## Edge Cases

**EC-01 — Damage amount of 0**
`take_damage(0)` passes the iframe check, reduces health by 0 (no change), emits `health_changed` and `player_damaged(0)`, and starts iframes. The wizard becomes INVINCIBLE for a full window after a zero-damage hit. This is intentional: zero-damage calls should not exist in practice (callers are responsible for not calling with 0), but if they do, iframes fire as a safe fallback.

**EC-02 — Multiple hits in the same frame**
A frame can deliver two simultaneous `take_damage()` calls (e.g., stepping on a hazard and being hit by an enemy in the same physics step). Only the first resolves — the second is discarded by the iframe check (which is set after the first). The wizard takes damage once and enters INVINCIBLE. No health double-dip.

**EC-03 — Damage exceeds remaining health**
`take_damage(5)` when `current_health = 2` results in `current_health = max(0, 2 - 5) = 0`. The wizard dies with one hit. No partial damage carry-over, no overkill state — clamping to 0 is the floor.

**EC-04 — Respawn called while ALIVE**
`respawn()` called on a living wizard (e.g., Checkpoint/Respawn bug) restores health to `max_health` and resets `iframe_timer`. It emits `health_changed`. It is safe to call in any state — it is a restore operation, not a state transition gate.

**EC-05 — `add_max_health` at upgrade cap**
If `n == N_UPGRADES` and the caller attempts another `add_max_health()` call (bug or duplicate pickup trigger), `max_health` would exceed the intended ceiling. The method must guard: if `max_health >= BASE_HEALTH + N_UPGRADES × UPGRADE_INCREMENT`, return without change and log a warning. No signal emitted.

**EC-06 — Corrupted save: `current_health > max_health`**
On load, if `current_health > max_health`, clamp `current_health` to `max_health`. Emit `health_changed` after clamping. Do not treat this as a death condition.

**EC-07 — Corrupted save: `current_health <= 0`**
On load, if `current_health <= 0`, set `current_health = 1`. The wizard loads alive at minimum health. Do not trigger `player_died` on load.

**EC-08 — Corrupted save: `max_health` out of valid range**
If loaded `max_health` is outside `[BASE_HEALTH, BASE_HEALTH + N_UPGRADES × UPGRADE_INCREMENT]`, reset `max_health = BASE_HEALTH` and `current_health = BASE_HEALTH`. Log a warning. The wizard loses upgrade progress but the game is playable.

**EC-09 — Death during iframe window**
Not possible by normal flow: iframes are set after step 6 (clamp health), and `player_died` fires at step 7 only when `current_health == 0`. By the time iframes are set, death has already been resolved. However, if a future change moves the iframe set before the death check, the spec is clear: death check always runs regardless of iframe state.

**EC-10 — Scene reload during any state**
Scene reload resets `iframe_timer = 0.0`. The health values are not reset by reload alone — they are restored by the Save/Load System loading the last saved state. If no save exists (first launch), the system initialises to `current_health = BASE_HEALTH`, `max_health = BASE_HEALTH`.

## Dependencies

### Upstream (this system depends on these)

| System | What this system needs | GDD |
|---|---|---|
| Save/Load System | `register_save_provider()` interface to persist `current_health` and `max_health` between sessions | `save-load-system.md` ✓ |

### Downstream (these systems depend on this system)

| System | What they need from this system | GDD |
|---|---|---|
| Enemy Base System | `take_damage(amount)` public method | not yet designed |
| Hazard System | `take_damage(amount)` public method | not yet designed |
| Boss System | `take_damage(amount)` public method | not yet designed |
| Checkpoint/Respawn System | `player_died` signal; `respawn()` public method | not yet designed |
| Progression System | `add_max_health(increment)` public method | not yet designed |
| HUD System | `health_changed(current, max)` signal | not yet designed |
| Audio Feedback System | `player_damaged(amount)` signal | not yet designed |
| Camera System | `player_damaged(amount)` signal (Damage Shake); `player_died` signal (T-11 hold) | `camera-system.md` ✓ |

### Bidirectionality Note

The Camera System GDD (`camera-system.md`) references `player_damaged` and `player_died` as trigger signals for Damage Shake and the T-11 hold sequence respectively. The Save/Load System GDD (`save-load-system.md`) references the Health System as a registered save provider under key `"health"`. All other downstream GDDs are not yet authored — they must reference this system's signal and method interfaces when written.

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Effect |
|---|---|---|---|
| `BASE_HEALTH` | 6 | [4, 10] | Starting health pool. Lower values make the early game more punishing; higher values reduce the weight of individual hits. Do not exceed 10 — at higher values a single hit (1 damage) feels inconsequential. |
| `UPGRADE_INCREMENT` | 2 | [1, 4] | HP gained per health upgrade. At 1, upgrades feel minor; at 4, a single upgrade substantially shifts the experience. Keep equal to enemy damage values or slightly above to preserve hit weight. |
| `N_UPGRADES` | 4 | [2, 6] | Total health upgrades available in the world. Controls the max health ceiling and the rate of Controlled Ascension. Fewer upgrades = scarcer, more meaningful moments; more = smoother ramp. |
| `IFRAME_DURATION` | 0.8s | [0.4, 1.5] | Duration of invincibility after a hit. Below 0.4s, fast enemies can deliver a two-hit burst before iframes expire. Above 1.5s, the wizard feels untouchable — multi-enemy encounters lose tension. The 0.8s default is tuned to feel protective without removing risk. |

**Dependent constraint**: `UPGRADE_INCREMENT` should satisfy `UPGRADE_INCREMENT ≥ max enemy damage per hit (currently 3 for boss special)` only if upgrades are intended to absorb a full boss hit. With current values (INCREMENT = 2, boss special = 3), a single upgrade does not absorb one boss special hit — this is intentional and preserves threat escalation.

## Visual/Audio Requirements

Owned by downstream systems. The Health System emits signals; visual and audio responses are the responsibility of the subscribing systems:
- **Hurt SFX**: Audio Feedback System subscribes to `player_damaged(amount)`.
- **Death SFX / animation**: Checkpoint/Respawn System handles `player_died`.
- **Camera shake on hit**: Camera System subscribes to `player_damaged(amount)`.

No visual or audio assets are owned or triggered directly by this system.

## UI Requirements

Owned by the HUD System. This system emits `health_changed(current, max)` — the HUD is responsible for rendering the bar. No UI assets or layout concerns belong to this system.

## Acceptance Criteria

**AC-01 — Normal damage reduces health**
Given the wizard has `current_health = 6` and `iframe_timer = 0`, when `take_damage(1)` is called, then `current_health == 5`, `health_changed(5, 6)` was emitted, `player_damaged(1)` was emitted, and `iframe_timer > 0`.

**AC-02 — iframes block follow-up hit**
Given `iframe_timer > 0`, when `take_damage(1)` is called, then `current_health` is unchanged and no signal is emitted.

**AC-03 — Death triggers correctly**
Given `current_health = 1` and `iframe_timer = 0`, when `take_damage(1)` is called, then `current_health == 0`, `health_changed(0, max_health)` was emitted, `player_damaged(1)` was emitted, and `player_died` was emitted.

**AC-04 — Overkill clamps to 0, not negative**
Given `current_health = 2` and `iframe_timer = 0`, when `take_damage(5)` is called, then `current_health == 0` (not −3) and `player_died` was emitted.

**AC-05 — Respawn restores full health**
Given `current_health = 2` and `max_health = 6`, when `respawn()` is called, then `current_health == 6`, `iframe_timer == 0.0`, and `health_changed(6, 6)` was emitted. `player_died` is NOT emitted.

**AC-06 — Upgrade increases both values**
Given `current_health = 4`, `max_health = 6`, `UPGRADE_INCREMENT = 2`, when `add_max_health(2)` is called, then `max_health == 8`, `current_health == 6`, and `health_changed(6, 8)` was emitted.

**AC-07 — Upgrade cap guard**
Given `max_health == BASE_HEALTH + N_UPGRADES × UPGRADE_INCREMENT` (14 with defaults), when `add_max_health(2)` is called again, then `max_health` remains 14, `current_health` is unchanged, and no signal is emitted.

**AC-08 — iframe timer counts down**
Given `iframe_timer = 0.8`, after 0.8 real seconds of `_physics_process` calls, then `iframe_timer <= 0.0`. A `take_damage(1)` call at this point reduces health (wizard is vulnerable).

**AC-09 — Health persists across sessions**
Given `current_health = 3`, `max_health = 8`, when the game saves and reloads, then `current_health == 3` and `max_health == 8` after load. `player_died` is NOT emitted on load.

**AC-10 — Corrupted save clamps to valid range**
Given a save file with `current_health = 0` and `max_health = 6`, when the game loads, then `current_health == 1` (clamped from 0) and `player_died` is NOT emitted.

**AC-11 — Corrupted save with out-of-range `max_health` resets to BASE_HEALTH**
Given a save file with `max_health = 999`, when the game loads, then `max_health == BASE_HEALTH` (6 with defaults) and `current_health == BASE_HEALTH`.

**AC-12 — No signals fire at startup before first damage**
When the scene loads for the first time (no save), `health_changed`, `player_damaged`, and `player_died` are NOT emitted during `_ready`. State is initialised silently.

**AC-13 — Zero-damage hit still triggers iframes**
Given `iframe_timer = 0`, when `take_damage(0)` is called, then `iframe_timer > 0` and `health_changed(current, max)` was emitted with the same values (health unchanged). This verifies EC-01 behaviour.

## Open Questions

[To be designed]
