# Camera System

> **Status**: In Review
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-04-23
> **Implements Pillar**: Controlled Ascension, Earned Truth, Sensation

## Overview

The Camera System is a Foundation-layer infrastructure system that manages all 2D camera behavior in Wizrless. It is built on the PhantomCamera 2D addon, which provides priority-based camera node selection, configurable follow interpolation, and damping. The system defines four distinct camera modes — Exploration, Combat, Boss Room, and Dialogue — each implemented as a separate `PhantomCamera2D` node. The active mode is selected by priority: the highest-priority visible `PhantomCamera2D` node owns the `Camera2D` at any time. Exploration mode (lowest priority) runs by default; zone triggers or gameplay events make higher-priority pcam nodes visible to override it. Nodes are deactivated by setting `visible = false` on the pcam node (not by priority manipulation — see CR-CB-1). The Zone/Room System pushes room boundary limits per room as `NodePath` references to `CollisionShape2D` nodes; the Movement System owns player position which Exploration and Combat cameras follow. Boss Room mode is a static arena-centered frame — the camera does not follow the player during a boss fight. Dialogue mode provides designer-framed static shots for pre-boss exchanges. The Camera System owns no game logic — it is a pure presentation layer that makes the rest of the game spatially and emotionally legible.

## Player Fantasy

The wizard sees the world the way a hunted man sees it: softly during the long walks where memory is the only company, sharply when steel is near, and not at all beyond the walls of the room where his teachers wait to judge him. The player inherits this sight.

In exploration, the frame drifts with him — forgiving, unhurried, giving the crumbling academy and its forgotten corridors the space to speak. In combat, the frame leans toward the threat, and the player's attention leans with it, because in this order you learn to look at the knife before it is drawn. The camera does not announce the shift; the player simply finds themselves already reading the space differently.

When a boss shuts the door, the camera shuts with it. The frame locks. There is no horizon to flee toward, no offscreen to retreat into. The player understands, without being told, that this is where a piece of the truth will be earned or lost. The camera does not deliver this feeling — it simply refuses to let the player look away.

## Detailed Design

### Core Rules

#### Exploration Mode (EXPLORATION)

**CR-EX-1.** Exploration mode is the default active mode. Its `PhantomCamera2D` node is assigned priority tier **0** (lowest). No other camera node may share or use a value below 0.

**CR-EX-2.** The camera follows the player's `CharacterBody2D` world position using damped interpolation. All damping is configured on the `PhantomCamera2D` node via `ex_follow_damping`. `Camera2D.position_smoothing` is disabled by PhantomCamera automatically and must not be re-enabled.

**CR-EX-3.** A rectangular deadzone is active. The player can move within the deadzone without the camera translating. Deadzone dimensions are tuning knobs `ex_deadzone_h` (horizontal) and `ex_deadzone_v` (vertical).

**CR-EX-4.** Look-ahead is disabled. The Exploration camera is passive — it does not anticipate the player's direction. This is a deliberate design decision: the wizard's Fantasy is that of a persecuted man who does not see what is ahead because the world has not decided to show him yet. Comfort mechanics that extend the player's sightline contradict this tone. `follow_offset` is always `(0, 0)` in Exploration mode. PhantomCamera's built-in `lookahead` property must be left disabled.

**CR-EX-5.** Room camera bounds are supplied by the Zone/Room System as a `NodePath` pointing to a `CollisionShape2D` node, assigned to the `limit_target` property on each pcam. Call: `pcam.limit_target = pcam.get_path_to(collision_shape_node)` — passing the node reference directly will fail. The camera hard-stops at this boundary — PhantomCamera does not implement soft easing at boundary edges. Note: resizing a `Shape2D` at runtime does not update the camera limits; the Zone/Room System must re-assign `limit_target` if room geometry changes. The Zone/Room System must push boundary data *before* the player crosses a room threshold, not after.

**CR-EX-6.** Camera shake is active. Shake applies as a screen-space offset via two separate `NoiseEmitter2D` nodes — one for Damage Shake, one for Impact Shake — with distinct parameter sets. Shake does not scale with zoom level.

**CR-EX-7.** Zoom is `ex_zoom`. Exploration and Combat modes share the same zoom value. The rationale is a feel-goal, not an implementability constraint: the world does not change size when a threat appears — only the player's attention shifts. Spatial scale is constant; what changes between modes is deadzone tightness and follow responsiveness. Zoom divergence between Exploration and Combat is explicitly forbidden — this design choice owns that decision intentionally.

#### Combat Mode (COMBAT)

**CR-CB-1.** Combat mode uses priority tier **10**. When a Combat Zone `Area2D` `body_entered` fires for the player, the zone script sets `phanCam_combat.visible = true` (if not already) and calls `phanCam_combat.set_priority(10)`, immediately overriding Exploration. On deactivation, call `phanCam_combat.visible = false`. **Do not use `set_priority(-1)` for deactivation** — PhantomCamera's `set_priority` setter clamps its argument to a minimum of 0, silently setting priority to 0 and producing undefined behaviour with the Exploration pcam (also at priority 0). Visibility is the correct deactivation mechanism.

**CR-CB-2.** Follow is active using `cb_follow_damping` — tighter than `ex_follow_damping` for more responsive tracking.

**CR-CB-3.** Look-ahead is disabled. Combat deadzone is tighter than Exploration: `cb_deadzone_h` and `cb_deadzone_v`.

**CR-CB-4.** Zoom is identical to Exploration (shared `ex_zoom`). This is a hard rule, not a tuning knob.

**CR-CB-5.** Camera shake is active. All shake rules from Exploration apply identically.

**CR-CB-6.** Room bounds apply identically to Exploration (CR-EX-5). The combat `PhantomCamera2D` must have its own `limit_target` configured — limits do not transfer between pcam nodes automatically.

