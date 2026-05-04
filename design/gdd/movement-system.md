# Movement System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-04-27
> **Implements Pillar**: Controlled Ascension, Spell Alchemy (support)

## Overview

The Movement System is the Core-layer system that owns the wizard's physical presence in the world: horizontal velocity, vertical velocity, gravity, ground contact state, and the input-to-physics translation that produces running, jumping, and dashing. It receives directional input from the Input System — `move_left`, `move_right`, `jump`, and `dash` actions, plus the left stick continuous vector — and applies them to the wizard's `CharacterBody2D` node each physics frame via `move_and_slide()`. The resulting world position is the source of truth that the Camera System follows and that the Zone/Room System uses to detect room boundaries and zone triggers.

In the MVP, the wizard can run, jump, and dash. Two additional movement abilities unlock through Controlled Ascension progression: double jump and air dash. Both abilities are registered by the Movement System but disabled until the Progression System signals their unlock — this system owns the capability state and enforces which abilities are active at any given moment. Locked abilities produce no input response; they do not exist from the player's perspective until earned.

The Movement System does not own combat, spell casting, damage, or health — those belong to their respective systems. Its scope is strictly locomotion: the wizard getting from A to B. The game's anti-pillar makes this boundary explicit: movement is traversal, not the test. The test is what the wizard does when he arrives.

## Player Fantasy

The wizard's body is not a weapon. It is the thing that has carried him from the place he was born to the place he will die, and it has not yet failed him. Running, jumping, the short sharp dash when something moves wrong in the corner of the eye — these are not feats. They are the quiet competence of a man who has learned, in years he does not like to remember, how to keep moving when stopping is not an option.

The player should never feel athletic. The player should feel **carried** — the way a hunted animal is carried by its legs without thinking about them, until the moment thinking about them is the only thing keeping it alive. When the player stops noticing the inputs and starts noticing the room, the system is working.

Movement is the floor of the experience. The test is the spell — the fight, the interaction discovered, the pattern read and answered. Everything between: the corridor, the leap across the broken stair, the dash through the gap before the door swings shut — is the distance traveled to reach the next decision. Movement exists so the wizard can arrive.

The abilities that come later — the second jump, the dash that carries him through the air — do not arrive as gifts. They arrive as memories surfacing. The order trained him before it decided to hunt him. He always knew how. He simply had not, until this moment, needed to.

## Detailed Design

### Core Rules

1. **Physics owner.** Movement System owns `velocity` on the player `CharacterBody2D`. No other system writes `velocity.x`/`velocity.y` directly — they signal the HSM instead.

2. **Input source.** Four Godot actions: `move_left`, `move_right`, `jump`, `dash`. Axis is continuous float via `Input.get_axis()`. No diagonal movement — 2D platformer.

3. **Asymmetric gravity.** Ascent: `GRAVITY = 900 px/s²`. Descent: `FALL_GRAVITY = 1400 px/s²`. Faster fall without sacrificing jump arc height.

4. **Variable-height jump.** Releasing jump while ascending multiplies `velocity.y` by `JUMP_CUT = 0.4`. Tap = short hop; hold = full arc.

5. **Coyote time.** `COYOTE_TIME = 0.12s` after walking off a ledge, jump still fires as if grounded.

6. **Jump buffer.** Jump pressed up to `JUMP_BUFFER = 0.10s` before landing is honored on first grounded frame.

7. **Terminal velocity.** Fall speed clamped at `MAX_FALL_SPEED = 500 px/s`.

8. **Instant horizontal response.** No acceleration or deceleration. `velocity.x = SPEED * dir` snaps immediately. Press = move; release = stop.

9. **Dash.**
   - Direction: input axis at dash moment, or current facing direction if no input.
   - Speed: `DASH_SPEED = 220 px/s`, horizontal only.
   - Duration: `DASH_DURATION = 0.18s`.
   - Gravity suspended during dash (`skip_gravity = true`).
   - Cooldown: `DASH_COOLDOWN = 0.6s` from entry.
   - Requires `GameManager.has_ability("dash")` — locked until Progression grants it.

