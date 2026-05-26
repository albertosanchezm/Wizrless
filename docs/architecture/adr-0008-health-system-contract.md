# ADR-0008: Health System Contract

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Player State) |
| **Knowledge Risk** | LOW — no Godot API used beyond signal emission and _physics_process; all unchanged since 4.0 |
| **References Consulted** | `design/gdd/health-system.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None — pure GDScript logic with no engine API calls beyond basic node operations |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (GameManager — owns take_damage, player_died, dialogue_active), ADR-0005 (SaveManager — `register_save_provider("health", ...)`) |
| **Enables** | ADR-0006 (Camera — subscribes to player_damaged, player_died), ADR-0015 (Hazard System — calls take_damage()), ADR-0019 (Boss System — calls take_damage()), ADR-0021 (HUD — subscribes to health_changed), ADR-0022 (AudioFeedback — subscribes to player_damaged), ADR-0016 (Checkpoint — handles player_died) |
| **Blocks** | No story involving player damage or death may start until this ADR is Accepted |

## Context

Player health state exists in `GameManager.gd` but without a formal contract for the damage intake flow, iframe window, or signal guarantees. Multiple systems need these guarantees before they can be implemented.

**NOTE**: The GDD specifies `take_damage()` as a method on the Health System. After cross-referencing with ADR-0002 (GameManager Contract), the canonical player damage entry point is **`GameManager.take_damage(amount: int) -> void`**. The Health System logic (iframe, health reduction, signals) lives inside GameManager, not in a separate Health System autoload. This ADR documents the contract; the implementation host is GameManager per ADR-0002.

## Decision

Player health is owned by `GameManager` (autoload #2 per ADR-0001). External systems call `GameManager.take_damage(amount)`. All health logic executes inside GameManager following the exact flow specified below.

### State Model

| State | Condition |
|-------|-----------|
| ALIVE | `current_health > 0` and `iframe_timer <= 0` |
| INVINCIBLE | `current_health > 0` and `iframe_timer > 0` |
| DEAD | `current_health == 0` |

INVINCIBLE is a substate of ALIVE. DEAD is terminal until `respawn()` is called.

### Damage Intake Flow (exact order, no exceptions)

```gdscript
func take_damage(amount: int) -> void:
    # Step 0: dialogue invulnerability
    if dialogue_active:
        return

    # Step 1: iframe check
    if iframe_timer > 0.0:
        return

    # Step 2: clamp negative damage
    amount = max(0, amount)

    # Step 3: reduce health
    current_health = max(0, current_health - amount)

    # Step 4: health_changed signal
    health_changed.emit(current_health, max_health)

    # Step 5: player_damaged signal
    player_damaged.emit(amount)

    # Step 6: start iframes
    iframe_timer = IFRAME_DURATION

    # Step 7: death check
    if current_health == 0:
        player_died.emit()
```

### Signals

```gdscript
signal health_changed(current: int, maximum: int)  # emitted by take_damage, respawn, heal, add_max_health
signal player_damaged(amount: int)                  # emitted by take_damage (step 5)
signal player_died                                  # emitted by take_damage (step 7) when health reaches 0
```

### Additional Public Methods

```gdscript
# Called by Checkpoint/Respawn System after player_died.
func respawn() -> void:
    current_health = max_health
    iframe_timer = 0.0
    health_changed.emit(current_health, max_health)
    # Does NOT emit player_damaged or player_died

# Called by SpellUpgrade System for vampiric effects.
func heal(amount: int) -> void:
    current_health = min(current_health + amount, max_health)
    health_changed.emit(current_health, max_health)
    # Does NOT interact with iframes

# Called by Progression System when player collects health upgrade.
func add_max_health(increment: int) -> void:
    if max_health >= BASE_HEALTH + N_UPGRADES * UPGRADE_INCREMENT:
        push_warning("HealthSystem: add_max_health called at cap")
        return
    max_health += increment
    current_health = min(current_health + increment, max_health)
    health_changed.emit(current_health, max_health)
```

### Iframe Countdown

```gdscript
# In _physics_process(delta):
iframe_timer = max(0.0, iframe_timer - delta)
```

### Constants (Data-Driven)

```gdscript
const BASE_HEALTH:        int   = 6
const UPGRADE_INCREMENT:  int   = 2
const N_UPGRADES:         int   = 4
const IFRAME_DURATION:    float = 0.8
# max_health ceiling = BASE_HEALTH + N_UPGRADES * UPGRADE_INCREMENT = 14
```

### Save/Load Integration

```gdscript
# In _ready():
SaveManager.register_save_provider("health", _save_health, _load_health)

func _save_health() -> Dictionary:
    return { "current_health": current_health, "max_health": max_health }