**CR-CB-7.** Combat mode deactivates when all enemies in the zone are defeated, regardless of player position. The trigger is "enemies defeated" alone — the player's position inside or outside the zone does not gate the transition. A short hold delay of `transition_combat_clear_delay` seconds is observed before blending to Exploration (gives the player a moment to react to the kill). Enemy-state queries are owned by the Zone/Room System; the Camera System does not track enemy state. See EC-08 for the previously documented T-02 deadlock that this rule resolves.

**CR-CB-8.** Overlapping Combat Zones authored in the same scene are a level design error. Only one `phanCam_combat` node exists per scene. Level designers must not author overlapping Combat Zone triggers. If violated, both zones will attempt to call `set_priority(10)` on the same pcam node — the second call is a no-op, but the Zone/Room System's enemy-alive tracking will be ambiguous (two zones, one pcam). Observable failure: Combat mode never deactivates because one zone's enemy count is always non-zero. Detectable in the Godot scene tree by checking for duplicate `phanCam_combat` nodes.

#### Boss Room Mode (BOSS_ROOM)

**CR-BR-1.** Boss Room mode uses priority tier **20**. On entering the Boss Room `Area2D`, the zone script sets `phanCam_boss_room.visible = true` and calls `phanCam_boss_room.set_priority(20)`. This immediately overrides any active camera regardless of mid-transition state — higher priority always wins and interrupts ongoing blends. Deactivation uses `phanCam_boss_room.visible = false` (same deactivation rule as CR-CB-1).

**CR-BR-2.** The Boss Room camera is **static** — `follow_mode = FollowMode.NONE`. The pcam node is positioned in the scene at the arena's designed anchor point (typically arena center). The camera does not follow the player. The player moves freely within the always-visible arena frame. The player must not be cropped at any reachable arena position (arena design responsibility — see CR-BR-4). The boss must also remain within the arena bounds at all times — boss designers are responsible for ensuring no attack or movement pattern drives the boss outside the visible frame (see CR-BR-4).

**CR-BR-3.** `br_zoom` is set wide enough that the entire arena is visible within the frame at all times. Both side walls and both vertical extents must be visible simultaneously. The designer authors `br_zoom` per-boss-room in the scene and validates it at scene authoring time: `arena_width ≤ viewport_width / br_zoom.x` and `arena_height ≤ viewport_height / br_zoom.y`. There is no global default — each boss room defines its own value. No deadzone or look-ahead applies.

**CR-BR-4.** The arena and boss movement must both fit within the camera frame at `br_zoom`. This is a dual level/boss design contract enforced at scene authoring time, not at runtime.

**Player framing constraint (CR-BR-3):** `arena_width ≤ viewport_width / br_zoom.x` and `arena_height ≤ viewport_height / br_zoom.y`.

**Boss framing constraint:** For each boss attack or movement pattern, the maximum displacement from arena center must satisfy: `max_boss_displacement ≤ (arena_half_width - frame_margin)` on each axis, where `frame_margin` is a minimum buffer of 32 px (world-space). Boss designers must annotate their movement boundaries in the boss design spec and verify against this formula at authoring time. The Camera System does not enforce or detect boss-out-of-frame at runtime — violation is a design error caught in scene review. If any attack pattern cannot satisfy this constraint, the arena must be enlarged or the attack redesigned; the camera does not follow the boss.

**CR-BR-5.** Camera shake is active and expected to be heavier in boss rooms. Boss-specific shake events (slam, phase transition) are triggered by the Boss System calling `emit()` on the appropriate `NoiseEmitter2D`. The Camera System does not initiate shake.

