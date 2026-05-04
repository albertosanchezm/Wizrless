# Spell Slot System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: Controlled Ascension (primary), Spell Alchemy (support)

## Overview

The Spell Slot System manages which spells the wizard has equipped and which one is currently active. It owns the slot array (ordered list of equipped `SpellResource` references, 1–5 entries), the active slot index, the cycle-slot input handler, the loadout equip/unequip interface, and the slot unlock flow. It writes to `player.active_spell` whenever the active slot changes and emits `GameManager.active_spell_changed` for the HUD.

At MVP the wizard has one slot — one spell, no choice, no cycling. The Controlled Ascension arc makes each unlock a felt event: the second slot is the first moment the player must decide, and the decision has real consequences because spell combinations drive the interaction engine. By slot five the loadout screen is not a menu — it is a build.

Slot count unlocks through story milestones. The Progression System calls `SpellSlotSystem.unlock_slot()` at the appropriate moment. Known spells accumulate separately via `GameManager.spell_unlocked`. Equipping a spell requires opening the Loadout Screen (accessed from pause menu). In-combat spell switching uses `cycle_spell_forward` / `cycle_spell_backward` input actions, cycling through all currently equipped slots.

## Player Fantasy

He has one hand. He has one thing in it. Until he doesn't.

The moment the second slot unlocks, the game changes. Not in difficulty — in texture. There is now a decision before every room: which two things, out of everything he knows. The first time he cycles mid-combat and discovers something he had never tried — that is Spell Alchemy, not as a system, but as a felt moment.

By five slots the loadout screen is no longer a menu. It is a statement about what kind of wizard — and what kind of demon — he has decided to become.

## Detailed Design

### Data Model

`SpellSlotSystem` lives as a Godot autoload. Accessed by Loadout Screen, player script, and HUD.

```
SpellSlotSystem (Autoload)
  slot_count:   int                   # unlocked slots (starts 1, max 5)
  slots:        Array[SpellResource]  # equipped spells; length == slot_count; null = empty
  active_index: int                   # index into slots (0-based)
  known_spells: Array[SpellResource]  # all spells the wizard has unlocked

  # Signals
  signal active_spell_changed(spell: SpellResource)
  signal slot_unlocked(new_count: int)
  signal loadout_changed(slots: Array)
```

`active_spell` is computed: `slots[active_index]`. When it changes, `active_spell_changed` emits and `player.active_spell` is updated.

---

### Slot Progression

| Story Milestone | Slot Count |
|-----------------|-----------|
| Game start | 1 |
| End of Zone 1 (first boss defeat) | 2 |
| Mid Zone 2 | 3 |
| End of Zone 3 | 4 |
| End of Zone 4 | 5 (max) |

Progression System calls `SpellSlotSystem.unlock_slot()` at each milestone. `slots` grows by one null entry. `slot_count` increments. `slot_unlocked` fires.

---

### In-Combat Cycling

Input actions: `cycle_spell_forward`, `cycle_spell_backward` (registered in InputMap).

On `cycle_spell_forward`:
1. `active_index = (active_index + 1) % slot_count`
2. Skip null slots. If all slots null: no change.
3. `player.active_spell = slots[active_index]`.
4. Emit `active_spell_changed`.

At MVP (1 slot): cycling does nothing — `active_index` stays 0, no feedback needed.

Cycling disabled during: AttackState (mid-cast), Death state, Loadout Screen open.

---

### Loadout Screen

Accessed from pause menu. Equip and unequip spells.

**Equip:**
1. Select a slot (empty or occupied).
2. Known spell list shown.
3. Select spell → `slots[selected] = spell`.
4. Emit `loadout_changed`.
5. If selected == active_index: emit `active_spell_changed`, update `player.active_spell`.

**Unequip:**
1. Select occupied slot → confirm removal.
2. `slots[selected] = null`.
3. If selected == active_index: auto-advance to next non-null slot. If all null: `player.active_spell = null`.

**Constraint**: same spell cannot occupy two slots. Equipping a spell already in another slot swaps positions — no duplication.

---

### Spell Library Management

`known_spells` is populated by:
- `GameManager.spell_unlocked(spell)` signal → append to `known_spells`.
- `SaveManager` restore on load.

At game start: Fireball pre-equipped in slot 0 (narrative default — the order's "safe" spell, the wizard's first).

---

### Save / Load

Persisted via `SaveManager`:

| Key | Type | Description |
|-----|------|-------------|
| `"slot_count"` | int | Unlocked slot count |
| `"known_spell_ids"` | Array[StringName] | IDs of all known spells |
| `"equipped_spell_ids"` | Array[StringName] | ID per slot; `""` = empty |
| `"active_index"` | int | Currently active slot |

Restored before first room loads. `SpellResource` files looked up by ID from a spell registry.

---

### Interactions with Other Systems

