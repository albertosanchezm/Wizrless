# Dialogue System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-03
> **Implements Pillar**: Earned Truth

## Overview

The Dialogue System defines how story beats are delivered, triggered, and persisted. It is built on the **Dialogue Manager v2 addon** (already installed). At MVP, all dialogue is pre-boss intro sequences: linear, mandatory, blocking — the player cannot skip past them without reading them. No ambient NPC dialogue, no branching choices, no mid-combat narration at MVP.

Every boss fight is preceded by a dialogue sequence that reveals one story beat and one tactical hint. This is the Earned Truth pillar in mechanical form: the player earns the story by reaching the boss, and the boss earns the player's attention by giving useful information.

The addon's `show_dialogue_balloon()` / `await balloon.tree_exited` pattern is the only dialogue trigger mechanism at MVP. All dialogue content lives in external `.dialogue` files (one per boss), not inline strings. Portrait display is data-driven via a character registry dictionary — adding a new speaking character requires no code changes. Dialogue completion is persisted to save state so sequences do not replay on re-entry.

## Player Fantasy

The dialogue box appears and the world stops.

For a few seconds, the wizard and the enemy exist only as words on a screen. The player leans forward. Whatever the boss says is not flavor — it is information. A hint about a weakness, a fragment of the world's broken history, a moment of personality that makes the fight feel like a confrontation rather than an obstacle.

When the box closes, the player wants to fight. Not because the game told them to. Because something was said that made the fight matter.

## Detailed Design

### Architecture

The Dialogue Manager singleton manages all dialogue state. Game code interfaces with it through two calls:

```gdscript
var resource := load("res://dialogue/bosses/boss_devium.dialogue")
var balloon  := DialogueManager.show_dialogue_balloon(resource, &"start")
await balloon.tree_exited
# dialogue complete — resume game logic
```

Game code never manipulates `DialogueLine`, `DialogueLabel`, or `DialogueResponsesMenu` directly. The balloon handles all input, typewriter effects, and UI layout internally.

---

### Dialogue Balloon (UI)

The `ExampleBalloon` scene (addon-provided, customized for this project) is the visual layer.

```
ExampleBalloon (CanvasLayer)
└─ Balloon (Control)
   └─ MarginContainer → PanelContainer → HBoxContainer
      ├─ Portrait (TextureRect)      — speaker portrait, hidden if no portrait registered
      └─ VBoxContainer
         ├─ CharacterLabel           — speaker name (RichTextLabel)
         ├─ DialogueLabel            — typewriter text (custom RichTextLabel)
         └─ ProgressIndicator        — "press to advance" visual cue
```

**Input actions (existing, unchanged):**

| Input | Effect |
|-------|--------|
| `ui_accept` (Space/Enter) | Advance to next line; or if typing: skip to end of current line |
| `ui_cancel` (Esc) | Skip typewriter, show full line immediately |
| Left-click on balloon | Same as `ui_accept` |

No new input actions required for MVP. All handled by the balloon internally.

---

### Dialogue Files

All dialogue content lives in `dialogue/` at project root.

```
dialogue/
├─ bosses/
│  ├─ boss_devium.dialogue
│  ├─ boss_[name_2].dialogue
│  └─ ...
```

One `.dialogue` file per boss. MVP requires one file per planned boss fight. Each file contains:
- `~ start` — main entry point (always present)
- Linear line sequence (no branches at MVP)
- `=> END` terminator

**File format (Dialogue Manager native):**

```dialogue
~ start
Devium: Hola "amigo"
Devium: Did you really think you could walk in here?
Wizard: ...
Devium: No matter. You won't leave.
=> END
```

**Character name** is the exact string used to look up the portrait texture (see Portrait Registry below). Must match registry key exactly (case-insensitive lookup at display time).

**No branching at MVP.** Every dialogue file is a single linear sequence from `~ start` to `=> END`. The addon supports branching and choices — those are post-MVP features once writer and narrative arc are further along.

---

### Portrait Registry

`example_balloon.gd` currently has a hard-coded `if character == "devium"` check. Replace with a dictionary:

```gdscript
const PORTRAIT_REGISTRY: Dictionary = {
    "devium": "res://assets/sprites/bosses/boss_devium_portrait.png",
    # "wizard": "res://assets/sprites/player/wizard_portrait.png",
    # add entries per character — no code change needed for new characters
}
```