10. **Double jump.** Only available in Fall state. Costs one charge (`jumps_left`, max 1). Resets on landing. Requires `GameManager.has_ability("double_jump")`.

11. **Ability gating.** Both abilities queried live from `GameManager.has_ability()` every input frame. Grant activates instantly without system restart.

---

### State Machine

Uses LimboHSM (LimboAI addon). States: **Idle, Run, Jump, Fall, Dash, Attack, Death**.

| State | Enters when | Exits when |
|-------|-------------|------------|
| **Idle** | Land / end dash / spawn | Move → Run; Jump → Jump; No floor → Fall; Dash → Dash; Attack → Attack |
| **Run** | Move input + grounded | No input → Idle; Jump → Jump; No floor → Fall; Dash → Dash; Attack → Attack |
| **Jump** | Jump input (ground / coyote / double) | `velocity.y ≥ 0` → Fall; Dash → Dash; Attack → Attack |
| **Fall** | No floor + `velocity.y ≥ 0` | Land → Idle; Jump (coyote / double) → Jump; Dash → Dash; Attack → Attack |
| **Dash** | Dash input (unlocked + off cooldown) | Timer ends → Idle |
| **Attack** | Attack input (mana + off cooldown) | Anim ends → Idle / Run / Fall |
| **Death** | `die` signal from any state | Respawn → Idle |

Attack behavior defined in Combat/Spell System GDD. Movement System owns transitions to/from Attack only.

---

### Interactions with Other Systems

| System | Direction | Exchange |
|--------|-----------|---------|
| Input System | → Movement | `move_left/right/jump/dash` action states per physics frame |
| Camera System | Movement → | `global_position` as follow target |
| Progression System | → Movement | `has_ability("dash")`, `has_ability("double_jump")` — queried live |
| Zone/Room System | Movement → | `global_position` monitored for boundary/trigger detection |
| Combat System | Bidirectional | Attack state entered from Movement; dispatches `stop/move/fall` back |
| Health System | → Movement | `player_died` signal → `die` event → Death state |

## Formulas

### Jump Arc

```
peak_height = JUMP_VELOCITY² / (2 × GRAVITY)
            = 325² / (2 × 900)
            = 105 625 / 1800
            ≈ 58.7 px

time_to_apex = |JUMP_VELOCITY| / GRAVITY
             = 325 / 900
             ≈ 0.36s

short_hop_velocity = JUMP_VELOCITY × JUMP_CUT
                   = -325 × 0.4
                   = -130 px/s

short_hop_peak ≈ 130² / (2 × 900) ≈ 9.4 px
```

### Fall Duration (from apex)

```
time_apex_to_ground = sqrt(2 × peak_height / FALL_GRAVITY)
                    = sqrt(2 × 58.7 / 1400)
                    ≈ 0.29s

total_jump_time ≈ 0.36 + 0.29 = 0.65s
```

### Dash Distance

```
dash_distance = DASH_SPEED × DASH_DURATION
              = 220 × 0.18
              = 39.6 px
```

### Horizontal Range per Jump

```
horizontal_range = SPEED × total_jump_time
                 = 90 × 0.65
                 ≈ 58.5 px
```

### Gravity Application (per physics frame)

```
if velocity.y > 0:   -- descending
    velocity.y = min(velocity.y + FALL_GRAVITY × delta, MAX_FALL_SPEED)
else:                -- ascending
    velocity.y = min(velocity.y + GRAVITY × delta, MAX_FALL_SPEED)
```

### Variable Definitions