| System | Direction | Exchange |
|--------|-----------|---------|
| Spell System | Slot → Spell | Writes `player.active_spell`; emits `active_spell_changed` |
| Progression System | → Slot | Calls `unlock_slot()` on story milestones |
| Input System | → Slot | `cycle_spell_forward/backward` actions |
| HUD System | Slot → HUD | `active_spell_changed`, `slot_unlocked`, `loadout_changed` signals |
| Save/Load System | Bidirectional | Slot config saved on change; restored on load |
| Spell Interaction Engine | Slot → Engine | Engine reads `active_spell` via player to track cast history |

## Formulas

### Cycling Index

```
-- Forward cycle:
active_index = (active_index + 1) % slot_count

-- Backward cycle:
active_index = (active_index - 1 + slot_count) % slot_count

-- Skip null slots (forward):
next = (active_index + 1) % slot_count
while slots[next] == null and next != active_index:
    next = (next + 1) % slot_count
active_index = next  -- unchanged if all null
```

### Slot Unlock Timeline

```
-- Approximate story time to each unlock (design target):
Slot 1: game start      (~0h)
Slot 2: Zone 1 boss     (~1.5h)
Slot 3: mid Zone 2      (~3.0h)
Slot 4: Zone 3 boss     (~5.0h)
Slot 5: Zone 4 boss     (~7.5h)

Front-loaded constraint is intentional: first 1.5h with 1 slot establishes
the baseline. Each unlock is spaced further apart as the spell library grows.
```

### Loadout Combinations

```
-- Ordered loadouts with no repeats (K slots, N known spells):
combinations = N! / (N - K)!

MVP  (K=1, N=6):            6 loadouts
Slot 2 (K=2, N=8):          56 ordered loadouts
Slot 5 (K=5, N=15):     360,360 ordered loadouts

In practice: far fewer meaningful combinations.
The Interaction Engine defines which pairs matter — that is the real design space.
```

### Variable Definitions

| Variable | Value | Description |
|----------|-------|-------------|
| `slot_count` | 1–5 | Current unlocked slot count |
| `MAX_SLOTS` | 5 | Hard cap — Controlled Ascension pillar |
| `active_index` | 0–(slot_count−1) | Currently active slot index |

## Edge Cases

**EC-01 — Cycle with one slot unlocked.**
`(0 + 1) % 1 = 0`. `active_index` stays 0. No signal emits. At MVP this is the normal state — cycling is a no-op by design.

**EC-02 — Cycle with null (empty) slots.**
Skip logic advances past null entries. If only one slot is populated, cycling always lands on it. If all slots are null, cycling does nothing — `active_index` unchanged, no signal.

**EC-03 — Slot unlocked mid-combat.**
Array grows by one null entry. `slot_count` increments. `slot_unlocked` emits. `active_index` and `player.active_spell` are unchanged — new slot is empty, does not affect current combat.

**EC-04 — Duplicate equip attempt.**
Equipping a spell already in slot A into slot B: slot A cleared, spell moves to slot B. No duplication. If slot A was `active_index`: updates to slot B, `active_spell_changed` emits.

**EC-05 — Active slot unequipped.**
`active_index` auto-advances to next non-null slot. `active_spell_changed` emits. If no other spell equipped: `player.active_spell = null`. `wants_attack()` returns false — wizard cannot cast.

**EC-06 — Cycle input during AttackState.**
Input read but produces no change. In-progress cast completes with the spell active at `_enter()`.

**EC-07 — Save spell ID no longer resolves.**
Unknown spell ID on load → slot initialized to null. No crash. Missing ID excluded from known spells. Player sees empty slot.

**EC-08 — Save data slot_count exceeds MAX_SLOTS.**
Clamp to `MAX_SLOTS = 5` on load. Extra slots discarded. Log a warning.

**EC-09 — All known spells already equipped.**
Loadout Screen shows all spells dimmed/unavailable. Equipping an already-equipped spell into a different slot triggers EC-04 (swap). Same-slot re-equip is a no-op.

**EC-10 — Cycle input same frame as slot unlock.**
Array grows, then cycle processes with updated `slot_count`. Null-skip handles the new empty slot. No conflict.

## Dependencies

### Systems this requires

| System | What Spell Slot needs |
|--------|----------------------|
| **Spell System** | `SpellResource` class; `player.active_spell` property to write |
| **Input System** | `cycle_spell_forward`, `cycle_spell_backward` actions in InputMap |
| **Progression System** | Calls `SpellSlotSystem.unlock_slot()` on story milestones |
| **Save/Load System** | `SaveManager` get/set for slot config, known spells, active index |
| **GameManager autoload** | `spell_unlocked(spell)` signal — appends to known spell library |

### Systems that require this

| System | What it needs |
|--------|--------------|
| **HUD System** | `active_spell_changed`, `slot_unlocked`, `loadout_changed` signals |
| **Spell Interaction Engine** | `active_spell` (via player) for cast history tracking |
| **Pause Menu / Loadout Screen** | Full `SpellSlotSystem` API — read slots, equip, unequip |

