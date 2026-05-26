# ADR-0003: Input System and InputContextManager Contract

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Foundation (Input) |
| **Knowledge Risk** | LOW — InputMap and Input singleton API stable since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `design/gdd/input-system.md` |
| **Post-Cutoff APIs Used** | None — `Input.is_action_pressed()`, `InputMap.action_add_event()`, `InputMap.action_erase_events()` unchanged since 4.0 |
| **Verification Required** | (1) Confirm `InputMap.action_erase_events(action)` + `InputMap.action_add_event(action, event)` is the correct pair for cache-and-restore context switching in 4.6. (2) Confirm `Input.get_vector()` deadzone parameter is ignored when we apply our own deadzone — use `Input.get_vector("move_left", "move_right", "move_down", "move_up", 0.0)` to get raw values. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload Singleton Architecture — `InputContextManager` is a new autoload not yet in ADR-0001 roster; add as slot #11 after SpellVFXSpawner) |
| **Enables** | ADR-0009 (Movement System — reads `move_left/right/jump/dash` + stick vector), ADR-0010 (Spell System — reads `cast/cycle_*`), ADR-0013 (Spell Slot System — reads `select_slot_1..5`), ADR-0017 (Dialogue System — uses context push/pop) |
| **Blocks** | No story implementing player input may start until this ADR is Accepted and the canonical action set is registered in `project.godot` |
| **Ordering Note** | `InputContextManager` must load after all autoloads whose signals it might receive but before any scene that uses `push_context()`. Add to ADR-0001 roster as slot #11. |

## Context

### Problem Statement

The input GDD specifies a 21-action canonical set, a radial deadzone formula, and a context-stack mechanism (`InputContextManager`). None of these have an architectural contract. Without this ADR:

- Stories register their own actions ad hoc, producing action name collisions
- Consuming systems read raw device events instead of named actions (AC-INP-001 violation)
- `InputContextManager` is re-invented per system with incompatible context names

### Constraints

- Godot `Input` singleton is global — actions are registered project-wide in `InputMap`
- Four autoloads already registered; `InputContextManager` must be added as a new autoload (see ADR-0001 amendment note)
- Context stack must survive scene transitions — autoload is the only viable host
- `cast_alt` is registered unbound — do not remove; Spell System will claim it later

## Decision

The project defines **21 canonical input actions** in `InputMap`. All consuming systems read only named-action methods. Raw hardware event calls (`get_joy_axis`, `is_key_pressed`, etc.) are forbidden outside `InputContextManager`.

### Canonical Action Set (21 actions)

| Action | Gamepad Default | Keyboard Default | Context | Consumer |
|--------|----------------|-----------------|---------|---------|
| `move_left` | Left Stick ← | A | gameplay | Movement |
| `move_right` | Left Stick → | D | gameplay | Movement |
| `jump` | A/Cross | Space | gameplay | Movement |
| `dash` | B/Circle | Shift | gameplay | Movement |
| `cast` | RT/R2 | LMB | gameplay | Spell System |
| `cycle_spell_forward` | RB/R1 | E | gameplay | Spell System |
| `cycle_spell_backward` | LB/L1 | Q | gameplay | Spell System |
| `select_slot_1..5` | — | 1-5 | gameplay | Spell Slot |
| `interact` | X/Square | F | gameplay | Ability Gates |
| `ui_accept` | A/Cross | Enter | ui/dialogue | Dialogue, Menus |
| `ui_cancel` | B/Circle | Escape | ui/dialogue | Dialogue, Menus |
| `ui_up/down/left/right` | D-Pad/Stick | Arrow Keys | ui | All menus |
| `pause` | Start | Escape | global | Pause Menu |
| `cast_alt` | LT/L2 | — (unbound) | gameplay | Reserved |
| `fullscreen_toggle` | — | Alt+Enter | global | Settings |

`select_slot_2..5` registered from launch; Spell Slot System ignores locked slots.
`cast_alt` registered with no binding — Spell System claims when needed.

### Radial Deadzone Contract

Applied by `InputContextManager` before exposing stick vectors. All consumers call `InputContextManager.get_stick_vector() -> Vector2` — never `Input.get_vector()` with a deadzone.