| Variable | Value | Unit | Description |
|----------|-------|------|-------------|
| `SPEED` | 90 | px/s | Horizontal run speed |
| `JUMP_VELOCITY` | −325 | px/s | Initial vertical velocity on jump |
| `JUMP_CUT` | 0.4 | multiplier | Short-hop velocity truncation |
| `GRAVITY` | 900 | px/s² | Ascent gravity |
| `FALL_GRAVITY` | 1400 | px/s² | Descent gravity |
| `MAX_FALL_SPEED` | 500 | px/s | Terminal velocity (positive = downward) |
| `COYOTE_TIME` | 0.12 | s | Ledge-forgiveness window |
| `JUMP_BUFFER` | 0.10 | s | Pre-land jump input window |
| `DASH_SPEED` | 220 | px/s | Dash horizontal speed |
| `DASH_DURATION` | 0.18 | s | Dash active time |
| `DASH_COOLDOWN` | 0.6 | s | Time before next dash allowed |

## Edge Cases

**EC-01 — Jump input on the exact frame of walking off a ledge.**
Coyote timer is set to `COYOTE_TIME` on every grounded frame via `_post_move()`. If the player walks off a ledge, the timer counts down from 0.12s. A jump input within that window fires normally. If the timer has already expired, the jump is refused unless `jumps_left > 0` (double jump).

**EC-02 — Jump buffered while airborne, double jump also available.**
Jump buffer and double jump are separate checks. Buffer is honored on landing (ground jump). Double jump fires immediately in Fall state regardless of buffer. If both are pending simultaneously, the active state resolves: Fall state checks double jump first; landing resolves the buffer. No double-consumption.

**EC-03 — Dash into a wall.**
`move_and_slide()` handles collision. `velocity.x` is set each frame of Dash state so the wizard is pushed flush against the wall but does not pass through. Dash timer continues counting — the wizard exits Dash state normally when the timer expires, regardless of whether he moved the full distance.

**EC-04 — Dash input while already dashing.**
Ignored. Dash state does not check `wants_dash()`. `dash_cooldown` is set at Dash entry; it will not be zero during the active dash anyway.

**EC-05 — Double jump while coyote time is active.**
Coyote jump takes priority. `can_jump()` returns true during coyote window. Fall state dispatches `jump` via the coyote path, consuming `coyote_timer`. `jumps_left` is not consumed — coyote is a ground jump.

**EC-06 — Ability unlocked mid-air (e.g. cutscene grants double jump while falling).**
`has_ability()` is queried live. If `double_jump` is granted while the wizard is in Fall state, `jumps_left` will be 0 (was set on last landing before the ability existed). The double jump will not be available until next landing, which calls `reset_air_moves()` and sets `jumps_left = 1`. No exploit window.

**EC-07 — Death during dash.**
`die` is an `ANYSTATE` transition in LimboHSM. Death state is entered immediately. `_exit()` on DashState fires, setting `skip_gravity = false`. Gravity resumes. Death animation plays correctly.

**EC-08 — Jump buffer fires on landing from a death respawn.**
Death state transitions to Idle on `land` event. `jump_buffer` is a timer ticked independently in `_physics_process` — it does not reset on death. If the player pressed jump during the death animation, the buffer could fire on respawn landing. Buffer is negligible here (0.10s) and the respawn transition takes longer than that. No action needed; buffer expires naturally.

**EC-09 — Move input held through Dash exit.**
Dash exits to Idle regardless of input. Idle immediately checks for move input and dispatches `move` → Run on the same frame. Player returns to running without a visible stop frame.

**EC-10 — Coyote time while double jump has no charges.**
If `jumps_left = 0` and coyote window is open, `can_jump()` still returns true. The coyote jump fires. Coyote time is a ground-jump forgiveness mechanic, independent of `jumps_left`.

## Dependencies

### Systems this requires

| System | What Movement needs from it |
|--------|---------------------------|
| **Input System** | `move_left`, `move_right`, `jump`, `dash` actions registered in Godot's InputMap |
| **Progression System** | `GameManager.has_ability(String) → bool` — queried live each frame for `"dash"` and `"double_jump"` |
| **Health System** | `GameManager.player_died` signal — consumed to dispatch `die` event into the HSM |
| **LimboAI addon** | `LimboHSM` and `LimboState` classes — HSM runtime |

