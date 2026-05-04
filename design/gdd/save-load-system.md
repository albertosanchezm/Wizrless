# Save/Load System

> **Status**: Complete
> **Author**: albertosanchezm + agents
> **Last Updated**: 2026-04-17
> **Implements Pillar**: Controlled Ascension — spell slots, zone unlocks, and material accumulation persist across sessions. Earned Truth — boss defeats and lore discoveries are permanent, non-repeatable events.

## Overview

The Save/Load System is the persistence layer for all cross-session game state. It defines what data is durable (survives between play sessions), when that data is written to disk, and how consuming systems register their state for serialisation and retrieve it on load. All durable state flows through this system — no other system writes to disk directly.

One save slot is supported. The save file is a JSON document written to `user://wizrless_save.json`. Saves are triggered automatically by game events (checkpoint activation, boss defeat, zone transition) — there is no manual save action. The file is written atomically: the new file is written to a temporary path and renamed over the old file only on success, preventing corruption from interrupted writes.

Consuming systems (Health, Zone/Room, Material, Checkpoint/Respawn, Spell System, Lore Fragment) each own a slice of the save document. The Save/Load System provides a registration interface: systems register a `Callable` that produces their serialisable dictionary and a `Callable` that receives their dictionary slice on load. The Save/Load System calls each registered provider on save and each registered consumer on load — it does not know the internal structure of any system's data.

The Settings System is explicitly excluded — volume and input preferences are written separately to `user://settings.json` and managed independently.

## Player Fantasy

The Save/Load System has no player fantasy of its own. The player never thinks about it — and that is the goal. When it works correctly, it disappears.

What it makes possible: the wizard's world has memory. Every boss defeated stays defeated. Every zone opened stays open. Every material gathered accumulates. The player closes the game mid-zone and returns three days later to find the wizard exactly where they left him — the same activated checkpoint, the same materials in inventory, the same spells equipped. The world did not reset. The order did not forget what happened.

For a game about uncovering hidden truth incrementally, session persistence is not a convenience feature — it is a design requirement. Discoveries must be permanent because they are story beats. A boss fight that can be re-encountered without consequence is a boss fight that did not matter.

The moment this makes possible: the player defeats Devium. The screen fades. Three days later they open the game. The arena is empty. Devium is gone. What was a colleague is now history. That permanence is the Save/Load System working as designed.

*Systems that deliver what this enables:* Health System (C2), Checkpoint/Respawn System (FT13), Boss System (FT6), Lore Fragment System (PL4).

## Detailed Design

### Core Rules

**C1 — Save Triggers**

Saves are automatic. There is no manual save. The following events trigger a save:

| Trigger | Who signals it | Timing |
|---------|---------------|--------|
| Checkpoint activation | Checkpoint/Respawn System | Immediately on player touch |
| Boss defeat | Boss System | After the defeat animation completes — not during |
| Zone transition | Zone/Room System | When the new zone is fully loaded (outgoing zone state is frozen before unload) |

A save in progress cannot be interrupted by another trigger. If a second trigger fires while saving, it is queued and executed once the current write finishes. At most one save is queued at a time — additional triggers while queued are dropped.

**C2 — One Save Slot**

One canonical save file: `user://wizrless_save.json`. Starting a New Game deletes the existing file after user confirmation. There is no way to maintain multiple simultaneous playthroughs.

**C3 — Atomic Write**

To prevent corruption from interrupted writes:
1. Collect all registered provider dictionaries.
2. Serialise to JSON string.
3. Write to `user://wizrless_save.tmp`.
4. If write succeeds: rename `.tmp` → `wizrless_save.json` (overwrites the previous save).
5. If write fails at any step: delete the `.tmp` file. The previous save is intact.

`FileAccess.file_exists("user://wizrless_save.json")` is used for all existence checks — not null-check on `FileAccess.open()` (Godot 4.4+ API).

### States and Transitions

**C4 — System States**