```gdscript
const DEADZONE: float = 0.20  # tuning knob: input_deadzone

static func apply_radial_deadzone(v_raw: Vector2, d: float) -> Vector2:
    var mag := v_raw.length()
    if mag < 0.001:
        return Vector2.ZERO
    if mag <= d:
        return Vector2.ZERO
    return (v_raw / mag) * ((mag - d) / (1.0 - d))
```

Output magnitude always in [0.0, 1.0]. Full deflection reachable.

### InputContextManager — Context Stack

```gdscript
# InputContextManager.gd (Autoload #11)

enum Context { GAMEPLAY, DIALOGUE, UI }

# Push a context. Caches and erases bindings not allowed in the new context.
func push_context(ctx: Context) -> void

# Pop the top context. Restores cached bindings. Error-log if only GAMEPLAY remains.
func pop_context() -> void

# Returns the current top-of-stack context.
func current_context() -> Context

# Returns processed stick vector with deadzone applied.
func get_stick_vector() -> Vector2
```

Stack rules:
- `GAMEPLAY` is always the bottom frame — never popped
- Max depth: 3. `push_context()` at depth 3 is a no-op + error log
- `pop_context()` at depth 1 (only GAMEPLAY) is a no-op + error log
- On push: cache the erased bindings per action, call `InputMap.action_erase_events()`
- On pop: call `InputMap.action_add_event()` to restore each cached binding

### Allowed Context Per Action

| Context active | Actions enabled |
|----------------|----------------|
| GAMEPLAY (base) | All gameplay + `pause` + `fullscreen_toggle` |
| DIALOGUE (on top of GAMEPLAY) | `ui_accept`, `ui_cancel`, `pause` |
| UI (on top of anything) | All `ui_*` + `pause` + `fullscreen_toggle` |

`pause` and `fullscreen_toggle` are global — never suppressed.

### UI Stick Threshold (UI context only)

```gdscript
const UI_STICK_THRESHOLD: float = 0.60   # tuning knob; must be > DEADZONE
const UI_AUTOREPEAT_INITIAL_MS: int = 400
const UI_AUTOREPEAT_RATE_HZ: float = 10.0

# In _process(), when Context == UI:
# left stick magnitude > UI_STICK_THRESHOLD → fire corresponding ui_* action
# with autorepeat: first fire on threshold cross, then at UI_AUTOREPEAT_RATE_HZ
# after UI_AUTOREPEAT_INITIAL_MS hold.
```

Guard: if `UI_STICK_THRESHOLD <= DEADZONE`, clamp to `DEADZONE + 0.05`.

### Remapping Rules

**Hard-locked** (excluded from settings remapping UI):
- `pause`, all `ui_*` actions, `fullscreen_toggle`

**Soft-locked** (minimum 1 binding; last binding removal blocked):
- `jump`, `cast`, `interact`

**Protected fallback slots** (slot 1, read-only):
- `pause` → Escape, `ui_accept` → Enter, `ui_cancel` → Escape, `cast` → LMB

Cross-context binding conflict: same hardware event in same context is blocked. Same event in different contexts permitted (A/Cross handles both `jump`/gameplay and `ui_accept`/ui).

### Architecture Diagram

```
Hardware (gamepad / keyboard)
  └── InputContextManager (Autoload #11)
        ├── Maintains context stack [GAMEPLAY, ...]
        ├── Manages InputMap binding cache per push/pop
        ├── Exposes get_stick_vector() with radial deadzone
        └── Processes UI stick threshold in _process()

Consumers:
  MovementSystem      → Input.is_action_pressed("move_left/right/jump/dash")
                        InputContextManager.get_stick_vector()
  SpellSystem         → Input.is_action_just_pressed("cast/cycle_*")
  SpellSlotSystem     → Input.is_action_just_pressed("select_slot_N")
  DialogueSystem      → Input.is_action_just_pressed("ui_accept/cancel")
                        InputContextManager.push_context(DIALOGUE) / pop_context()
  PauseMenu           → Input.is_action_just_pressed("pause")
                        InputContextManager.push_context(UI) / pop_context()
  SettingsSystem      → InputMap write access (remapping) + get_stick_vector()
```