**CR-BR-6.** Boss Room mode deactivates on receiving `boss_defeated` signal from the Boss System. On receipt: (a) hold current camera position for `br_death_hold_duration` (default 3.0 s — the held beat after a former friend's death must breathe), then (b) blend to the lower-priority camera over `br_death_blend_duration`, `TRANS_SINE + EASE_OUT`. Do not cut immediately. The hold time is intentionally long — it is the most emotionally significant moment in the game session.

**CR-BR-7.** Boss Room mode cannot be exited by normal zone exit during combat. The arena door lock is the Boss System's responsibility. If the player exits the Boss Room `Area2D` without `boss_defeated` (player death followed by scene reload, room reset, etc.), the camera falls back to the next active priority. Player death is the primary failure state — see EC-11.

#### Dialogue Mode (DIALOGUE)

**CR-DL-1.** Dialogue mode uses priority tier **25** (highest of all modes). It activates temporarily on top of Boss Room mode to provide a designed static frame for pre-boss exchanges between the wizard and a former friend. `phanCam_dialogue` is positioned by the level designer in the boss room scene at the intended framing position. `follow_mode = FollowMode.NONE`.

**CR-DL-2.** Dialogue mode is activated by the Narrative System on receiving `boss_dialogue_started` from the Boss System: `phanCam_dialogue.visible = true`, `phanCam_dialogue.set_priority(25)`. Boss Room mode (priority 20) remains active underneath — Dialogue simply takes priority on top. On `boss_dialogue_complete`, the Narrative System deactivates: `phanCam_dialogue.visible = false`. Boss Room (priority 20) resumes without any explicit re-activation.

**CR-DL-3.** Dialogue mode blend-in uses `transition_to_dialogue` seconds, `TRANS_SINE + EASE_IN_OUT` — slow and ceremonial, not a cut. Blend-out on `boss_dialogue_complete` uses `transition_from_dialogue` seconds, `TRANS_SINE + EASE_IN_OUT`.

**CR-DL-4.** No shake, no follow, no deadzone in Dialogue mode. If a shake event fires during dialogue (e.g. a boss telegraphing the fight), it is emitted as normal — the static camera frame makes shake more impactful, not less.

**CR-DL-5.** `phanCam_dialogue` exists only in boss room scenes. It is not placed in regular combat or exploration rooms.

#### Camera Shake (all modes)

**CR-SH-1.** Two shake profiles exist, implemented as two separate `NoiseEmitter2D` nodes:
- **Damage Shake** (`shake_emitter_damage`): triggered by Health System signal `player_damaged`. Parameters: `shake_dmg_intensity`, `shake_dmg_duration`, `shake_dmg_frequency`.
- **Impact Shake** (`shake_emitter_impact`): triggered by Spell System signal `heavy_impact_resolved` for spells flagged `shake_on_impact: true`. Parameters: `shake_impact_intensity`, `shake_impact_duration`, `shake_impact_frequency`.

Damage Shake is sharp and brief (interrupt feel); Impact Shake is lower-frequency and slightly longer (resonance feel). They must be perceptually distinguishable.

**CR-SH-2.** Shake applies as screen-space positional offset only — magnitude does not scale with zoom. **Rotational shake is not used.** The `rotational_noise` property on both NoiseEmitter2D noise resources must be set to `false` (addon default). `Camera2D.ignore_rotation` remains at default `true`. This is a deliberate design decision — rotational shake reads as disorientation rather than impact, and in a game that uses camera framing to deliver emotional beats, involuntary rotation undermines player legibility.

**CR-SH-3.** Stacking rule: if a new shake fires while one is in progress, use **replace-if-higher** — the new shake wins only if its intensity exceeds the current decaying magnitude. It does not add to the envelope.

**CR-SH-4.** No single shake event may exceed `shake_max_intensity`. No shake event may be below `shake_min_intensity` — imperceptible shake is not feedback.

**CR-SH-5.** Shake is globally suppressible by the Accessibility System via `camera_shake_enabled` (default: on). When disabled, all `emit()` calls to both emitter nodes are blocked at the Camera System level. No other feedback channel is affected.

---

### States and Transitions

| State | Active Node | Priority | Follow | Look-ahead | Shake |
|---|---|---|---|---|---|
| **EXPLORATION** | `phanCam_exploration` | 0 | Player pos, `ex_follow_damping`, `FollowMode.FRAMED` | Off (see CR-EX-4) | On |
| **COMBAT** | `phanCam_combat` | 10 | Player pos, `cb_follow_damping`, `FollowMode.FRAMED` | Off | On |
| **BOSS_ROOM** | `phanCam_boss_room` | 20 | None (`FollowMode.NONE`, static at scene anchor) | Off | On |
| **DIALOGUE** | `phanCam_dialogue` | 25 | None (`FollowMode.NONE`, static at designer position) | Off | On |

Priority tiers maintain minimum separation of 5. No two visible pcam nodes may share a priority value simultaneously. Deactivation uses `pcam_node.visible = false` — never `set_priority(-1)`.

**Easing standard:** unless specified otherwise, all blends use `TRANS_SINE` transition type. "Ease-in-out" = `TRANS_SINE + EASE_IN_OUT`. "Ease-in" = `TRANS_SINE + EASE_IN`. "Ease-out" = `TRANS_SINE + EASE_OUT`.

| # | Trigger | From | To | Blend |
|---|---|---|---|---|
| T-01 | Player enters Combat Zone `Area2D` (`body_entered`) | EXPLORATION | COMBAT | `transition_ex_to_cb` s, `TRANS_SINE + EASE_IN_OUT` |
| T-02 | All zone enemies defeated (regardless of player position), after `transition_combat_clear_delay` s | COMBAT | EXPLORATION | `transition_cb_to_ex` s, `TRANS_SINE + EASE_IN_OUT` |
| T-03 | Player exits Combat Zone, enemies still alive | COMBAT | COMBAT | No change |
| T-04 | Player enters Boss Room `Area2D` | EXPLORATION or COMBAT | BOSS_ROOM | `transition_to_boss` s, `TRANS_SINE + EASE_IN`; interrupts any in-progress tween |
| T-05 | `boss_defeated` signal received | BOSS_ROOM | EXPLORATION or COMBAT | Hold `br_death_hold_duration` s (3.0 s default), then `br_death_blend_duration` s, `TRANS_SINE + EASE_OUT` |
| T-06 | Room boundary data pushed by Zone/Room System | EXPLORATION, COMBAT | Same | No tween; `limit_target` NodePath updated silently mid-state |
| T-07 | Player crosses room threshold (Exploration) | EXPLORATION | EXPLORATION | No tween; follow continues, `limit_target` updates to new room |
| T-08 | `camera_shake_enabled` toggled | Any | Same | No state change; emitter `emit()` calls blocked/unblocked at runtime |
| T-09 | `boss_dialogue_started` signal from Boss System | BOSS_ROOM | DIALOGUE | `transition_to_dialogue` s, `TRANS_SINE + EASE_IN_OUT`; BOSS_ROOM remains active at priority 20 underneath |
| T-10 | `boss_dialogue_complete` signal from Boss System | DIALOGUE | BOSS_ROOM | `transition_from_dialogue` s, `TRANS_SINE + EASE_IN_OUT`; DIALOGUE deactivated, BOSS_ROOM (priority 20) resumes |
| T-11 | Player dies in BOSS_ROOM (death signal from Health System) | BOSS_ROOM or DIALOGUE | EXPLORATION or COMBAT | Immediate deactivation of Boss Room and Dialogue pcams on scene reload; camera state resets to whatever priority is active in the new scene |

---

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| Zone/Room System | → Camera | Zone scripts set `pcam_node.visible = true/false` and call `set_priority()` to activate/deactivate modes. Zone/Room must push `limit_target` (`pcam.limit_target = pcam.get_path_to(collision_shape_node)`) to Exploration and Combat pcams before the player crosses a room threshold. Zone/Room owns trigger placement and enemy-alive state queries. |
| Zone/Room System | ← Camera | PhantomCamera emits `tween_completed` on the newly-active pcam when a blend finishes normally. It emits `tween_interrupted` on the previously-active pcam when a higher-priority node interrupts a blend mid-way (e.g. T-04 interrupting T-01). Zone/Room System must handle both signals if it gates boss intro sequences on camera settling. |
| Health System | → Camera | Calls `shake_emitter_damage.emit()` on `player_damaged` signal. Also emits death signal on player death (T-11). |
| Spell System | → Camera | Emits `heavy_impact_resolved` signal when a spell with `shake_on_impact: true` resolves. **Signal contract:** `heavy_impact_resolved` carries no payload required by the Camera System — the Camera System always responds with Impact Shake at its configured parameters. The `shake_on_impact` flag is a boolean property on the Spell resource; it is set to `true` for any spell or spell interaction that produces area damage or a heavy collision effect. The exact list of flagged spells is owned by the Spell System GDD. |
| Boss System | → Camera | Calls `shake_emitter_impact.emit()` for boss-specific shake events. Emits `boss_defeated` (T-05). Emits `boss_dialogue_started` and `boss_dialogue_complete` — these are consumed by the Narrative System, which then drives Camera System dialogue activation (see Narrative System row). |
| Narrative System | → Camera | The Narrative System listens to `boss_dialogue_started` from the Boss System and activates `phanCam_dialogue`: sets `visible = true`, calls `set_priority(25)`. On `boss_dialogue_complete` from the Boss System: deactivates `phanCam_dialogue` (`visible = false`). The Camera System's upstream dependency is on the **Narrative System**, not the Boss System, for dialogue mode activation. |
| Movement System | → Camera (passive) | Camera reads `follow_target` node position via PhantomCamera's `follow_target` property (set to the player's `CharacterBody2D`). No explicit signal needed. |
| Accessibility System | → Camera | Sets `camera_shake_enabled` at runtime, blocking or unblocking all `emit()` calls to both emitter nodes. |