Display logic (replace existing hard-code):
```gdscript
var portrait_path: String = PORTRAIT_REGISTRY.get(
    dialogue_line.character.to_lower(), ""
)
portrait.visible   = portrait_path != ""
portrait.texture   = load(portrait_path) if portrait_path != "" else null
```

Portrait image spec: **128×128 px**, transparent background, face framed in lower two-thirds. Same spec for all characters for consistent balloon layout.

---

### Trigger Architecture

**All MVP dialogue is triggered by the entity that owns the conversation** — boss idle states, not a central dialogue manager or room script.

Pattern (already implemented for Devium, reference for all future bosses):

```
BossIdleState._physics_process()
  → player_in_range()
  → boss.start_intro_sequence()   [guarded by _intro_started flag]
    → load dialogue resource
    → show_dialogue_balloon()
    → await balloon.tree_exited
    → register completion: GameManager.mark_dialogue_seen(dialogue_id)
    → _start_combat()
```

Two rules:
1. **Dialogue blocks combat start.** `_start_combat()` is never called before `await balloon.tree_exited`.
2. **Dialogue triggers once per playthrough.** The `_intro_started` flag prevents replay within a session. `GameManager.is_dialogue_seen(dialogue_id)` prevents replay across sessions.

---

### Dialogue State Persistence

Dialogue completion is tracked by `dialogue_id` — a unique string per sequence, matching the dialogue file stem by convention:

| Dialogue | `dialogue_id` |
|----------|--------------|
| Devium intro | `"boss_devium_intro"` |
| Future boss | `"boss_[name]_intro"` |

**GameManager additions required:**

```gdscript
var seen_dialogues: Dictionary = {}   # { dialogue_id: bool }

func mark_dialogue_seen(id: String) -> void:
    seen_dialogues[id] = true

func is_dialogue_seen(id: String) -> bool:
    return seen_dialogues.get(id, false)
```

Save payload includes `seen_dialogues` dictionary. On load: restore from save file into GameManager before any room or boss loads.

**Replay behavior:**
- If `is_dialogue_seen(dialogue_id)` returns true: skip balloon entirely, call `_start_combat()` immediately.
- This means on a second attempt after death (if checkpoint is before boss room): no dialogue replay — straight to fight. Correct. The player already heard what the boss had to say.

---

### Boss Room Integration

Every boss room that has a pre-fight dialogue must follow this scene structure:

```
BossRoom (Node2D)
├─ Boss (entity with IdleState)
│     @export var dialogue_id: String = "boss_devium_intro"
│     @export var dialogue_file: String = "res://dialogue/bosses/boss_devium.dialogue"
└─ CombatBarrier (combat_barrier.gd)
```

Boss script exposes `dialogue_id` and `dialogue_file` as `@export` — no hardcoded paths in boss script logic. Level designers assign the correct file per boss scene in the inspector.

---

### Input Blocking During Dialogue

While the balloon is open:
- Player movement input must be suppressed.
- Player spell input must be suppressed.
- Boss AI must be paused (velocity = Vector2.ZERO, HSM tick halted or states ignore input).

Implementation: `DialogueManager.dialogue_started` signal → game sets `GameManager.dialogue_active = true`. Player script checks this flag in `_physics_process` and skips input handling. Boss HSM's `_enter()` on IntroState halts movement.

`dialogue_active` clears on `DialogueManager.dialogue_ended` signal.

---

### Typewriter Timing

Default DialogueLabel settings (no change from addon defaults unless playtesting reveals friction):

| Parameter | Value | Notes |
|-----------|-------|-------|
| `seconds_per_step` | 0.02 s | 50 chars/sec — fast enough to not feel slow, readable |
| `seconds_per_pause_step` | 0.3 s | Pause at `.?!` for dramatic beat |
| Typing skip | `ui_cancel` | Shows full line immediately |
| Advance | `ui_accept` | If typing: skip to end. If done: next line. |

No auto-advance at MVP (no `time:` tag on dialogue lines). Every line requires player input to advance — enforces that the player reads each line.

## Formulas

### Approximate Dialogue Duration