## Alternatives Considered

### Alternative A: _unhandled_input() Context Priority via Scene Tree

Context switching via scene tree `_unhandled_input()` propagation order — child nodes consume input, preventing it from reaching parent nodes.

- **Pros**: No InputMap mutation; no caching needed.
- **Cons**: Requires careful scene hierarchy design; dialogue and UI scenes must be children of the tree's top; context changes happen at frame boundary, not at signal. Cannot suppress a global action like `pause`.
- **Rejected**: GDD specifies an explicit context stack with binding suppression. Scene-tree ordering is fragile across future scene restructuring.

### Alternative B: Per-System Input Checks in _process()

Each system polls only in its own state (dialogue system ignores movement actions in its _process).

- **Pros**: Zero runtime InputMap mutation.
- **Cons**: Multiple systems must each implement "am I allowed to read input right now?" logic. No single source of truth. Race conditions if two systems both check in the same frame.
- **Rejected**: No single authoritative context source. Violates the "context stack" design in the GDD.

## Consequences

### Positive
- Single authority for context state — all systems call `InputContextManager.push/pop_context()`
- Deadzone applied once, not per consumer
- Remapping constraints codified — Settings System cannot break locked actions

### Negative
- `InputContextManager` adds a new autoload (ADR-0001 must be updated to add slot #11)
- InputMap mutation during context switch is a Godot-level side effect — must be verified after any engine upgrade
- Context stack depth 3 is a hard limit — if a future system needs depth 4, this ADR must be revisited

### Risks

- **InputMap mutation timing**: If `push_context()` fires mid-frame, a system that already polled `is_action_pressed()` this frame will have seen the old binding. Mitigation: context pushes should happen at the start of a frame (in `_process()` before other systems, or via signal emitted on the previous frame).
- **Dialogue System double-push**: Dialogue System calls `push_context(DIALOGUE)` on start and `pop_context()` on end. If a dialogue script error prevents the pop, gameplay context is permanently suppressed. Mitigation: `InputContextManager` exposes an `emergency_reset()` that clears the stack to GAMEPLAY only — call from the crash handler or a debug key.

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-input-001 | input-system.md | 21-action canonical set in InputMap | Canonical Action Set table above; registered in project.godot |
| TR-input-002 | input-system.md | Context stack routes input to gameplay/dialogue/ui | InputContextManager context stack contract |
| TR-input-003 | input-system.md | Radial deadzone (0.20) on analog stick | `apply_radial_deadzone()` formula; `InputContextManager.get_stick_vector()` |
| TR-input-004 | input-system.md | `ui_stick_threshold` (0.60) for UI navigation | UI Stick Threshold section |
| TR-input-005 | input-system.md | Both keyboard/mouse and gamepad bindings per action | Canonical Action Set table (both columns) |

## Performance Implications

- **CPU**: InputMap mutation (push/pop) is a rare event (dialogue/menu open/close). No per-frame overhead.
- **CPU**: Deadzone applied once per frame when `get_stick_vector()` called — negligible.
- **Memory**: Context stack array (max 3 elements) + cached bindings per action — negligible.

## Validation Criteria

- AC-INP-001: zero `get_joy_axis()` / `is_key_pressed()` calls outside `InputContextManager`
- AC-INP-002: `InputMap.get_actions()` returns exactly 21 actions on launch
- AC-INP-003/004/005/006: radial deadzone formula verified by unit tests
- AC-INP-007/008: push/pop context restores bindings correctly
- AC-INP-009/010: stack depth guards fire on overflow/underflow
- AC-INP-013: A/Cross context-split (jump in gameplay, ui_accept in ui)
- AC-INP-016: `ui_stick_threshold` clamp fires when ≤ `input_deadzone`

## Related Decisions

- ADR-0001: Autoload Singleton Architecture — add `InputContextManager` as slot #11
- ADR-0009: Movement System — primary consumer of stick vector and movement actions
- ADR-0010: Spell System — consumer of cast/cycle actions
- ADR-0013: Spell Slot System — consumer of select_slot actions
- ADR-0017: Dialogue System — consumer of context push/pop
- `design/gdd/input-system.md` — full GDD, all TR-input-* requirements