## Formulas

### F-1. Shake Magnitude Envelope (for stacking check)

PhantomCamera's `NoiseEmitter2D` uses a **three-phase model** internally: growth → sustain → decay. The output screen displacement at any moment is `amplitude × trauma²` where `trauma` is a scalar in [0, 1] driven by the phase.

The `NoiseEmitter2D` API exposes no `get_current_trauma()` or `get_elapsed_time()` methods. The Camera System must maintain a **shadow timer** per emitter (`elapsed_t`) incremented in `_process(delta)` and reset to 0 each time `emit()` is called.

**Piecewise magnitude formula M(elapsed_t):**

```
# Guard: discard zero-duration events before this formula runs
# if growth_time + duration + decay_time == 0: discard, return

t_g = growth_time    # rise phase duration
t_s = duration       # sustain phase duration (full intensity)
t_d = decay_time     # decay phase duration

# Growth phase — explicit guard protects division when t_g = 0
if t_g > 0 and elapsed_t < t_g:
    trauma = elapsed_t / t_g
# Sustain phase
elif elapsed_t < t_g + t_s:
    trauma = 1.0
# Decay phase — explicit guard protects division when t_d = 0
elif t_d > 0 and elapsed_t < t_g + t_s + t_d:
    trauma = 1.0 - (elapsed_t - t_g - t_s) / t_d
else:
    trauma = 0.0  # event expired, or t_d = 0 instant cutoff

M(elapsed_t) = intensity × trauma²
```

**Phase rules when a phase has zero duration:** if `t_g = 0`, the growth phase is skipped — the event starts at full intensity. If `t_d = 0`, the decay phase is skipped — the event cuts to zero immediately after sustain. If `t_s = 0`, sustain is instantaneous. All three combinations are valid; no division-by-zero occurs because divisions are guarded by their phase condition.

| Variable | Meaning | Corresponds to |
|---|---|---|
| `intensity` | Maximum amplitude | `amplitude` on the NoiseEmitter2D noise resource |
| `growth_time` | Time from 0 to full intensity | `growth_time` property on NoiseEmitter2D |
| `duration` | Time at full intensity | `duration` property on NoiseEmitter2D |
| `decay_time` | Time from full intensity to 0 | `decay_time` property on NoiseEmitter2D |
| `elapsed_t` | Shadow-tracked time since `emit()` was called | Camera System internal variable |

**Stacking decision** when a new shake event fires:
```
# Apply F-2 first (discard if below min, cap at max)
new_clamped = F2(new_requested_intensity)
if new_clamped is discarded: return

# Guard: discard zero-duration events
if new_growth_time + new_duration + new_decay_time == 0: return

# Compare new event's peak against current decaying magnitude
if new_clamped > M(elapsed_t_now):
    emitter.stop()  # immediate stop — verify this method signature
                    # against the installed PhantomCamera addon version
                    # before implementing; the stop() API may vary
    emit new event with new parameters
    elapsed_t = 0
else:
    discard new event
```

**Note on `emitter.stop()` API:** The method name and signature must be verified against the installed PhantomCamera 2D addon version before implementation. Do not assume a boolean parameter without checking the addon source.

**Note on stacking comparison:** `new_clamped` is the new event's peak intensity. `M(elapsed_t_now)` is the current event's instantaneous decayed magnitude. This comparison is intentionally asymmetric — a new event near-equal in peak to the current one will be suppressed if the current event is still at or near full sustain. This asymmetry is by design: avoid interrupting a strong ongoing shake with an equal-strength replacement.

**Prerequisite:** `assert(shake_min_intensity < shake_max_intensity)` at startup — if misconfigured, `clamp(x, min, max)` with `min > max` returns `min` for all x, producing maximum-intensity shake for every event with no ceiling.