func _load_health(data: Dictionary) -> void:
    if data.is_empty():
        current_health = BASE_HEALTH
        max_health = BASE_HEALTH
        return
    max_health = data.get("max_health", BASE_HEALTH)
    # Validate max_health range
    if max_health < BASE_HEALTH or max_health > BASE_HEALTH + N_UPGRADES * UPGRADE_INCREMENT:
        push_warning("HealthSystem: loaded max_health out of range, resetting")
        max_health = BASE_HEALTH
    current_health = data.get("current_health", max_health)
    current_health = clamp(current_health, 1, max_health)  # EC-06, EC-07
    # No signal on load — HUD reads health on scene ready via initial health_changed
```

### Damage Value Table

| Source | Amount | Caller |
|--------|--------|--------|
| Enemy hit | 1 | Enemy Base System |
| Hazard contact | 1 | Hazard System |
| Boss hit | 2 | Boss System |
| Boss special attack | 3 | Boss System |

These amounts are owned by the calling system — Health System does not know or validate them.

### Architecture Diagram

```
External callers → GameManager.take_damage(amount)
                     └── dialogue_active? return
                     └── iframe_timer > 0? return
                     └── current_health -= amount (clamped)
                     └── health_changed.emit(current, max) → HUD
                     └── player_damaged.emit(amount)     → Camera (Damage Shake)
                                                          → AudioFeedback (hurt SFX)
                     └── iframe_timer = IFRAME_DURATION
                     └── current_health == 0? player_died.emit()
                                                → Checkpoint/Respawn (respawn flow)
                                                → Camera (T-11 hold)

_physics_process(delta) → iframe_timer -= delta (clamped to 0)

Progression System → add_max_health(increment) → health_changed.emit
SpellUpgrade System → heal(amount) → health_changed.emit
Checkpoint System → respawn() → health_changed.emit
```

## Consequences

### Positive
- Single entry point — all health changes traceable to one method
- Iframe deduplication happens at the authoritative source
- `dialogue_active` invulnerability is enforced at step 0 — no per-caller guard needed

### Negative
- Health system logic lives in GameManager — GameManager grows larger over time
- Step 0 (dialogue invulnerability) must be kept in sync with `GameManager.dialogue_active` property; if property is renamed, step 0 silently breaks

### Risks

- **Step order violation**: If `player_died` is emitted before `health_changed` (wrong order), HUD shows non-zero health at death. Mitigation: strict step ordering documented; code review checks emit order.
- **respawn() called before player_died**: `respawn()` is safe in any state — it's a restore operation, not a state transition guard (EC-04).
- **Zero-damage hit consumes iframes** (EC-01 — intentional design choice): callers must not pass 0.

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-health-001 | health-system.md | Single take_damage() entry point; no direct health writes | Public API section |
| TR-health-002 | health-system.md | Damage intake flow in exact 7-step order | Damage Intake Flow section |
| TR-health-003 | health-system.md | iframe_timer countdown in _physics_process | Iframe Countdown section |
| TR-health-004 | health-system.md | health_changed, player_damaged, player_died signals | Signals section (also in ADR-0002) |
| TR-health-005 | health-system.md | heal(amount) method; vampiric upgrade path | Additional Public Methods section |
| TR-health-006 | health-system.md | add_max_health(increment); cap guard | Additional Public Methods section |
| TR-health-007 | health-system.md | respawn() sets current=max, resets iframes | Additional Public Methods section |
| TR-health-008 | health-system.md | Save/load with corruption guards (EC-06,07,08) | Save/Load Integration section |
| TR-health-009 | health-system.md | dialogue_active invulnerability at step 0 | Damage Intake Flow step 0 |

## Performance Implications

- **CPU**: `iframe_timer -= delta` per physics frame. One float subtract + clamp. < 0.001 ms.
- Everything else is event-driven (on hit, on death) — not per-frame.

## Validation Criteria

- AC-01: take_damage(1) → current_health--, health_changed emitted, player_damaged emitted, iframe_timer > 0
- AC-02: take_damage(1) with iframe_timer > 0 → no state change, no signals
- AC-03: take_damage at current_health=1 → current_health=0, player_died emitted
- AC-05: respawn() → current_health=max_health, iframe_timer=0, health_changed emitted, player_died NOT emitted
- AC-09: Save/load round-trip preserves current_health and max_health
- AC-10/11: Corruption guards clamp/reset values without emitting player_died

## Related Decisions

- ADR-0001: GameManager is autoload #2 — hosts health logic
- ADR-0002: GameManager Contract — take_damage() defined as player entry point; dialogue_active flag
- ADR-0005: SaveManager — "health" slice registration
- ADR-0006: Camera System — subscribes to player_damaged (Damage Shake) and player_died (T-11)
- `design/gdd/health-system.md` — full GDD