### Systems that require this

| System | What it needs from Movement |
|--------|---------------------------|
| **Camera System** | Player `global_position` each frame as follow target |
| **Zone/Room System** | Player `global_position` for boundary detection and zone triggers |
| **Combat System** | Velocity context during Attack state; HSM transitions (`stop`, `move`, `fall`) dispatched back after attack resolves |
| **Save/Load System** | Player `global_position` at save point — written by Save System, restored on load |

### Hard blockers (must exist before Movement is testable)

- Input System: actions mapped in InputMap
- LimboAI addon: installed and active
- `GameManager` autoload: `has_ability()`, `player_died` signal present

## Tuning Knobs

All values live in `scripts/player/player.gd` as constants. All states read them via the `agent` reference.

| Knob | Current | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `SPEED` | 90 px/s | 70–130 | Traversal pace. Below 70: sluggish. Above 130: level geometry needs wider spacing. |
| `JUMP_VELOCITY` | −325 px/s | −250 to −400 | Peak jump height (≈59 px current). Change paired with `GRAVITY` — recheck level geometry gaps. |
| `JUMP_CUT` | 0.4 | 0.2–0.6 | Short-hop height ratio. Lower = more punishing tap; higher = less variable-height control. |
| `GRAVITY` | 900 px/s² | 600–1200 | Ascent arc shape. Lower = floaty; higher = snappy. Pair with `JUMP_VELOCITY`. |
| `FALL_GRAVITY` | 1400 px/s² | 900–2000 | Descent speed. Must exceed `GRAVITY` to maintain asymmetric feel. |
| `MAX_FALL_SPEED` | 500 px/s | 350–700 | Terminal velocity. Below 350: visible decel before ground. Above 700: hazard collision windows shrink. |
| `COYOTE_TIME` | 0.12 s | 0.08–0.20 | Ledge forgiveness. Below 0.08: players notice missed jumps. Above 0.20: feels exploitable. |
| `JUMP_BUFFER` | 0.10 s | 0.06–0.15 | Pre-land leniency. Below 0.06: fast repeated jumps become frame-tight. Above 0.15: jumps fire unexpectedly after long falls. |
| `DASH_SPEED` | 220 px/s | 160–300 | Dash distance + feel. Must stay above `SPEED`. Current distance: 39.6 px. |
| `DASH_DURATION` | 0.18 s | 0.12–0.28 | Dash active time (paired with `DASH_SPEED`). Shorter = micro-dodge; longer = traversal tool. |
| `DASH_COOLDOWN` | 0.6 s | 0.3–1.2 | Dash availability. Below 0.3: spammable, breaks encounter design. Above 1.2: punishing on missed dashes. |

## Visual/Audio Requirements

### Animations

All played on `AnimatedSprite2D`. Horizontal flip via `anim.flip_h` — no mirrored animation assets needed.

| Animation | Trigger | Notes |
|-----------|---------|-------|
| `idle` | Idle state enter | Looping breathing/standing cycle |
| `run` | Run state enter | Looping. SFX footstep fires on frames 0 and 3 |
| `jump` | Jump state enter | Single play upward arc |
| `fall` | Fall state enter | Looping descent pose |
| `dash` | Dash state enter | Single play; must complete within `DASH_DURATION` (0.18s) |
| `death` | Death state enter | Single play; does not loop |

### Sound Effects

| SFX | Node | Trigger | Notes |
|-----|------|---------|-------|
| Footsteps | `StepSFX` (AudioStreamPlayer) | Run frames 0 and 3 via `frame_changed` signal | Frequency tied to animation speed — do not drive with a separate timer |
| Jump | `JumpSFX` (AudioStreamPlayer) | Jump state `_enter()` | Single short burst |
| Land | None currently | — | **Gap**: no landing SFX. Ground impact feedback recommended. |
| Dash | None currently | — | **Gap**: no dash SFX. Short whoosh recommended. |

