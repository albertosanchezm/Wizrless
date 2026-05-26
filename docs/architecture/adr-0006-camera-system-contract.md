# ADR-0006: Camera System Contract (PhantomCamera 2D)

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Foundation (Camera) |
| **Knowledge Risk** | HIGH — PhantomCamera 2D addon; post-LLM-cutoff API |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `design/gdd/camera-system.md` |
| **Post-Cutoff APIs Used** | `PhantomCamera2D.set_priority()`, `pcam.limit_target` (NodePath), `NoiseEmitter2D.emit()` — all addon APIs. `Tween.kill()` for EC-10 cleanup — confirm method name in 4.6 docs. |
| **Verification Required** | (1) Confirm `PhantomCamera2D.set_priority(-1)` is clamped to 0 in installed addon version — deactivation must use `visible = false` not `set_priority(-1)`. (2) Confirm `limit_target` accepts a `NodePath` string, not a node reference. (3) Confirm `NoiseEmitter2D.stop()` method name before implementing shake stacking. (4) Verify `Tween.kill()` signature in Godot 4.6. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload — PhantomCameraManager is autoload #1), ADR-0002 (GameManager signals: boss_defeated, boss_appeared), ADR-0007 (Health System signals: player_damaged, player_died for camera shake and T-11) |
| **Enables** | ADR-0012 (Zone/Room System — pushes limit_target, activates Combat camera) |
| **Blocks** | No room scene may be authored without following the pcam activation/deactivation rules in this ADR |

## Context

Camera behavior is fully specified in the GDD but the architectural contract — which system calls what, deactivation mechanism, shake stacking math — requires an ADR to prevent implementation divergence across 30+ room scenes.

## Decision