| State | Description |
|-------|-------------|
| NO_FILE | No save file exists. Game must be started fresh. |
| IDLE | Save file exists and no I/O in progress. Normal gameplay. |
| SAVING | Write in progress. Additional triggers queue. |
| LOADING | Read in progress. Additional triggers queue. |

Transitions:
- `NO_FILE → IDLE`: `new_game()` called — fresh file written.
- `IDLE → SAVING`: save trigger fires.
- `SAVING → IDLE`: write completes successfully.
- `SAVING → IDLE` (error): write failed — previous save preserved, `save_error` signal emitted.
- `IDLE → LOADING`: `load_game()` called on boot or "Continue" from menu.
- `LOADING → IDLE`: read and distribution to systems complete.
- `IDLE → NO_FILE`: `delete_save()` called — file deleted, state resets.

### Interactions with Other Systems

**C5 — Registration Interface**

`SaveSystem` is a singleton Autoload. Systems register on `_ready()`:

```gdscript
## Register a system's save/load participation.
## key: the slice name in the JSON document (must be unique per system).
## save_fn: called with no arguments; must return a Dictionary.
## load_fn: called with the system's Dictionary slice; no return value.
func register_save_provider(key: String, save_fn: Callable, load_fn: Callable) -> void
```

On save: `SaveSystem` iterates all registered providers, calls each `save_fn()`, and writes results under their keys. On load: `SaveSystem` reads the file, extracts each key's sub-dictionary, and calls the corresponding `load_fn(data)`.

If a registered key is missing from the save file on load (system added after the save was created), `load_fn` is called with an empty Dictionary. Systems must handle the empty case and initialise to defaults.

**C6 — Save Document Structure**

```json
{
  "meta": {
    "save_version": 1,
    "timestamp_unix": 0,
    "playtime_seconds": 0,
    "game_version": "0.1.0"
  },
  "[system_key]": { ... }
}
```

The `meta` slice is owned by `SaveSystem` itself. All other slices are owned by the systems that registered them. `SaveSystem` does not inspect or validate system slice content — it stores and retrieves opaque dictionaries.

**C7 — Public Interface**

```gdscript
## Call on boot. Emits save_loaded or no_save_found.
func check_and_load() -> void

## Start a new playthrough. Emits confirm_overwrite if file exists.
func new_game() -> void

## Trigger a save (called by game events, not by player directly).
func save_game() -> void

## Returns true if a save file exists.
func has_save() -> bool

## Emitted when save file is loaded and all systems are initialised.
signal save_loaded

## Emitted when no save file exists (show New Game screen).
signal no_save_found

## Emitted when a write error occurs.
signal save_error(message: String)
```

**C8 — Boot Sequence**

On game launch, `SaveSystem.check_and_load()` is called before any gameplay systems are ready. All systems register their providers in `_ready()`. Load is deferred until after all Autoloads complete their `_ready()` calls. The Main Menu reads `has_save()` to show "Continue" vs. "New Game."

## Formulas

**F1 — Playtime Accumulation**

Playtime is recorded in whole seconds and accumulated during active gameplay:

```
playtime_on_save = playtime_stored + elapsed_since_last_save
elapsed_since_last_save = (Time.get_ticks_msec() − session_start_ticks_msec) / 1000.0
```

Variables:
- `playtime_stored` — seconds from the loaded save file's `meta.playtime_seconds`; 0 if new game
- `elapsed_since_last_save` — seconds since the session began or since the last save write
- `playtime_on_save` — integer seconds written to `meta.playtime_seconds`; truncated (not rounded)

The Main Menu displays playtime as `HH:MM`:
- `hours = playtime_seconds / 3600`
- `minutes = (playtime_seconds % 3600) / 60`

Playtime is not paused during the pause menu — it reflects total session time.

## Edge Cases

**E1 — Corrupted save file (JSON parse failure)**
`JSON.parse()` returns an error or a non-Dictionary result. Rule: `SaveSystem` emits `save_error("corrupt_save")` and transitions to NO_FILE state. The Main Menu shows "New Game" only. The corrupt file is renamed to `user://wizrless_save.corrupt.json` (not deleted) so the player can potentially recover it manually.