### Visual Feedback Gaps (not blockers)

- No dash trail / ghost effect — adds directional read on dash
- No squash-and-stretch on jump/land — adds physicality without hitbox change
- No dust particles on land or run start — standard metroidvania polish layer

## UI Requirements

Movement System has minimal direct HUD presence. Movement state is communicated through animation and SFX — not UI elements.

### Dash Cooldown Indicator

Movement does not emit a dash cooldown signal. Dash availability is implicit — the wizard simply does not respond to dash input when on cooldown. No UI element required unless playtesting reveals players find the cooldown opaque.

If a dash indicator is added later, the signal pattern already exists (`GameManager.attack_cooldown_changed` is the model) — emit `dash_cooldown_changed(current, max)` from `_tick_timers()`.

### Ability Unlock Feedback

When `dash` or `double_jump` is granted by Progression, the player needs feedback that a new movement ability is available. This is **not owned by Movement System** — it is a Progression/HUD concern. Movement System only gates behavior; it does not announce unlocks.

### Nothing else required

Movement System does not drive health bars, mana bars, maps, or any other HUD element. Those belong to Health, Combat, and Zone systems respectively.

## Acceptance Criteria

Each criterion is pass/fail verifiable by a QA tester without access to code.

**AC-01 — Run**
Hold `move_right` on flat ground. Wizard moves right continuously. Release: wizard stops on the same frame with no slide. Repeat left. Pass: instant start/stop both directions.

**AC-02 — Jump height**
On flat ground, press and hold jump. Wizard clears a 56 px tall obstacle placed 0 px away horizontally. Pass: clears without touching.

**AC-03 — Short hop**
Tap jump (release within 3 frames). Wizard does not clear the 56 px obstacle. Pass: apex visibly lower than full jump.

**AC-04 — Coyote time**
Run off a ledge edge. Press jump within 0.12s of leaving the floor. Wizard jumps. Pass: jump fires; wizard does not fall straight down.

**AC-05 — Jump buffer**
While falling toward the floor, press jump ~0.08s before landing. Wizard jumps on the first grounded frame without re-pressing. Pass: immediate jump on land.

**AC-06 — Dash (locked)**
With `dash` ability not granted, press dash. Nothing happens. Pass: no movement response.

**AC-07 — Dash (unlocked)**
With `dash` ability granted, press dash. Wizard moves horizontally ~40 px in 0.18s with no vertical drop. Pass: straight horizontal burst, gravity inactive during dash.

**AC-08 — Dash cooldown**
Dash once. Immediately press dash again. Nothing happens. Wait 0.6s. Press dash. Wizard dashes. Pass: second dash fires only after cooldown.

**AC-09 — Dash direction**
Press dash with no directional input. Wizard dashes toward current facing direction. Press dash while holding opposite direction. Wizard dashes that direction. Pass: both cases correct.

**AC-10 — Double jump (locked)**
With `double_jump` ability not granted, jump then press jump again while airborne. No second jump. Pass: single jump only.

**AC-11 — Double jump (unlocked)**
With `double_jump` granted, jump then press jump again while airborne. Wizard jumps a second time. Pass: two distinct jump arcs observable.

**AC-12 — Double jump charge reset**
Use double jump. Land. Jump and double jump again. Pass: double jump available every time after landing; not available a second time in the same air session.

**AC-13 — Death interrupts all states**
While dashing, trigger death. Wizard enters death animation immediately. Gravity resumes (no horizontal freeze). Pass: no stuck-in-dash state after death.

**AC-14 — Footstep audio**
Run on flat ground. Two footstep sounds per run animation cycle. Pass: audible, rhythm matches animation frames.

**AC-15 — Asymmetric gravity feel**
Jump and observe arc shape. Fall should be visibly faster than ascent. Pass: arc is not symmetric; descent takes less time than ascent.