---

### F-2. Shake Intensity Gate

Applied to every shake event **before** the F-1 stacking check:

```
if requested_intensity < shake_min_intensity:
    discard event entirely  # imperceptible shake is not feedback
    return

clamped_intensity = min(requested_intensity, shake_max_intensity)
# Pass clamped_intensity to F-1 stacking check
```

This is a piecewise discard-and-cap, **not** a `clamp()` call. A `clamp()` would raise sub-minimum events to `shake_min_intensity`; this design discards them. The distinction matters: a health-chip tick should not be allowed to play at `shake_min_intensity`; if the damage is too small to warrant visible shake, the event is dropped entirely.

**Example values (tuning defaults):**
- `shake_min_intensity` = 0.3 — below this the screen offset is invisible at normal zoom
- `shake_max_intensity` = 2.0 — above this the frame becomes disorienting

## Edge Cases

**EC-01 — Boss Room `Area2D` exits without `boss_defeated` (e.g. player clip, room reset).**
CR-BR-7 applies: on `body_exited`, the Boss Room pcam falls back to the next highest active priority (Combat or Exploration). The boss intro music stinger and intro sequence are the Boss System's responsibility; the Camera System does not gate them on camera state. This state is a level design bug, not an expected flow.

**EC-02 — `boss_defeated` fires while the Boss Room blend-in tween is still in progress.**
The deactivation sequence (hold → blend-out) begins immediately, interrupting the blend-in. The hold timer (`br_death_hold_duration`) starts from the moment `boss_defeated` is received, regardless of blend state.

**EC-03 — Two `body_entered` signals arrive before the first `body_exited` (re-entry overlap).**
Priority is already at the target value; the second `set_priority()` call is a no-op. Duplicate signals must not stack or produce a second transition.

**EC-04 — Room boundary data not pushed before the player crosses a room threshold.**
The camera hard-stops at the previous room's boundary rather than the new one. The player can walk into the new room while the frame clips on the old wall. This is a Zone/Room System integration error. The Camera System documents the required order (CR-EX-5) but cannot enforce it.

**EC-05 — Boss arena frame constraint violated at `br_zoom`.**
Boss Room mode is static — there are no deadzones. The relevant frame constraints are from CR-BR-3 and CR-BR-4: `arena_width ≤ viewport_width / br_zoom.x` and `arena_height ≤ viewport_height / br_zoom.y`. If either constraint is violated, the player or boss may be cropped. Arena designers must verify both constraints at scene authoring time. Additionally, the boss movement constraint from CR-BR-4 must be verified: `max_boss_displacement ≤ (arena_half_width - 32 px)` on each axis. These are authoring-time checks only — the Camera System does not enforce them at runtime.

**EC-06 — `camera_shake_enabled` toggled from `false` to `true` mid-shake.**
Previously suppressed shake events are not replayed. Shake resumes on the next emitter call. No burst or catch-up.

**EC-07 — Damage Shake and Impact Shake both fire on the same frame.**
Each `NoiseEmitter2D` is independent. Both play simultaneously. The replace-if-higher rule (F-1) applies within each emitter independently — Damage Shake and Impact Shake do not compete with each other, only within their own channel.

**EC-08 — [Previously documented T-02 deadlock, now resolved by CR-CB-7.] Player kills last enemy while outside the Combat Zone.**
Under the old T-02 rule ("all enemies defeated AND player in zone"), this produced a deadlock: `body_exited` had fired so player was not "in zone," and T-02 required the player to be in zone. Camera was permanently stuck in COMBAT with no documented exit. Resolution: CR-CB-7 now fires T-02 on "all enemies defeated" regardless of player position, with `transition_combat_clear_delay` s hold. This edge case no longer exists as a deadlock.

**EC-09 — Player dies in BOSS_ROOM or DIALOGUE mode.**
Player death is the primary failure state of a boss fight. `boss_defeated` is never emitted. On player death: the Health System emits a `player_died` signal. The Zone/Room System owns the respawn and scene reload. On scene reload, all pcam nodes reload with their initial state (`visible = false` for BOSS_ROOM and DIALOGUE, `visible = true` for EXPLORATION). Camera returns to EXPLORATION immediately upon scene load — no explicit camera cleanup required. If the boss room scene is reloaded and the boss is still alive, the player re-enters the Boss Room `Area2D` which re-fires T-04. This is normal re-entry flow.

**EC-10 — Boss death hold timer running when the scene is freed.**
If a scene reload or room transition occurs while the `br_death_hold_duration` timer is running (e.g. a very fast skip or reload triggered by another system), the `Tween` and `Timer` nodes created during the hold sequence may fire into a freed scene tree. The `CameraController` node — which owns the boss death hold sequence — must call `tween.kill()` and `timer.stop()` in its `_exit_tree()` method. The hold sequence (`Tween` + `Timer`) must be created on the `CameraController` node, not on a child or transient node, so that `_exit_tree()` fires before the scene tree is freed. This prevents a Godot 4 "freed object" error. Verify `Tween.kill()` behavior against the Godot 4.6 engine reference (`docs/engine-reference/godot/`) before implementing.

## Dependencies

### Upstream (Camera System depends on these)