### Hard blockers

- `SpellResource` class defined
- `player.active_spell` property exists
- `cycle_spell_forward/backward` registered in InputMap
- `SaveManager` read/write available

## Tuning Knobs

| Knob | Value | Range | Effect |
|------|-------|-------|--------|
| `MAX_SLOTS` | 5 | 3–6 | Power ceiling. Below 3: build variety too narrow. Above 6: combinatorial space exceeds meaningful interaction design. |
| Slot 2 unlock timing | Zone 1 boss (~1.5h) | 0.5–3h | Constraint duration. Earlier = less time to feel single-slot gameplay. Later = constraint overstays. |
| Slot spacing | Non-linear (front-loaded) | — | Each slot should take longer to earn than the previous. Resist even spacing. |

No per-slot stat modifiers. Slots are equal containers — power comes from spell choice and interaction knowledge, not slot count.

## Visual/Audio Requirements

### Slot Cycle Feedback

On `active_spell_changed` during combat:
- Active spell icon flashes or scale-pops briefly in HUD
- Optional: short click/whoosh SFX on cycle
- No combat pause, no animation interrupt

### Slot Unlock Moment

On `slot_unlocked`:
- Brief screen notification: "New spell slot unlocked" (HUD System scope)
- Distinct unlock chime SFX — weightier than a regular pickup
- Non-blocking Loadout Screen prompt (polish addition)

### Loadout Screen Visuals

- Slot row: N frames side by side, spell icon inside; empty slots show faint outline
- Active slot: highlighted border or glow
- Known spell list: icon grid; dimmed if already equipped elsewhere
- Spell preview panel: name, element, description on select

## UI Requirements

### HUD Spell Display

Replaces hardcoded `_fireball_portrait` in `hud.gd`. Becomes a dynamic slot row:

- 1–5 frames rendered based on `slot_count`
- Each frame: spell icon + cooldown radial overlay (from `attack_cooldown_changed`)
- Active slot: highlighted border
- Empty slot: dim placeholder frame
- Signals: `active_spell_changed`, `slot_unlocked`, `loadout_changed`

**Migration required**: `_fireball_portrait` and `FireballCooldown` nodes in `hud.tscn` must be replaced with a dynamic slot container.

### Loadout Screen

Full pause-state screen accessed from pause menu. Not a HUD overlay. Owned by UI System GDD. Reads and writes through `SpellSlotSystem` API.

### Locked Slots

Unlocked empty slots visible as dim frames. Locked slots (beyond `slot_count`) not shown at MVP — the unlock is the surprise, not a teased lock icon.

## Acceptance Criteria

**AC-01 — Single slot at game start.**
Launch new game. `slot_count = 1`. Fireball equipped in slot 0. `player.active_spell` is Fireball. Pass: correct initial state.

**AC-02 — Active spell written to player.**
Equip Ice Shard in slot 0 via Loadout Screen. `player.active_spell` is Ice Shard. Cast — Ice Shard fires. Pass: player casts newly equipped spell.

**AC-03 — Cycle with one slot does nothing.**
`slot_count = 1`, Fireball equipped. Press `cycle_spell_forward`. No change, no signal, no visual feedback. Pass: no-op confirmed.

**AC-04 — Cycle switches active spell.**
Slot 0 = Fireball, slot 1 = Ice Shard, `active_index = 0`. Press forward. `active_index = 1`, HUD updates to Ice Shard. Pass: correct cycle.

**AC-05 — Cycle skips empty slots.**
Slot 0 = Fireball, slot 1 = null, slot 2 = Ice Shard, `active_index = 0`. Press forward. `active_index = 2`. Pass: null slot skipped.

**AC-06 — Slot unlock adds empty slot.**
Trigger `unlock_slot()`. `slot_count` increases by 1. New slot is null. `slot_unlocked` emits. `player.active_spell` unchanged. Pass: correct post-unlock state.

**AC-07 — Duplicate equip swaps, not duplicates.**
Fireball in slot 0, Ice Shard in slot 1. Equip Fireball into slot 1. Slot 0 becomes null, slot 1 = Fireball. Pass: no two slots hold same spell.

**AC-08 — Unequipping active slot auto-advances.**
Fireball active in slot 0, Ice Shard in slot 1. Unequip slot 0. `active_index` advances to 1. `player.active_spell` = Ice Shard. Pass: no null active spell when alternatives exist.

**AC-09 — Loadout config persists across sessions.**
Equip Ice Shard in slot 0. Save and quit. Reload. Ice Shard in slot 0, `active_index` correct. Pass: slot config restored from save.

**AC-10 — Cycling disabled during cast.**
Mid-attack animation: press `cycle_spell_forward`. Active spell does not change. Cast completes with original spell. Pass: no mid-cast slot swap.
