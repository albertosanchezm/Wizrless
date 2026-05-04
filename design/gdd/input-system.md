# Input System

> **Status**: In Design
> **Author**: albertosanchezm + agents
> **Last Updated**: 2026-04-17
> **Implements Pillar**: Foundation — enables Spell Alchemy, Earned Truth, Controlled Ascension

## Overview

The Input System is the single abstraction layer between hardware events (keyboard keys, gamepad buttons, analog sticks) and every other game system. All game systems — Movement, Spell System, Spell Slot, Dialogue, UI navigation — query named **actions** rather than raw device events. This means hardware can change (keyboard → gamepad → remapped gamepad) without touching any downstream system.

The system defines a **canonical action set** for Wizrless and maps each action to both a primary gamepad binding and a secondary keyboard/mouse binding. Gamepad is the primary input (per the game's primary-input decision); keyboard/mouse bindings exist for accessibility and player preference but receive no preferential treatment in UI labeling or tutorials.

Remapping is supported at the action level via InputMap at runtime. The Settings System (PL1) owns the UI for remapping; the Input System provides the underlying action store and persistence contract.

## Player Fantasy

The Input System has no player-facing fantasy of its own. Players engage with movement, spell casting, dialogue, and UI — all of which are powered by this system. The Input System succeeds when it is invisible: controls feel immediate, hardware differences disappear, and no player is locked out of an action because they are using a different device.

*Downstream systems that deliver the player fantasy this system enables:* Movement System (C1), Spell Slot System (FT1), Spell System (C3).

## Detailed Design

### Core Rules

**1. Action-Only Contract**
No game system reads raw hardware events. All systems call `Input.is_action_pressed()`, `is_action_just_pressed()`, or `is_action_just_released()` with a named action string. Raw `InputEvent` handling is restricted to the Input System's internal processing only.

**2. Canonical Action Set (21 actions, including 1 reserved)**

| Action | Signal Type | Default Gamepad | Default Keyboard | Consumer(s) |
|--------|-------------|----------------|-----------------|-------------|
| `move_left` | Digital (from analog) | Left Stick ← | A | Movement (C1) |
| `move_right` | Digital (from analog) | Left Stick → | D | Movement (C1) |
| `jump` | `just_pressed` + `is_pressed` | A / Cross | Space | Movement (C1) |
| `dash` | `just_pressed` | B / Circle | Shift | Movement (C1) |
| `cast` | `just_pressed` | RT / R2 | Left Mouse Button | Spell System (C3) |
| `cycle_spell_forward` | `just_pressed` | RB / R1 | E | Spell System (C3) |
| `cycle_spell_backward` | `just_pressed` | LB / L1 | Q | Spell System (C3) |
| `select_slot_1` | `just_pressed` | — | 1 | Spell Slot (FT1) |
| `select_slot_2` | `just_pressed` | — | 2 | Spell Slot (FT1) |
| `select_slot_3` | `just_pressed` | — | 3 | Spell Slot (FT1) |
| `select_slot_4` | `just_pressed` | — | 4 | Spell Slot (FT1) |
| `select_slot_5` | `just_pressed` | — | 5 | Spell Slot (FT1) |
| `interact` | `just_pressed` | X / Square | F | Ability Gates (FT10) |
| `ui_accept` | `just_pressed` | A / Cross | Enter | Dialogue (FT7), Menus |
| `ui_cancel` | `just_pressed` | B / Circle | Escape | Dialogue (FT7), Menus |
| `ui_up` | `just_pressed` + autorepeat | D-Pad Up / Left Stick ↑ | Arrow Up | All menus |
| `ui_down` | `just_pressed` + autorepeat | D-Pad Down / Left Stick ↓ | Arrow Down | All menus |
| `ui_left` | `just_pressed` + autorepeat | D-Pad Left / Left Stick ← | Arrow Left | All menus |
| `ui_right` | `just_pressed` + autorepeat | D-Pad Right / Left Stick → | Arrow Right | All menus |
| `pause` | `just_pressed` | Start / Options | Escape | Pause Menu |
| `cast_alt` | `just_pressed` | LT / L2 (unbound) | — (unbound) | Reserved — no consumer yet |
| `fullscreen_toggle` | `just_pressed` | — (unbound) | Alt+Enter | Settings (PL1) |

Notes:
- `select_slot_2` through `select_slot_5` are registered from launch. The Spell Slot System ignores input on locked slots; registration does not imply availability.
- `ui_accept` and `jump` share A/Cross. Context switching ensures only the correct action fires per context (see States and Transitions).
- `cast_alt` is registered with no binding. The Spell System (C3) GDD will claim it when charged-cast or secondary-cast is designed.

**3. Analog Handling — Left Stick**

The Input System reads the left stick as a continuous vector. It does NOT produce pre-snapped digital output — the Movement System (C1) decides how to interpret the values.

**Radial deadzone (applied before any consumer reads the stick):**

`v_out = (v_raw / |v_raw|) × ((|v_raw| − D) / (1 − D))` when `|v_raw| > D`, else `v_out = (0, 0)`

Where `D = 0.20` (default; tuning knob). Output `v_out` magnitude is always in [0.0, 1.0] — rescaling after the deadzone removal restores full-range reach.

**Example**: `v_raw = (0.30, 0.10)`, `|v_raw| = 0.316`, D = 0.20. Post-deadzone scale = (0.316 − 0.20) / (1 − 0.20) = 0.145. Direction = (0.949, 0.316). `v_out = (0.138, 0.046)`.

**Exception — UI context**: When the `ui` context is active, left stick deflection above `0.60` fires `ui_up/down/left/right` as digital events. Autorepeat: first fire on threshold cross, then 10 Hz after 400 ms hold. This behavior is active only in the `ui` context.

**Analog triggers**: `cast` action deadzone = `0.15`. Godot's InputMap action system handles threshold conversion; no special code required.

### States and Transitions

**Three input contexts managed by `InputContextManager` (Autoload singleton):**

| Context | Active When | Allowed Actions |
|---------|-------------|----------------|
| `gameplay` | Player controls the wizard | All gameplay actions + `pause` |
| `dialogue` | A dialogue sequence is playing | `ui_accept`, `ui_cancel`, `pause` |
| `ui` | Any menu is open | All `ui_*` + `pause` |

`InputContextManager` maintains a stack. `gameplay` is always the bottom frame and is never popped. Pushing a context disables all out-of-context actions by caching and erasing their `InputMap` bindings. Popping restores cached bindings. Maximum stack depth: 3. Exceeding depth 3 is rejected with an error log.

**Context transitions:**
- Dialogue starts → push `dialogue`
- Dialogue ends → pop `dialogue`
- Pause menu opens (from gameplay) → push `ui`
- Pause menu opens (during dialogue) → push `ui` on top of `dialogue`
- Pause menu closes → pop `ui` (restores whatever was below — either `gameplay` or `dialogue`)

This is an architecture pattern — implementation details (class structure, signals) belong in the Input System ADR.

### Interactions with Other Systems

| System | Interface | Direction | Notes |
|--------|-----------|-----------|-------|
| Movement (C1) | Reads `move_left`, `move_right`, `jump`, `dash`; reads stick vector via `Input.get_vector()` | Input → Movement | Movement decides snapping/directional handling |
| Spell System (C3) | Reads `cast`, `cycle_spell_forward`, `cycle_spell_backward`; `cast_alt` when a mechanic claims it | Input → Spell | Input provides the trigger; Spell System owns cooldown/state |
| Spell Slot System (FT1) | Reads `select_slot_1..5`, `cycle_spell_forward`, `cycle_spell_backward` | Input → Spell Slot | Slot System ignores input on locked slots |
| Dialogue System (FT7) | Reads `ui_accept`, `ui_cancel`; calls `InputContextManager.push/pop_context()` | Bidirectional | Dialogue owns its own push/pop lifecycle |
| Ability Gate System (FT10) | Reads `interact` | Input → Gate | |
| Settings / Pause Menu (PL1, P7) | Reads all `ui_*`; calls `InputContextManager.push_context("ui")`; writes to `InputMap` during remapping | Bidirectional | Settings owns the remapping UI; Input owns the action store |

**4. Remapping Constraints**

**Hard-locked (excluded from remapping UI):**
- `pause` — if unbound, player cannot access settings to fix it
- All `ui_*` actions — remapping UI requires these to function during the remapping session
- `fullscreen_toggle` Alt+Enter — PC OS-level standard

**Soft-locked (must always have at least one binding):**
- `jump`, `cast`, `interact` — these can be unbound to any hardware, but unbinding the last binding is rejected. Message: *"This action requires at least one input. Assign a new binding before removing the current one."*

**Protected keyboard fallbacks (read-only slot in remapping UI, binding slot 1):**
- `pause` → Escape
- `ui_accept` → Enter
- `ui_cancel` → Escape
- `cast` → Left Mouse Button

Player's remappable binding uses slot 0. Protected fallback is slot 1, not shown as editable.

**Cross-context conflict rule**: Same hardware event assigned to two actions in the same context → blocked. Same event in different contexts → permitted. The context stack ensures only the correct action fires. Exception: `pause` is global and cannot share any hardware event.

## Formulas

### Radial Deadzone Formula

The radial deadzone formula is defined as:

`v_out = (v_raw / |v_raw|) × ((|v_raw| − D) / (1 − D))` when `|v_raw| > D`, else `v_out = (0, 0)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Raw stick vector | `v_raw` | vec2 | (−1.0, −1.0) to (1.0, 1.0) | Direct hardware output from `Input.get_vector()` |
| Deadzone radius | `D` | float | 0.0–1.0 (default: 0.20) | Radius of the dead center zone; tuning knob `input_deadzone` |
| Stick magnitude | `\|v_raw\|` | float | 0.0–1.414 | Euclidean magnitude of `v_raw` |
| Processed output | `v_out` | vec2 | (0,0) or unit-direction × [0,1] | Rescaled clean vector delivered to consumers |

**Output Range**: `v_out` magnitude is 0.0 (inside deadzone) to 1.0 (full deflection). The rescaling step `((|v_raw| − D) / (1 − D))` ensures full deflection is always reachable — the player does not need to push past the deadzone offset to get maximum output.

**Example**: `v_raw = (0.30, 0.10)`, `|v_raw| = 0.316`, D = 0.20. Scale = (0.316 − 0.20) / (1 − 0.20) = 0.145. Direction = (0.949, 0.316). `v_out = (0.138, 0.046)`.

**Edge case at center**: If `|v_raw| < 0.001`, return `(0, 0)` directly — guards against division by zero.

---

### UI Stick Threshold (constant)

Left stick fires `ui_direction` actions when the dominant axis exceeds `UI_STICK_THRESHOLD`. Default: `0.60`. This threshold applies only in the `ui` context. It is a separate value from `input_deadzone` and is independently tunable.

---

*No other formulas. The Input System is a pure event-routing layer; all numeric logic belongs to consuming systems.*

## Edge Cases

- **If `v_raw` magnitude < 0.001 (stick at rest or noise)**: Return `v_out = (0, 0)` directly, skipping the formula. Guards against division by zero.

- **If `|v_raw|` ≤ D (inside deadzone)**: Return `v_out = (0, 0)`. Movement System receives no stick input. Expected during idle or minor controller drift.

- **If a gamepad is disconnected mid-gameplay**: All gamepad actions immediately report `is_action_pressed() = false`. The wizard stops moving. The Input System emits `Input.joy_connection_changed`; the Settings/Pause system is responsible for detecting it and surfacing a reconnect prompt. The Input System does not pause the game automatically.

- **If two controllers are connected**: Input System reads device ID `0` by default. Multi-device assignment is a Settings (PL1) concern. All actions poll device `0` unless Settings explicitly reassigns.

- **If `InputContextManager.push_context()` is called with the context already at the top**: Push proceeds normally. The same context name can stack (e.g., nested dialogue triggers). Each push requires a matching pop.

- **If `InputContextManager.pop_context()` is called when only `gameplay` remains**: No-op; log an error. `gameplay` is never popped. This is a programming error, not a player-accessible case.

- **If `select_slot_N` fires for a locked slot**: The Spell Slot System (FT1) ignores the action. The Input System delivers the event normally — suppression is the Spell Slot System's responsibility, not the Input System's.

- **If the player attempts to unbind the last binding from a soft-locked action**: Settings System rejects the save. Message: *"This action requires at least one input. Assign a new binding before removing the current one."* The InputMap binding is unchanged.

- **If `pause` fires during a context push/pop**: `pause` is global and not suppressible. Context push/pop operations must complete atomically within a single `_input()` call to prevent partial-state race conditions. Mid-frame partial context state is an implementation responsibility.

- **If keyboard and gamepad trigger the same action simultaneously**: Godot sets `is_action_just_pressed()` to true for that frame regardless of device. The action fires once. Consumer systems read the action flag, not individual hardware events — no double-fire occurs.

## Dependencies

**Upstream dependencies (systems this one requires):** None. The Input System is a Foundation layer system with no dependencies.

**Downstream dependents (systems that depend on this one):**

| System | What It Gets From Input | Hard or Soft |
|--------|------------------------|-------------|
| Movement System (C1) | `move_left`, `move_right`, `jump`, `dash`; left stick `v_out` vector | Hard |
| Spell System (C3) | `cast`, `cycle_spell_forward`, `cycle_spell_backward`, `cast_alt` (reserved) | Hard |
| Spell Slot System (FT1) | `select_slot_1..5`, `cycle_spell_forward`, `cycle_spell_backward` | Hard |
| Dialogue System (FT7) | `ui_accept`, `ui_cancel`; `InputContextManager.push/pop_context()` | Hard |
| Ability Gate System (FT10) | `interact` | Hard |
| Settings System (PL1) | All `ui_*` actions; `InputMap` write access for remapping; `input_deadzone` tuning knob | Hard |
| Pause Menu (P7) | All `ui_*` actions; `InputContextManager.push_context("ui")` | Hard |

**Interface contract**: All downstream systems access the Input System through Godot's `Input` singleton and `InputContextManager`. Only the Settings System has direct `InputMap` write access (for remapping).

## Tuning Knobs

| Knob | Default | Safe Range | Breaks if Too Low | Breaks if Too High |
|------|---------|------------|------------------|-------------------|
| `input_deadzone` | 0.20 | 0.05–0.40 | Controller drift causes unintended movement/casting | Stick requires large deflection to register; feels unresponsive |
| `ui_stick_threshold` | 0.60 | 0.40–0.85 | Menu navigation fires from minor stick deflection (accidental inputs) | Player must push stick far to navigate menus; tedious on long lists |
| `ui_autorepeat_initial_delay_ms` | 400 ms | 200–700 ms | Rapid-fire on first hold; accidental scrolling | Long pause before repeat starts; slow menu navigation |
| `ui_autorepeat_rate_hz` | 10 Hz | 6–20 Hz | Slow scrolling for long lists | Too-fast scrolling makes precise selection difficult |

**Interaction constraint**: `ui_stick_threshold` must always be > `input_deadzone`. If `ui_stick_threshold ≤ input_deadzone`, clamp at runtime to `input_deadzone + 0.05`. The stick cannot trigger UI actions if the value is already zeroed by the deadzone.

## Acceptance Criteria

- **AC-INP-001** — GIVEN any consuming system (Movement, Spells, UI), WHEN it polls for input, THEN it calls only named-action methods. Verified by static grep: zero calls to `Input.get_joy_axis()`, `is_joy_button_pressed()`, `is_key_pressed()`, or `is_mouse_button_pressed()` outside the Input System's own files.

- **AC-INP-002** — GIVEN the game starts, WHEN `InputMap` initializes, THEN `InputMap.get_actions()` returns exactly 21 named actions from the canonical set including `cast_alt` (unbound) and `fullscreen_toggle`.

- **AC-INP-003** — GIVEN D = 0.20, WHEN `v_raw` has magnitude ≤ 0.20, THEN `v_out = (0, 0)`.

- **AC-INP-004** — GIVEN D = 0.20, WHEN `v_raw = (0.30, 0.10)`, THEN `v_out ≈ (0.138, 0.046)` within ±0.001 tolerance.

- **AC-INP-005** — GIVEN D = 0.20, WHEN `v_raw = (1.0, 0.0)`, THEN `v_out.length() ≈ 1.0` within ±0.001.

- **AC-INP-006** — GIVEN `v_raw` magnitude < 0.001, WHEN the deadzone formula processes it, THEN `v_out = (0, 0)` and no division-by-zero error or NaN is produced.

- **AC-INP-007** — GIVEN `gameplay` is the base context, WHEN `dialogue` is pushed, THEN `InputMap.action_has_event("move_left")` returns false; `ui_accept`, `ui_cancel`, and `pause` remain active.

- **AC-INP-008** — GIVEN stack is `[gameplay, dialogue]`, WHEN `pop_context()` is called, THEN all gameplay action bindings are restored and `move_left` fires normally on the next poll.

- **AC-INP-009** — GIVEN only `gameplay` remains on the stack, WHEN `pop_context()` is called, THEN stack depth remains 1 and an error log entry is emitted.

- **AC-INP-010** — GIVEN 3 contexts are stacked, WHEN a 4th `push_context()` is called, THEN stack depth remains 3 and an error log entry is emitted.

- **AC-INP-011** — GIVEN `jump`, `cast`, or `interact` has exactly 1 binding, WHEN the player attempts to remove it via the Settings remapping UI, THEN the binding remains in `InputMap` and the message *"This action requires at least one input. Assign a new binding before removing the current one."* is displayed (exact text match required).

- **AC-INP-012** — GIVEN the Settings remapping screen is open, WHEN the player browses the remappable action list, THEN `pause`, all `ui_*` actions, and `fullscreen_toggle` are absent as editable entries; protected keyboard fallback slots are visible but non-interactive.

- **AC-INP-013** — GIVEN A/Cross is bound to both `ui_accept` (ui context) and `jump` (gameplay context), WHEN A/Cross is pressed in `ui` context, THEN `ui_accept` fires and `jump` does not. WHEN pressed in `gameplay` context, THEN `jump` fires and `ui_accept` does not.

- **AC-INP-014** — GIVEN `gameplay` context is active, WHEN the player attempts to bind a hardware event already used by another active `gameplay` action, THEN the assignment is blocked and a conflict warning is displayed.

- **AC-INP-015** — GIVEN `ui` context active and `ui_stick_threshold = 0.60`, WHEN left stick is held at magnitude 0.65 for 500 ms, THEN `ui_down` fires once on initial threshold cross, then fires at ~10 Hz after 400 ms hold (pass: 6 fires in the 600 ms window after initial delay, ±1 tolerance).

- **AC-INP-016** — GIVEN `input_deadzone = 0.30`, WHEN `ui_stick_threshold` is set to 0.30 or below, THEN the system clamps it to 0.35 and UI navigation continues to function.

- **AC-INP-017** — GIVEN a gamepad is the active device during gameplay, WHEN it is disconnected, THEN all gamepad-bound actions return false on the next poll, the wizard stops all movement, `Input.joy_connection_changed` fires within 1 frame, and no crash occurs.

## Open Questions

1. **InputContextManager implementation pattern** — The GDD specifies a singleton that rewrites `InputMap` bindings on context push/pop. An alternative is relying on scene-tree `_unhandled_input()` ordering. This is an architecture decision. → **Becomes an ADR**. Owner: Technical Director. Resolve before the first system that calls `push_context()` is implemented.

2. **Input latency ceiling** — The Overview states "controls feel immediate" but no frame-latency benchmark is specified. At 60 fps, "1 frame" = 16.6 ms. A criterion stating `just_pressed` fires ≤1 frame after physical input should be added before the story enters implementation. Owner: QA Lead to define the measurement method.

3. **`cast_alt` future claim** — Left Trigger is reserved as `cast_alt` with no binding. When the Spell System GDD (C3) is authored, the Spell System owns the decision of whether to claim this action and what mechanic it activates. If no mechanic uses it by Vertical Slice, remove the registration.