| System | What Camera needs | Interface |
|---|---|---|
| **PhantomCamera 2D addon** | Priority-based pcam selection, follow interpolation, damping, limit_target, NoiseEmitter2D shake | Addon API — `set_priority()`, `follow_target`, `limit_target`, `NoiseEmitter2D.emit()` |
| **Zone/Room System** | Room boundary `CollisionShape2D` pushed before player crosses threshold; Combat Zone `Area2D` body signals; enemy-alive state (for T-02) | Signals: `body_entered`, `body_exited`; property write: `limit_target` on pcam nodes |
| **Health System** | `player_damaged` signal to trigger Damage Shake | Signal: `player_damaged` (no payload required by Camera System) |
| **Spell System** | `heavy_impact_resolved` signal for spells with `shake_on_impact: true` | Signal: `heavy_impact_resolved` + metadata flag |
| **Boss System** | `boss_defeated` signal to trigger Boss Room deactivation sequence; boss-specific shake events | Signals: `boss_defeated`, arbitrary boss shake triggers calling `shake_emitter_impact.emit()` |
| **Accessibility System** | `camera_shake_enabled` boolean at runtime | Property set: `camera_shake_enabled` on Camera System node |
| **Narrative System** | Activates and deactivates DIALOGUE mode. On `boss_dialogue_started` (from Boss System): calls `phanCam_dialogue.visible = true`, `phanCam_dialogue.set_priority(25)`. On `boss_dialogue_complete` (from Boss System): calls `phanCam_dialogue.visible = false`. The Camera System's dependency is on the Narrative System, not the Boss System, for dialogue activation. | Calls: `visible` property + `set_priority()` on `phanCam_dialogue` |

### Downstream (these depend on Camera System)

| System | What it reads from Camera | Interface |
|---|---|---|
| **Zone/Room System** | `tween_completed` to gate boss intro sequences behind camera settling | Signal: `tween_completed` on active pcam |
| **UI / HUD System** | No direct dependency. HUD anchors to `CanvasLayer` — unaffected by camera movement. |  |

### Addon Dependency Note

The Camera System has a **hard dependency** on the PhantomCamera 2D addon. If the addon is removed or its API changes, the entire camera mode architecture must be re-implemented. This is the only Foundation-layer system with a third-party addon dependency. No fallback is designed.

## Tuning Knobs

All values below are exported properties on the `CameraController` node (or a `CameraConfig` resource). No values are hardcoded in GDScript.

**Dead zone units:** dead zone properties on PhantomCamera2D are `@export_range(0.0, 1.0)` — they are normalized fractions of viewport half-size, not pixel values. Conversion: `dead_zone_h_normalized = dead_zone_px / (viewport_width / 2 / zoom.x)`. For a 640 px viewport at zoom 1.2: visible half-width = 266.7 px. All `_dz_h` and `_dz_v` knobs below use normalized units (0.0–1.0).

### Exploration Mode

| Knob | Type | Default | Safe Range | Gameplay Effect |
|---|---|---|---|---|
| `ex_follow_damping` | float | 3.0 s | 1.0 – 6.0 | Higher = lazier follow. Below 1.0 feels glued; above 6.0 lags too far in fast traversal. |
| `ex_deadzone_h` | float (0–1) | 0.30 | 0.0 – 0.60 | ≈80 px at 640 viewport, zoom 1.2. Wider = more player movement before camera translates. |
| `ex_deadzone_v` | float (0–1) | 0.40 | 0.0 – 0.80 | ≈60 px at 360 viewport, zoom 1.2. Allows vertical movement to read without constant camera shift. |
| `ex_zoom` | Vector2 | (1.2, 1.2) | (0.8, 0.8) – (1.6, 1.6) | Shared with Combat mode — locked by design. Changing this also changes Combat zoom. |

### Combat Mode

| Knob | Type | Default | Safe Range | Gameplay Effect |
|---|---|---|---|---|
| `cb_follow_damping` | float | 1.5 s | 0.5 – 3.0 | Tighter than exploration. Controls how snappily the camera tracks during combat. |
| `cb_deadzone_h` | float (0–1) | 0.15 | 0.0 – 0.30 | ≈40 px at 640 viewport, zoom 1.2. Tighter than exploration — keeps threats visible. |
| `cb_deadzone_v` | float (0–1) | 0.20 | 0.0 – 0.40 | ≈30 px at 360 viewport, zoom 1.2. |
| `transition_ex_to_cb` | float | 0.3 s | 0.1 – 0.6 | Blend into Combat. Below 0.1 s feels jarring; above 0.6 s the delay is perceptible. |
| `transition_cb_to_ex` | float | 0.5 s | 0.2 – 1.0 | Blend returning to Exploration. Slightly longer — the tension release should breathe. |
| `transition_combat_clear_delay` | float | 0.5 s | 0.0 – 1.5 | Hold after last enemy dies before blending to Exploration. Gives the player time to react to the kill. |

### Boss Room Mode

| Knob | Type | Default | Safe Range | Gameplay Effect |
|---|---|---|---|---|
| `br_zoom` | Vector2 | (varies) | (0.5, 0.5) – (1.0, 1.0) | Per-boss-room scene value. Must satisfy: arena fits entirely within frame (`arena_w ≤ viewport_w / br_zoom.x`). Lower value = more arena visible. |
| `transition_to_boss` | float | 0.6 s | 0.3 – 1.2 | Blend into Boss Room. Should feel ceremonial — longer than combat entry. |
| `br_death_hold_duration` | float | **3.0 s** | 1.5 – 5.0 | Hold after `boss_defeated` before blending out. Default is 3.0 s — this is the death of a former friend. The held beat must breathe. Adjust per-boss for emotional weight (early bosses may be 2.0 s; the final confrontation may be 4.0 s). |
| `br_death_blend_duration` | float | 1.0 s | 0.5 – 2.0 | Blend-out ease duration after the hold. |

### Dialogue Mode

| Knob | Type | Default | Safe Range | Gameplay Effect |
|---|---|---|---|---|
| `transition_to_dialogue` | float | 0.8 s | 0.4 – 1.5 | Blend into Dialogue framing. Slow and ceremonial — this is a significant moment. |
| `transition_from_dialogue` | float | 0.6 s | 0.3 – 1.2 | Blend back to Boss Room after dialogue ends. Slightly faster — the fight is now inevitable. |

### Camera Shake