**E2 — Save version mismatch**
`meta.save_version` does not match the current expected version. Rule: if the file version is older, apply migration (see OQ-SAV-001). If the file version is newer than the current game build, emit `save_error("version_too_new")` and treat as NO_FILE.

**E3 — Missing system slice on load**
A registered key is absent from the save file (system added after the save was created). Rule: `load_fn` is called with an empty Dictionary. The system initialises to defaults. This is the intended forward-compatibility path — not an error.

**E4 — Disk full during write**
Write fails mid-stream. Rule: the `.tmp` file is deleted. The previous `wizrless_save.json` is untouched. `save_error("disk_full")` is emitted. SaveSystem returns to IDLE — no state is lost.

**E5 — Two save triggers in the same frame**
Boss defeat and checkpoint activation signal simultaneously. Rule: the first trigger starts a save; the second is queued. The queue holds at most one pending save — further triggers while queued are dropped. The queued save executes immediately after the current write, capturing state after both triggers resolved.

**E6 — New Game called while save in progress**
Debug path or race condition. Rule: `new_game()` is queued and executes after the current write completes. The in-progress save finishes successfully first, then the file is deleted.

**E7 — load_fn throws an error**
A system's `load_fn` raises an exception. Rule: `SaveSystem` catches it, logs the system key and error, and continues calling `load_fn` for all other registered systems. The failing system defaults to its empty-dictionary path. `save_error` is emitted with the key and description.

**E8 — Game quit before first checkpoint**
Player starts a new game and force-quits before activating any checkpoint. Rule: no save was triggered — on next launch, `has_save()` is false. The session is lost. This is intentional: the first checkpoint is the first action that durably changes the wizard's world.

## Dependencies

**Upstream (SaveSystem depends on):**

SaveSystem is Foundation-layer — it has no runtime dependencies on other game systems. It depends only on Godot's `FileAccess` and `JSON` built-ins.

**Downstream (systems that depend on SaveSystem):**

| System | Key (JSON slice) | What it persists |
|--------|-----------------|-----------------|
| Health System (C2) | `"health"` | Current health, max health |
| Spell System (C3) | `"spells"` | Owned spells, spell slot count, equipped loadout |
| Zone/Room System (C5) | `"zones"` | Visited rooms, cleared static enemies, opened doors/shortcuts |
| Checkpoint/Respawn System (FT13) | `"checkpoints"` | Last activated checkpoint ID |
| Material System (FT15) | `"materials"` | Material type → quantity map |
| Spell Upgrade System (FT17) | `"spell_upgrades"` | Per-spell upgrade levels and applied properties |
| Boss System (FT6) | `"bosses"` | Defeated boss IDs (permanent — these rooms stay cleared) |
| Lore Fragment System (PL4) | `"lore"` | Discovered fragment IDs |
| Main Menu (PL-VS) | reads `has_save()` | Shows "Continue" vs. "New Game" |
| Settings System (PL1) | NOT registered | Writes its own `user://settings.json` independently |

**Trigger callers (who calls `save_game()`):**

| Caller | When |
|--------|------|
| Checkpoint/Respawn System | On checkpoint activation |
| Boss System | After defeat animation complete |
| Zone/Room System | On zone transition (new zone fully loaded) |

## Tuning Knobs

| Knob | Default | Safe Range | Affects |
|------|---------|------------|---------|
| `save_version` | 1 | N/A (increment only) | Schema version in `meta.save_version`. Increment on breaking slice format changes. Never decrement. |
| `save_file_path` | `"user://wizrless_save.json"` | Any valid `user://` path | Primary save file location. Change only for platform-specific requirements. |
| `save_tmp_path` | `"user://wizrless_save.tmp"` | Any valid `user://` path | Temp file used during atomic write. Must differ from `save_file_path`. |
| `corrupt_backup_path` | `"user://wizrless_save.corrupt.json"` | Any valid `user://` path | Where corrupt saves are moved (not deleted) for manual recovery. |

No gameplay values are configurable in this system. The only meaningful tuning is the save version and file paths, which change only when intentionally migrating the save format.