Camera System is implemented as a `CameraController` node (not an autoload) in each room scene. Four `PhantomCamera2D` nodes exist per room: `phanCam_exploration` (priority 0), `phanCam_combat` (priority 10), `phanCam_boss_room` (priority 20, boss rooms only), `phanCam_dialogue` (priority 25, boss rooms only). `PhantomCameraManager` (autoload #1) selects the active pcam by priority.

### Priority Tiers and Deactivation Rule

| Mode | Priority | Follow | Shake |
|------|----------|--------|-------|
| EXPLORATION | 0 | Player pos, framed damped | On |
| COMBAT | 10 | Player pos, tighter damped | On |
| BOSS_ROOM | 20 | None (static at arena anchor) | On |
| DIALOGUE | 25 | None (static at designer pos) | On |

**Deactivation rule**: Set `pcam_node.visible = false`. **Never** call `set_priority(-1)` — PhantomCamera clamps to 0, colliding with EXPLORATION priority. Activation: `pcam_node.visible = true` + `set_priority(N)`.

Minimum priority separation: 5. No two visible pcam nodes may share the same priority simultaneously.

### Camera Mode Activation Owners

| Trigger | Activating System | Method |
|---------|------------------|--------|
| Enter Combat Zone Area2D | Zone/Room System | `phanCam_combat.visible = true; phanCam_combat.set_priority(10)` |
| All enemies defeated + delay | Zone/Room System | `phanCam_combat.visible = false` |
| Enter Boss Room Area2D | Zone/Room System | `phanCam_boss_room.visible = true; phanCam_boss_room.set_priority(20)` |
| `boss_defeated` signal | CameraController | Hold `br_death_hold_duration` → blend out → `phanCam_boss_room.visible = false` |
| `boss_dialogue_started` | Narrative System | `phanCam_dialogue.visible = true; phanCam_dialogue.set_priority(25)` |
| `boss_dialogue_complete` | Narrative System | `phanCam_dialogue.visible = false` |

### Room Boundaries

Zone/Room System must assign `limit_target` to Exploration and Combat pcams **before** the player crosses a room threshold:

```gdscript
pcam.limit_target = pcam.get_path_to(collision_shape_node)  # NodePath, not node ref
```

Resizing a `Shape2D` at runtime does not update limits — Zone/Room must re-assign `limit_target` if geometry changes.

### Camera Shake Architecture

Two `NoiseEmitter2D` nodes on `CameraController`:
- `shake_emitter_damage` — triggered by Health System `player_damaged`
- `shake_emitter_impact` — triggered by Spell System `heavy_impact_resolved`

Both nodes operate independently (simultaneous allowed). Shake stacking rule: **replace-if-higher** within each channel.

```gdscript
# Stacking decision per emitter channel:
# 1. Apply F-2 intensity gate (discard < shake_min, cap at shake_max)
# 2. If new_intensity > M(elapsed_t_now):  stop current, emit new, reset elapsed_t
# 3. Else: discard
```

Shadow timer `elapsed_t` per emitter, incremented in `_process(delta)`, reset on each `emit()` call.

Shake globally suppressible: `camera_shake_enabled: bool`. When false, block all `emit()` calls.

No rotational shake (`rotational_noise = false` on both noise resources).

### Shake Magnitude Formula (F-1)

Three-phase envelope (growth → sustain → decay):

```
M(t) = intensity × trauma²

# trauma:
t < growth_time:                  trauma = t / growth_time         (guard: growth_time > 0)
t < growth_time + duration:       trauma = 1.0
t < growth_time + duration + dt:  trauma = 1.0 - (t - g - d) / dt  (guard: dt > 0)
else:                              trauma = 0.0
```

### Boss Death Hold Sequence

On `boss_defeated` from GameManager:
1. Stop all active tweens; record `camera_2d.global_position`
2. Start `br_death_hold_duration` timer (default 3.0 s)
3. On timer end: blend to lower-priority camera over `br_death_blend_duration`, `TRANS_SINE + EASE_OUT`
4. On blend complete: `phanCam_boss_room.visible = false`

`CameraController._exit_tree()` must call `tween.kill()` and `timer.stop()` to prevent "freed object" errors if scene reloads during hold (EC-10).

### Architecture Diagram

```
project.godot [autoload]
  └── PhantomCameraManager (addon, #1) — selects highest-priority visible pcam

Room scene tree:
  ├── CameraController (node — owns shake logic + boss death hold)
  │   ├── phanCam_exploration (priority 0, always visible)
  │   ├── phanCam_combat (priority 10, visible = false initially)
  │   ├── phanCam_boss_room (priority 20, boss rooms only)
  │   ├── phanCam_dialogue (priority 25, boss rooms only)
  │   ├── shake_emitter_damage (NoiseEmitter2D)
  │   └── shake_emitter_impact (NoiseEmitter2D)
  └── Camera2D (owned by PhantomCameraManager)

Zone/Room System → pcam visibility + priority + limit_target
Health System   → shake_emitter_damage.emit() via player_damaged signal
Spell System    → shake_emitter_impact.emit() via heavy_impact_resolved signal
Narrative System → phanCam_dialogue visibility
GameManager     → boss_defeated → boss death hold sequence
```

## Alternatives Considered

### Alternative: CameraController as Autoload

Single global camera controller persisting across scene transitions.

- **Pros**: No re-setup per room.
- **Cons**: Pcam nodes must be re-pointed to new room's player and collision shapes on every scene transition. Each room has its own boundary geometry — a scene-local approach is simpler.
- **Rejected**: Scene-local controller is idiomatic Godot. PhantomCameraManager (autoload #1) already provides cross-scene persistence at the addon level.

## Consequences

### Positive
- Deactivation rule is singular (visible = false) — eliminates the documented CR-CB-1 footgun
- Shake is independent of camera mode — works in all four modes without mode-specific code
- Boss death hold is implemented once in CameraController, not per boss

### Negative
- 30–50 room scenes each need the same pcam node setup (OQ-05 recommends base scene template)
- PhantomCamera addon is a hard dependency — API break requires re-architecture
- `Tween.kill()` and timer cleanup in `_exit_tree()` is easy to forget — must be in implementation checklist

### Risks

- **Priority collision**: Two combat zones activate simultaneously → `set_priority(10)` called twice → no-op on second, but enemy tracking is ambiguous. Mitigation: CR-CB-8 forbids overlapping zones; add debug assertion.
- **limit_target NodePath after scene restructure**: If the CollisionShape2D node is moved in the scene tree, the cached NodePath breaks silently. Mitigation: Zone/Room System re-assigns `limit_target` on every room entry, not just once at startup.

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-camera-001 | camera-system.md | PhantomCamera2D priority-based mode selection | Priority Tiers and Deactivation Rule section |
| TR-camera-002 | camera-system.md | Deactivation via visible = false, never set_priority(-1) | Deactivation rule; Verification Required item #1 |
| TR-camera-003 | camera-system.md | Four camera modes with defined priorities | Priority Tiers table |
| TR-camera-004 | camera-system.md | limit_target NodePath assigned by Zone/Room System | Room Boundaries section |
| TR-camera-005 | camera-system.md | Damage Shake + Impact Shake as separate NoiseEmitter2D nodes | Camera Shake Architecture section |
| TR-camera-006 | camera-system.md | Replace-if-higher shake stacking with shadow timer | Stacking decision algorithm |
| TR-camera-007 | camera-system.md | Boss death hold 3.0s + TRANS_SINE EASE_OUT blend out | Boss Death Hold Sequence section |
| TR-camera-008 | camera-system.md | CameraController._exit_tree() kills tween + timer | EC-10 handling in Boss Death Hold Sequence |
| TR-camera-009 | camera-system.md | camera_shake_enabled accessibility toggle | Shake suppressible via boolean |
| TR-camera-010 | camera-system.md | No rotational shake (rotational_noise = false) | shake Architecture section note |

## Performance Implications

- **CPU**: Shadow timer increment in `_process(delta)` — 2 float increments/frame. Negligible.
- **CPU**: Shake stacking check on shake event only (rare). Negligible.
- **PhantomCamera addon**: Priority selection is O(pcam count) on priority change, not per frame. Negligible.

## Validation Criteria

- AC-01: Combat camera activates within `transition_ex_to_cb + 50ms` of `body_entered`
- AC-02: Combat camera deactivates `transition_combat_clear_delay ± 50ms` after last enemy dies
- AC-05: No two visible pcams share same priority simultaneously
- AC-09: `phanCam_exploration.zoom == phanCam_combat.zoom` asserted in `_ready()`
- AC-12: `camera_shake_enabled = false` blocks new shake; existing shake completes
- AC-19: Scene reload during boss hold produces no freed object errors

## Related Decisions

- ADR-0001: PhantomCameraManager is autoload #1
- ADR-0002: GameManager.boss_defeated signal drives boss death hold
- ADR-0008: Health System — player_damaged drives Damage Shake
- ADR-0012: Zone/Room System — activates combat camera + pushes limit_target
- `design/gdd/camera-system.md` — full GDD, all TR-camera-* requirements