NoiseEmitter2D uses a three-phase model: growth → sustain → decay. `shake_dmg_duration` and `shake_impact_duration` refer to the **sustain** phase. Add `_growth` and `_decay` knobs below for full control.

| Knob | Type | Default | Safe Range | Gameplay Effect |
|---|---|---|---|---|
| `shake_dmg_intensity` | float | 0.8 | 0.3 – 2.0 | Damage Shake peak amplitude. Sharp interrupt feel. |
| `shake_dmg_growth_time` | float | 0.0 s | 0.0 – 0.05 | Rise time for Damage Shake. Instant onset (0) is the interrupt feel. |
| `shake_dmg_duration` | float | 0.05 s | 0.0 – 0.1 | Sustain phase. Very brief. |
| `shake_dmg_decay_time` | float | 0.2 s | 0.1 – 0.4 | Decay phase. The shake fades over this window. |
| `shake_dmg_frequency` | float | 20 Hz | 8 – 40 | Noise frequency. Higher = more erratic, staccato feel. |
| `shake_impact_intensity` | float | 1.0 | 0.3 – 2.0 | Impact Shake peak amplitude. Resonance feel. |
| `shake_impact_growth_time` | float | 0.05 s | 0.0 – 0.1 | Short rise. Not instant — impact builds briefly then peaks. |
| `shake_impact_duration` | float | 0.1 s | 0.05 – 0.2 | Sustain phase. Slightly longer than damage. |
| `shake_impact_decay_time` | float | 0.25 s | 0.1 – 0.5 | Decay phase. Longer resonance than damage shake. |
| `shake_impact_frequency` | float | 10 Hz | 4 – 20 | Noise frequency. Lower = more rolling, wave-like feel. |
| `shake_min_intensity` | float | 0.3 | 0.1 – 0.5 | Events below this are **discarded entirely** (see F-3). Do not lower below 0.1. |
| `shake_max_intensity` | float | 2.0 | 1.5 – 3.0 | Events above this are capped. Must be > `shake_min_intensity` — validated at startup. Do not exceed 3.0. |

## Visual/Audio Requirements

The Camera System produces no visual or audio assets directly. Its requirements on other systems:

- **Audio System:** no camera-specific music or SFX. Mode transitions are silent — the Audio System owns any music state changes that co-occur with combat/boss triggers. The Camera System does not initiate audio events.
- **VFX:** shake offset is a screen-space effect only. No VFX node is owned by the Camera System.

## UI Requirements

- HUD and all UI elements must be attached to a `CanvasLayer` node, not to the `Camera2D` node tree. This ensures UI is unaffected by camera follow, zoom changes, and shake offsets.
- No camera mode information is surfaced in the HUD. Mode transitions are invisible to the player as a UI event.

## Acceptance Criteria

**Verification prerequisite:** Add a debug export boolean `debug_camera` to the `CameraController` node. When `true`, print camera state transitions and elapsed timers via `Time.get_ticks_msec()` to console. This costs zero release build performance and makes timing-based ACs verifiable without frame-stepping. All ACs marked "debug timer" below require this flag enabled during testing.

### Mode Switching

**AC-01.** When the player enters a Combat Zone `Area2D` (from EXPLORATION with no prior active transitions), the active camera blends to Combat mode. Setup: spawn one enemy in the zone, player in Exploration outside zone. Pass: `became_active` signal fires on `phanCam_combat` within `transition_ex_to_cb + 50ms` of `body_entered` (measured via debug timer print). Fail: blend does not complete, or fires more than 50ms late.

**AC-02.** When all enemies in the Combat Zone are defeated, Combat mode begins returning to Exploration after `transition_combat_clear_delay` seconds, regardless of whether the player is inside or outside the zone. Pass: debug timer shows blend beginning `transition_combat_clear_delay ± 50ms` after last enemy dies — tested with player both inside and outside the zone separately.

**AC-03.** When the player enters the Boss Room `Area2D` while a T-01 blend is in progress, the Boss Room blend begins from the camera's current visual position — not from the pre-blend start position. Setup: trigger T-04 at 0.15 s into a 0.3 s T-01 blend. Pass: at all frames between interrupt and blend completion, `camera_2d.global_position` changes by no more than 8 pixels between any two consecutive frames (verify via debug print of `camera_2d.global_position` each frame during the transition window). Fail: any single-frame delta exceeds 8 px.

**AC-04.** On `boss_defeated`: camera holds position for `br_death_hold_duration` seconds (±100ms), then blends to lower-priority camera over `br_death_blend_duration`. Verification: `debug_camera = true`; console prints `[BOSS_HOLD] started`, `[BOSS_HOLD] elapsed=Xms` at blend-start. Compute delta. Pass: delta within `br_death_hold_duration ± 100ms`. Do not use frame-stepping — use console timestamps.

**AC-05.** At no point during a mode switch do two visible pcam nodes share the same priority value simultaneously. Verification: add a debug check in `_process` that iterates all visible pcam nodes and asserts no two share a priority. Run through T-01, T-02, T-04, T-05, T-09, T-10. Pass: no assertion fires.

**AC-06.** During Dialogue mode (T-09 active), the camera frame is static. Pass: at every frame while dialogue is playing, `phanCam_dialogue.global_position` must be within 0.01 units of its value at the moment `boss_dialogue_started` fires. Sample every 5 frames via debug print; assert no sample exceeds the 0.01-unit threshold. Fail: any sample shows drift.

### Follow and Deadzone

**AC-07.** In Exploration mode, the player can move horizontally without the camera translating, up to the `ex_deadzone_h` fraction of viewport half-width. Verification: enable Godot's remote debugger; monitor `camera_2d.global_position.x` while player moves within the deadzone. Pass: camera X does not change. Fail: camera translates before player exits the deadzone region. Test also for vertical (`ex_deadzone_v`).