```
T_line = (char_count × seconds_per_step) + (punctuation_count × seconds_per_pause_step)
       + player_read_time (estimated 1.5–3.0 s per line)

Example (20 chars, 1 punctuation mark):
  T_line = (20 × 0.02) + (1 × 0.3) + 2.0
         = 0.4 + 0.3 + 2.0 = 2.7 s per line

Target: 4–8 lines per boss intro = 10–22 s total pre-fight sequence.
Design cap: 8 lines max per boss intro at MVP. Beyond 8: pacing study required.
```

### Variable Definitions

| Variable | Default | Description |
|----------|---------|-------------|
| `seconds_per_step` | 0.02 s | Typewriter speed per character |
| `seconds_per_pause_step` | 0.3 s | Pause at punctuation `.?!` |
| `dialogue_id` | per-boss string | Unique ID for persistence tracking |
| Max lines per intro | 8 | Design cap — enforces tight writing |
| Portrait size | 128×128 px | Standard portrait spec |

## Edge Cases

**EC-01 — Player reaches boss room after loading a save where dialogue already seen.**
`is_dialogue_seen(dialogue_id)` returns true → IdleState skips balloon, calls `_start_combat()` directly. Player enters fight immediately. Correct.

**EC-02 — DialogueManager singleton missing.**
Existing fallback in `devium.gd` (`_get_dialogue_manager()`) instantiates it manually if not found. Pattern must be replicated or refactored into a shared utility. No crash.

**EC-03 — Dialogue file path wrong or missing.**
`load()` returns null → `show_dialogue_balloon(null)` → addon may error. Guard: `assert(resource != null, "Dialogue file not found: " + dialogue_file)`. Fail loud in dev; in ship build, skip dialogue and start combat (fail-safe).

**EC-04 — Player pauses game mid-dialogue.**
Pause menu opens. `DialogueLabel` is a `CanvasLayer` — continues rendering. If pause freezes `_process`: typewriter halts. Resumed on unpause. No text is lost — `DialogueLabel` resumes from current character index. No guard needed.

**EC-05 — Player dies mid-dialogue (e.g., a lingering DoT).**
Player receives death signal. `player_died` dispatches `&"die"`. Death animation starts. Balloon is still open. Conflict: death sequence vs. dialogue await.

Rule: **dialogue sets `dialogue_active = true`; Health System must check `dialogue_active` before emitting `player_died`** — damage still applies, but death is deferred until balloon exits. Alternative: grant invulnerability during dialogue. MVP decision: **grant full invulnerability during `dialogue_active`** — simpler, no death-mid-cutscene edge case.

**EC-06 — Character name not in PORTRAIT_REGISTRY.**
`PORTRAIT_REGISTRY.get(name, "")` returns `""`. Portrait hidden. Character name label still shows. No crash. Correct for nameless characters or enemies without portraits.

**EC-07 — seen_dialogues not in save file (old save format).**
`SaveManager` restores `seen_dialogues = {}` (empty dict) as default. All dialogues appear unseen. Player re-watches boss intro on first encounter after upgrade. Minor annoyance — acceptable for MVP save format migration.

**EC-08 — Balloon closed by code (queue_free) before player finishes reading.**
`await balloon.tree_exited` resolves. `_start_combat()` fires. If balloon was force-closed mid-line, partial dialogue was shown. Only happens if external code calls `balloon.queue_free()` — document that no external code should close the balloon. Balloon closes itself on `=> END`.

**EC-09 — Two bosses in same room (future scenario).**
Not in MVP scope. One boss per room rule at MVP. No handling required.

**EC-10 — `dialogue_active` flag not cleared if balloon errors out.**
If balloon exits via error instead of `=> END`, `dialogue_ended` signal may not fire. `dialogue_active` stays true — player input permanently blocked. Guard: `dialogue_active = false` in `_on_dialogue_ended()` AND in DeathState. Belt-and-suspenders.

## Dependencies

| System | Direction | What this system needs |
|--------|-----------|----------------------|
| **Zone/Room System** | Owned by | Dialogue triggers live in boss room scenes; room structure determines when trigger fires |
| **Input System** | Blocks | `dialogue_active = true` suppresses player input during balloon. Input System (or player script) must check this flag |
| **Save/Load System** | Sends to | `seen_dialogues` dictionary must be included in save payload; restored on load |
| **Enemy Base / Boss System** | Consumer | Boss idle states own the trigger; Boss System GDD will reference this pattern |
| **Health System** | Constraint | No death events while `dialogue_active = true` — invulnerability during dialogue |
| **Dialogue Manager addon** | Requires | `addons/dialogue_manager/` must remain in project; all balloon UI and line management is addon-owned |