## Acceptance Criteria

**AC-SAV-001 — Save file created on new game**
Call `new_game()` with no existing save file. `FileAccess.file_exists("user://wizrless_save.json")` must return `true`. The file contains valid JSON with a `meta` key and `save_version: 1`.

**AC-SAV-002 — Registration and round-trip**
Register a provider with key `"test"`, `save_fn` returning `{"value": 42}`, and `load_fn` storing the received dictionary. Call `save_game()` then `check_and_load()`. The `load_fn` must receive `{"value": 42}`.

**AC-SAV-003 — Atomic write: crash simulation**
Simulate a failed write (delete `.tmp` mid-stream). The original `wizrless_save.json` must remain intact and parseable. `save_error` must be emitted.

**AC-SAV-004 — Corrupt save handling**
Replace `wizrless_save.json` with invalid JSON. Call `check_and_load()`. `no_save_found` must be emitted. `wizrless_save.corrupt.json` must exist. `has_save()` must return `false`.

**AC-SAV-005 — Missing slice forward-compatibility**
Create a save file missing the `"health"` key. Register a Health System provider. Call `check_and_load()`. Health System's `load_fn` must be called with an empty Dictionary. No crash.

**AC-SAV-006 — Save queue: at most one pending save**
Call `save_game()` three times in rapid succession while the first write is in progress. Exactly two write operations must occur. No more.

**AC-SAV-007 — Boss defeat save timing**
Boss defeat triggers save after the defeat animation completes. Verify save timestamp is at least `defeat_animation_duration_ms` after the boss health reaches zero.

**AC-SAV-008 — Boss defeat permanence**
Defeat a boss. Save. Reload the game. The boss must not be present in its room. The `"bosses"` slice must contain the defeated boss's ID.

**AC-SAV-009 — Playtime accumulates correctly**
Load a save with `playtime_seconds: 100`. Play for 60 real seconds. Trigger a save. The new `meta.playtime_seconds` must be ≥ 160.

**AC-SAV-010 — has_save() before and after new game**
With no save file: `has_save()` returns `false`. After `new_game()`: `has_save()` returns `true`. After deleting the file manually: `has_save()` returns `false`.

**AC-SAV-011 — No system writes to disk except SaveSystem and SettingsSystem**
Grep the codebase for `FileAccess` calls outside `save_system.gd` and `settings_system.gd`. Result must be zero matches.

**AC-SAV-012 — version_too_new handling**
Create a save file with `save_version: 999`. Call `check_and_load()`. `save_error("version_too_new")` must be emitted. `has_save()` must return `false`. Original file is preserved.

## Open Questions

**OQ-SAV-001 — Save migration strategy**
When `save_version` increments, what is the migration path? Two options: (A) in-place migration inside `SaveSystem` (reads old format, writes new format on next save), or (B) external migration tool run at launch. A migration registry (version → migration function) is the recommended pattern but the implementation should be defined in an ADR before any breaking schema change is made.

**OQ-SAV-002 — Steam Cloud Save integration**
PC/Steam launch will likely require Steam Cloud Saves. Godot does not natively integrate with the Steamworks SDK — this requires GodotSteam or an equivalent plugin. The save file path (`user://`) is compatible with Steam's file sync, but the integration must be confirmed before the Settings System vertical slice. Add to Allowed Libraries in `technical-preferences.md` when integration begins.

**OQ-SAV-003 — Checkpoint ID authority**
The save file stores the last activated checkpoint ID. The Checkpoint/Respawn System must own the canonical list of valid IDs. If a checkpoint ID in the save file is not found in the current scene (e.g., after a level change in development), what is the fallback? This must be defined when the Checkpoint/Respawn System GDD is authored.

**OQ-SAV-004 — New Game confirmation UI**
`new_game()` emits `confirm_overwrite` if a save file exists. Which system renders the confirmation dialogue? The Pause Menu or Main Menu must handle this signal and present the player with a destructive action confirmation before calling `delete_save()`. Define the exact UI flow when the Pause Menu GDD is authored.