**AC-08.** In Boss Room mode, the camera position does not change while the player moves freely within the arena. The player character is never cropped at the four corners and four edge midpoints of the arena (8 test positions). Pass: at all 8 positions, no character body part is outside the visible frame.

**AC-09.** Exploration and Combat modes have identical zoom values at runtime. Pass: `phanCam_exploration.zoom == phanCam_combat.zoom` — assert this in `_ready()` at startup and on any zoom change.

### Camera Shake

**AC-10.** Taking damage triggers Damage Shake. Pass: `shake_emitter_damage` is emitting (`emitter.is_emitting() == true` immediately after `player_damaged` fires). Screen offset is non-zero on the subsequent frame (verify via remote inspector showing Camera2D position shift).

**AC-11.** Damage Shake (20 Hz) and Impact Shake (10 Hz) have measurably different frequency profiles. Setup: record `camera_2d.offset` at 10ms intervals over 500ms for each shake in isolation at default parameters. Compute oscillation frequency from zero-crossings of the offset signal. Pass: Damage Shake produces 18–22 zero-crossings per second (target 20 Hz ±10%); Impact Shake produces 8–12 zero-crossings per second (target 10 Hz ±20%). Fail: either emitter falls outside its range.

**AC-12.** When `camera_shake_enabled = false`, subsequent `emit()` calls produce no screen offset. Pre-existing shake completes normally. Pass: start a 0.4 s shake, set flag to `false` at 0.1 s — camera continues offsetting through 0.4 s. After 0.4 s, trigger a new shake — camera does not respond.

**AC-13.** Replace-if-higher stacking: a new Damage Shake event fired at `t = 0.15 s` into an active shake (default `shake_dmg_decay_time = 0.2 s`) where new intensity is below the current decaying magnitude is discarded. Scripted test: two `emit()` calls 150ms apart, second at lower intensity. Pass: `elapsed_t` shadow timer is not reset; shake envelope continues without interruption.

**AC-14.** Damage Shake and Impact Shake are independent. Pass: fire both simultaneously with both intensities above `shake_min_intensity`. Both emitters show `is_emitting() == true` simultaneously.

**AC-15.** Shake magnitude does not scale with zoom. Setup: trigger identical shake parameters at `ex_zoom = (0.8, 0.8)` and at `ex_zoom = (1.6, 1.6)`. Record peak `camera_2d.offset` magnitude for each. Pass: the two peak magnitudes differ by no more than 1 px. Fail: any difference exceeds 1 px.

**AC-16.** A sub-minimum shake event (`requested_intensity < shake_min_intensity`) is discarded, not raised to minimum. Pass: fire a shake event with `requested_intensity = shake_min_intensity × 0.5`. Verify `camera_2d.offset` remains 0 on all subsequent frames until the next natural shake event. Fail: any non-zero offset.

### Room Boundaries

**AC-17.** The camera does not translate beyond the `limit_target` boundary in Exploration or Combat mode. Pass: walk the player to all four arena walls; `camera_2d.global_position` must not exceed the boundary extents at any point. Hard-stop — no frame of overflow permitted.

**AC-18.** Boss Room camera position matches the `phanCam_boss_room` node's world position and does not change during the fight. Pass: record `camera_2d.global_position` at fight start and at any point during combat. Positions must be equal (± 1 px rounding tolerance).

### Crash and Reset

**AC-19.** Scene reload during the boss death hold timer does not produce a "freed object" error. Setup: trigger `boss_defeated`, then reload the scene at `br_death_hold_duration × 0.5` seconds into the hold. Pass: Godot error log (Output panel) contains no "freed object" or "invalid get index" errors after reload. The `CameraController._exit_tree()` must complete without error.

**AC-20.** Player death in BOSS_ROOM or DIALOGUE mode resets camera state cleanly on scene reload. Setup: kill the player during a boss fight (boss still alive). Pass: after scene reload, `phanCam_boss_room.visible == false`, `phanCam_dialogue.visible == false`, `phanCam_exploration.visible == true`. No duplicate pcam nodes active. Verify via remote scene tree inspector immediately after reload.

## Open Questions

**OQ-01 — ~~Vertical look-ahead in boss rooms~~ [RESOLVED — N/A].**
Look-ahead is disabled in all camera modes (CR-EX-4). Boss Room is static (no follow, no look-ahead). This question is permanently closed.

**OQ-02 — Multiple simultaneous Combat Zones (overlapping rooms).**
CR-CB-8 forbids overlapping Combat Zone triggers as a level design error. If a specific layout requires it, the Zone/Room System would need to track zone stack depth. Currently out of scope.

**OQ-03 — ~~Cinematic camera mode~~ [RESOLVED].**
Pre-boss dialogue framing is addressed by DIALOGUE mode (CR-DL-1 through CR-DL-5, priority tier 25). Signal routing is resolved: the Narrative System listens to `boss_dialogue_started` and `boss_dialogue_complete` from the Boss System and drives Camera System dialogue activation directly. The Camera System's upstream dependency for dialogue is the Narrative System. No open questions remain on this topic.

**OQ-04 — Controller rumble as complement to camera shake.**
The Accessibility System may want to redirect shake events to controller rumble as an alternative to (or alongside) screen offset. Integration point not designed — the shake event pipeline would need a second dispatch path. Deferred to Accessibility System GDD.

**OQ-05 — Base scene pattern for pcam node authoring.**
30–50 room scenes × 3 pcam nodes (or 4 for boss rooms) = 90–200 manual property assignments. A Godot inherited base-room scene that pre-instantiates the pcam nodes with default configuration is strongly recommended before room count exceeds 10. Defer specifics to the engine-programmer implementing the Camera System, but the GDD author should approve the final scene structure before it becomes load-bearing.