**Reverse dependencies:**
- Boss System: every boss with pre-fight dialogue follows the trigger pattern defined here.
- Save/Load System: must include `seen_dialogues` in its save schema.
- HUD System: must hide/suppress HUD elements while `dialogue_active` is true (dialogue is full-attention).

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `seconds_per_step` | 0.02 s | 0.01–0.05 s | 0.01: near-instant (no typewriter feel). 0.05: slow (frustrating for long lines). 0.02 is the sweet spot. |
| `seconds_per_pause_step` | 0.3 s | 0.1–0.8 s | Punctuation beat. 0.1: punchy. 0.8: dramatic pause. Adjust per boss personality. |
| Max lines per intro | 8 | 4–12 | Below 4: insufficient story beat. Above 12: player checks out before fight. 6–8 is ideal. |
| Portrait size | 128×128 px | 96–192 px | Changing this requires balloon layout adjustment. Stick to 128×128 for all characters. |
| Invulnerability during dialogue | true | true/false | false: player can die mid-cutscene (EC-05). Keep true at MVP. Revisit if abuse found. |

## Acceptance Criteria

**AC-01 — Devium intro plays on first encounter.**
Player enters Devium's room. When within 200 units, balloon appears. Devium's portrait shows. Text typewriters in. Player presses `ui_accept` to advance through all lines. On final `=> END`, balloon closes and combat starts. Verified by: fresh game state, enter boss room.

**AC-02 — Devium intro does not replay on second encounter.**
Player fights Devium, dies, respawns, re-enters boss room. Balloon does NOT appear. Combat starts immediately. `GameManager.is_dialogue_seen("boss_devium_intro")` returns true. Verified by: die and re-enter boss room.

**AC-03 — Typewriter effect and skip.**
While text is typewriting, pressing `ui_cancel` reveals full line instantly. Pressing `ui_accept` before typewriter completes also skips to end. Pressing `ui_accept` after line is complete advances to next line. Verified by: interact with each input during typewriter.

**AC-04 — Player input suppressed during dialogue.**
While balloon is open, player movement, jumping, and spell casting are all disabled. Player character does not move. Verified by: hold directional input during dialogue, confirm no movement.

**AC-05 — Player invulnerable during dialogue.**
A hazard overlapping the player position deals no damage while `dialogue_active = true`. Health bar does not change during dialogue. Verified by: position player on active DamageZone, trigger dialogue, confirm no damage.

**AC-06 — Portrait registry lookup.**
Character named `"Devium"` (any casing) shows boss portrait texture. Character named anything not in registry shows no portrait and no broken texture — just the character name label. Verified by: trigger Devium dialogue, verify portrait shows; author test dialogue with unknown character, verify no portrait shown.

**AC-07 — Dialogue file external (not inline).**
Devium's dialogue content loads from `res://dialogue/bosses/boss_devium.dialogue`, not from `INTRO_DIALOGUE_TEXT` constant. Text is editable in the file without touching `devium.gd`. Verified by: edit boss_devium.dialogue, reload, confirm changed text appears in-game.

**AC-08 — dialogue_id exported per boss.**
Devium scene has `dialogue_id = "boss_devium_intro"` and `dialogue_file = "res://dialogue/bosses/boss_devium.dialogue"` set as `@export` in inspector. No hardcoded strings in `devium.gd` logic. Verified by: inspect Devium scene exports.

**AC-09 — seen_dialogues persists across sessions.**
Player sees Devium intro, game saves (checkpoint activation). Player closes game, reopens. Re-enters Devium room. Intro does not replay. `seen_dialogues["boss_devium_intro"] = true` restored from save. *(Blocked until SaveManager.save_game() implemented.)*

**AC-10 — dialogue_active clears on balloon exit.**
After balloon closes (normal end or error), `GameManager.dialogue_active = false`. Player input resumes. Movement and spells function normally. Verified by: complete dialogue sequence, confirm player can move immediately after.
