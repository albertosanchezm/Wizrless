# ADR-0013: Spell Slot System Contract

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Feature (Spell Loadout) |
| **Knowledge Risk** | LOW — pure GDScript autoload; no post-cutoff APIs |
| **References Consulted** | `design/gdd/spell-slot-system.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0010 (Spell System — SpellResource class, `player.active_spell`), ADR-0003 (Input — `cycle_spell_forward/backward`), ADR-0005 (SaveManager), ADR-0002 (GameManager — `spell_unlocked` signal) |
| **Enables** | ADR-0021 (HUD — subscribes to slot signals), ADR-0025 (Progression — calls `unlock_slot()`) |
| **Blocks** | HUD spell slot row cannot be authored until this contract is Accepted |

## Context

The player begins with one spell slot; additional slots unlock through story milestones. The Spell Slot System owns the slot array, active index, cycling logic, and known-spell library. Without a formal contract, HUD and Progression would implement against guessed interfaces.

## Decision

`SpellSlotSystem` is autoload #7 (per ADR-0001). It owns the slot array and active spell selection. All cycling and loadout mutations go through its methods — no external system writes to `slots[]` or `active_index` directly.

### Class Contract

```gdscript
class_name SpellSlotSystem
extends Node

# State
var slot_count:   int = 1                  # unlocked slots; grows on milestone
var slots:        Array[SpellResource] = [] # length == slot_count; null = empty slot
var active_index: int = 0
var known_spells:  Array[SpellResource] = []

const MAX_SLOTS: int = 5

# Signals
signal active_spell_changed(spell: SpellResource)
signal slot_unlocked(new_count: int)
signal loadout_changed(slots: Array)

# Computed active spell
var active_spell: SpellResource:
    get: return slots[active_index] if active_index < slots.size() else null
```

### Slot Cycling

```gdscript
func cycle_forward() -> void:
    if slot_count <= 1: return
    var next := (active_index + 1) % slot_count
    var start := next
    while slots[next] == null:
        next = (next + 1) % slot_count
        if next == start: return   # all null — no change
    active_index = next
    _sync_player_spell()
    active_spell_changed.emit(active_spell)

func cycle_backward() -> void:
    if slot_count <= 1: return
    var prev := (active_index - 1 + slot_count) % slot_count
    var start := prev
    while slots[prev] == null:
        prev = (prev - 1 + slot_count) % slot_count
        if prev == start: return
    active_index = prev
    _sync_player_spell()
    active_spell_changed.emit(active_spell)
```

Cycling disabled during AttackState: `cycle_forward/backward` input checked by SpellSlotSystem only outside AttackState. Implemented via `GameManager.is_attack_active: bool` flag.

### Slot Unlock

```gdscript
func unlock_slot() -> void:
    if slot_count >= MAX_SLOTS: return
    slot_count += 1
    slots.append(null)
    slot_unlocked.emit(slot_count)
```

Called by Progression System on story milestones. New slot is null (empty). Active spell unaffected.

### Loadout API

```gdscript
# Equip: handles duplicate detection (EC-04 swap rule)
func equip_spell(slot_index: int, spell: SpellResource) -> void:
    # If spell already in another slot: clear that slot first
    for i in slot_count:
        if slots[i] == spell and i != slot_index:
            slots[i] = null
    slots[slot_index] = spell
    loadout_changed.emit(slots)
    if slot_index == active_index:
        _sync_player_spell()
        active_spell_changed.emit(active_spell)

# Unequip
func unequip_slot(slot_index: int) -> void:
    slots[slot_index] = null
    if slot_index == active_index:
        _advance_to_next_non_null()
    loadout_changed.emit(slots)
```

### Known Spell Library

```gdscript
func _ready() -> void:
    GameManager.spell_unlocked.connect(_on_spell_unlocked)

func _on_spell_unlocked(spell: SpellResource) -> void:
    if not known_spells.has(spell):
        known_spells.append(spell)
```

Game start: Fireball pre-equipped in slot 0 (set by save load or new-game initializer).

### Save / Load

```gdscript
# Registered under "spells" key with SaveManager
func _save_spells() -> Dictionary:
    return {
        "slot_count": slot_count,
        "known_spell_ids": known_spells.map(func(s): return str(s.id)),
        "equipped_spell_ids": slots.map(func(s): return str(s.id) if s else ""),
        "active_index": active_index,
    }

func _load_spells(data: Dictionary) -> void:
    if data.is_empty():
        slot_count = 1
        slots = [_spell_by_id(&"fireball")]
        active_index = 0
        return
    slot_count = clamp(data.get("slot_count", 1), 1, MAX_SLOTS)
    # ... restore from IDs via spell registry lookup
    # EC-07: unknown ID → null slot (no crash)
    # EC-08: slot_count > MAX_SLOTS → clamped above
```

SpellResource lookup by ID uses a global spell registry (Dictionary of id → SpellResource loaded from `res://resources/spells/`).

### Architecture Diagram

```
InputContextManager (GAMEPLAY context)
  └── cycle_spell_forward/backward → SpellSlotSystem.cycle_forward/backward()
         └── active_index update → _sync_player_spell() → player.active_spell
              └── active_spell_changed.emit() → HUD slot row

Progression System → unlock_slot() → slots.append(null) → slot_unlocked.emit()

Loadout Screen → equip_spell(idx, spell) / unequip_slot(idx) → loadout_changed.emit()
```

## Consequences

### Positive
- Single owner of active spell state; player script reads `active_spell` without mutation
- Duplicate prevention on equip (EC-04 swap) is in one method, not per-caller

### Negative
- Cycling disabled during AttackState requires `GameManager.is_attack_active` flag — another responsibility added to GameManager
- Spell registry (id → resource) must load all spell `.tres` on game start; small startup cost

### Risks
- **Null active_spell during early init**: Guard in `wants_attack()` — returns false if `active_spell == null`
- **Save with unknown spell ID**: Unknown IDs silently become null slots; player may notice empty slots on load from future save

## GDD Requirements Addressed

| TR-ID | GDD | Requirement | How This ADR Addresses It |
|-------|-----|-------------|--------------------------|
| TR-slot-001 | spell-slot-system.md | SpellSlotSystem is an autoload singleton | Class Contract section |
| TR-slot-002 | spell-slot-system.md | slots: Array[SpellResource] with 1–5 entries, dynamic resize | Class Contract + unlock_slot() |
| TR-slot-003 | spell-slot-system.md | active_index tracks which slot is selected for casting | Class Contract |
| TR-slot-004 | spell-slot-system.md | Slot count progression tied to story milestones | unlock_slot() called by Progression System |
| TR-slot-005 | spell-slot-system.md | Slot cycling skips null slots | cycle_forward/backward null-skip logic |
| TR-slot-006 | spell-slot-system.md | Save payload: slot_count, known_spell_ids, equipped_spell_ids, active_index | Save/Load section |
| TR-slot-007 | spell-slot-system.md | Signals: active_spell_changed, slot_unlocked, loadout_changed | Class Contract signals |

## Related Decisions

- ADR-0010: SpellResource definition
- ADR-0025: Progression System — calls `unlock_slot()` on milestones
- ADR-0021: HUD System — subscribes to all three slot signals
- `design/gdd/spell-slot-system.md` — full GDD
