# HUD System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-04
> **Implements Pillar**: Controlled Ascension (clarity of earned power), Spell Alchemy (spell state readability)

## Overview

The HUD System owns all persistent player-facing information displayed during gameplay: the health pip row, mana bar, spell slot display with cooldown overlays, boss health bar, and transient notification toasts. It reads exclusively from signals — it never polls game state directly. Every HUD element is a subscriber, not an inspector.

Six signal sources feed the HUD:

| Source | Signals consumed |
|--------|-----------------|
| Health System | `health_changed(current, max)` |
| Spell System | `mana_changed(current, max)`, `attack_cooldown_changed(remaining, total)` |
| Spell Slot System | `active_spell_changed(spell)`, `slot_unlocked(count)`, `loadout_changed(slots)` |
| Boss System | `boss_appeared(id, name, max_hp)`, `boss_health_changed(current, max)`, `boss_defeated(id)` |
| Material System | `material_collected(type, amount, new_total)` |
| Spell Upgrade System | `upgrade_applied(spell_id, new_tier)` |

The HUD does not own damage numbers (spawned by Enemy Base System at enemy position), upgrade UI (opened by Upgrade Shrine), loadout screen (pause menu), or any in-world UI elements. It owns only the persistent overlay that is always visible during play.

**Display elements:**

1. **Health pips** — integer display of `current_health / max_health` using filled/empty pip sprites
2. **Mana bar** — linear fill bar for `current_mana / MAX_MANA`; color shifts at low mana
3. **Spell slot row** — 1–5 slot frames, spell icon per slot, cooldown radial overlay on active slot
4. **Boss health bar** — shown only during boss fight; hides on defeat or player death
5. **Material toast** — brief pickup notification (fades after 2s)
6. **Upgrade toast** — brief upgrade confirmation (fades after 2.5s)

At MVP, one spell slot is shown. The slot row is the migration target for the existing hardcoded `_fireball_portrait` in `hud.gd`.

## Player Fantasy

The best HUD is the one the player stops noticing.

Information should register without demanding attention. The health pips are in the corner — the player sees them without looking. The mana bar is there when it matters (one cast left, bar tinting amber) and invisible when it doesn't. The spell icon is a reminder, not a tutorial. None of this competes with the world.

When something changes, the change earns a moment: picking up Frost Crystals, the toast confirms the pickup without stopping play. Upgrading Ice Shard to Tier 2 — a brief confirmation, then back to the fight. The wizard does not celebrate upgrades; he acknowledges them.

The boss health bar is the exception. It is meant to be seen. It carries a name. It frames the encounter as a confrontation between two specific people, not a player emptying a pool. When it drains past 60%, something should feel different — the bar alone communicates that the fight has entered a new phase even before the animation plays.

**The HUD should feel like the wizard's awareness, not a scoreboard.** Every element is present because it answers a question the player will actually ask in the heat of play: *how much have I got left? can I cast? is this fight almost over?* Nothing else belongs here.

## Detailed Design

### HUD Scene Structure

```
HUD (CanvasLayer, layer = 10)
├─ TopLeft (MarginContainer)
│   ├─ HealthRow (HBoxContainer)
│   │   └─ [HealthPip × max_health] (TextureRect)
│   └─ ManaBarContainer (VBoxContainer)
│       ├─ ManaBar (TextureProgressBar)
│       └─ ManaLabel (Label)          -- hidden at MVP; "25 / 100" debug only
├─ BottomCenter (MarginContainer)
│   └─ SpellSlotRow (HBoxContainer)
│       └─ [SpellSlotFrame × slot_count] (Panel)
│           ├─ SpellIcon (TextureRect)
│           ├─ CooldownOverlay (TextureProgressBar, radial fill)
│           └─ ActiveBorder (Panel)   -- visible only on active slot
├─ TopCenter (MarginContainer)
│   └─ BossBarContainer (VBoxContainer, hidden by default)
│       ├─ BossNameLabel (Label)
│       └─ BossHealthBar (TextureProgressBar)
└─ ToastStack (VBoxContainer, anchored top-right)
    └─ [ToastEntry] (Label, spawned dynamically)
```

`hud.gd` connects all signals in `_ready()`. No polling — every update is event-driven.

---

### Health Pips

Pip count = `max_health`. Each pip is a `TextureRect`. Filled pip = health present. Empty pip = damage taken.

```gdscript
# hud.gd
@onready var _health_row: HBoxContainer = $TopLeft/HealthRow
const PIP_SCENE := preload("res://scenes/ui/health_pip.tscn")

func _on_health_changed(current: int, maximum: int) -> void:
    # Rebuild pip row if max changed
    if _health_row.get_child_count() != maximum:
        for c in _health_row.get_children(): c.queue_free()
        for i in maximum:
            _health_row.add_child(PIP_SCENE.instantiate())
    # Fill/empty based on current
    for i in maximum:
        _health_row.get_child(i).set_filled(i < current)
```

`HealthPip` scene: `TextureRect` with two textures — `filled` and `empty`. `set_filled(bool)` swaps texture.

Pip size: 8×8 px. Gap: 2 px. Max row width at 14 HP: `(8 + 2) × 14 - 2 = 138 px`. Fits top-left at any target resolution.

---

### Mana Bar

Linear `TextureProgressBar`. Fills left-to-right. Value = `current_mana / MAX_MANA`.

```gdscript
@onready var _mana_bar: TextureProgressBar = $TopLeft/ManaBarContainer/ManaBar
const MANA_COLOR_FULL:    Color = Color(0.3, 0.5, 1.0, 1.0)   # blue
const MANA_COLOR_LOW:     Color = Color(1.0, 0.6, 0.1, 1.0)   # amber
const MANA_LOW_THRESHOLD: float = 25.0   # one default cast remaining

func _on_mana_changed(current: float, maximum: float) -> void:
    _mana_bar.value = current / maximum
    _mana_bar.tint_progress = MANA_COLOR_LOW if current <= MANA_LOW_THRESHOLD else MANA_COLOR_FULL
```

Bar dimensions: 64×6 px. Sits below health pip row, left-aligned. No numeric label in shipped build.

---

### Spell Slot Row

Dynamic row of 1–5 `SpellSlotFrame` scenes. Rebuilt when `slot_unlocked` fires.

```gdscript
@onready var _slot_row: HBoxContainer = $BottomCenter/SpellSlotRow
const SLOT_SCENE := preload("res://scenes/ui/spell_slot_frame.tscn")

func _rebuild_slots(count: int, slots: Array) -> void:
    for c in _slot_row.get_children(): c.queue_free()
    for i in count:
        var frame: SpellSlotFrame = SLOT_SCENE.instantiate()
        frame.set_spell(slots[i])   # null = empty frame
        _slot_row.add_child(frame)

func _on_active_spell_changed(spell: SpellResource) -> void:
    var idx := SpellSlotSystem.active_index
    for i in _slot_row.get_child_count():
        _slot_row.get_child(i).set_active(i == idx)

func _on_attack_cooldown_changed(remaining: float, total: float) -> void:
    var active_frame := _slot_row.get_child(SpellSlotSystem.active_index)
    if active_frame:
        active_frame.set_cooldown(remaining / total)   # 0.0 = ready, 1.0 = just cast
```

`SpellSlotFrame` scene:

```
SpellSlotFrame (Panel, 32×32 px)
├─ SpellIcon (TextureRect, 24×24 px, centered)
├─ CooldownOverlay (TextureProgressBar, radial clockwise, 32×32 px)
│   -- value: 0.0 = full (hidden), 1.0 = dark overlay covering icon
└─ ActiveBorder (StyleBoxFlat or NinePatchRect)
   -- visible only when set_active(true)
```

Empty slot: `SpellIcon` shows `null_spell_icon.png` (dim placeholder). No cooldown overlay on empty slots.

---

### Boss Health Bar

Hidden until the boss fight begins. Shows boss name + health bar. Anchored top-center.

**Deferral rule**: `boss_appeared` fires before the boss pre-fight dialogue. The bar must NOT reveal immediately — it reveals only after `dialogue_ended` fires (or immediately if no dialogue is active). This prevents the bar from floating over the dim dialogue overlay.

**Reveal animation**: 0.5s fade-in tween on `modulate.a` from 0.0 → 1.0 (`BOSS_BAR_REVEAL_DURATION = 0.5`).

```gdscript
@onready var _boss_bar_container: VBoxContainer      = $TopCenter/BossBarContainer
@onready var _boss_name_label:    Label              = $TopCenter/BossBarContainer/BossNameLabel
@onready var _boss_health_bar:    TextureProgressBar = $TopCenter/BossBarContainer/BossHealthBar

const BOSS_BAR_REVEAL_DURATION := 0.5

var _boss_bar_pending := false   # true when boss_appeared received but dialogue active

func _on_boss_appeared(_id: StringName, display_name: String, max_hp: int) -> void:
    _boss_name_label.text  = display_name
    _boss_health_bar.value = 1.0
    if GameManager.dialogue_active:
        _boss_bar_pending = true   # defer until dialogue_ended
    else:
        _reveal_boss_bar()

func _reveal_boss_bar() -> void:
    _boss_bar_pending = false
    _boss_bar_container.modulate.a = 0.0
    _boss_bar_container.show()
    create_tween().tween_property(_boss_bar_container, "modulate:a", 1.0, BOSS_BAR_REVEAL_DURATION)

func _on_dialogue_ended() -> void:
    if _boss_bar_pending:
        _reveal_boss_bar()

func _on_boss_health_changed(current: int, maximum: int) -> void:
    _boss_health_bar.value = float(current) / float(maximum)

func _on_boss_defeated(_id: StringName) -> void:
    _boss_bar_pending = false
    _boss_bar_container.hide()

func _on_player_died() -> void:
    _boss_bar_pending = false
    _boss_bar_container.hide()
```

Bar dimensions: 240×10 px. Boss name label: centered above bar, 14pt, bold. Bar color: element-tinted (set from `BossConfig.element` on `boss_appeared`).

### Dialogue Suppression

During `GameManager.dialogue_active`, the HUD hides the gameplay elements that are visually disruptive behind the dialogue overlay. The boss bar is suppressed via the deferral rule above. Health pips, mana bar, and spell slots remain visible — they are anchored to the HUD CanvasLayer (layer 10) which sits above the dialogue dim overlay (layer 5). No explicit hide/show on those elements during dialogue at MVP; they are covered by the overlay visually.

If full HUD suppression is needed in a future pass, connect to `GameManager.dialogue_started/dialogue_ended` and toggle `_health_row.visible`, `_mana_bar.visible`, and `_slot_row.visible`.

---

### Material Toast

Fires on `GameManager.material_collected`. Brief label appears top-right, fades after 2.0s.

```gdscript
const MATERIAL_NAMES: Dictionary = {
    &"ember":      "Ember",
    &"frost":      "Frost Crystal",
    &"radiance":   "Radiance",
    &"void_shard": "Void Shard",
    &"aether":     "Aether",
    &"shatter":    "Shatter",
}

func _on_material_collected(type: StringName, amount: int, _new_total: int) -> void:
    _spawn_toast("+%d %s" % [amount, MATERIAL_NAMES.get(type, str(type))])

func _spawn_toast(text: String) -> void:
    var label := Label.new()
    label.text = text
    label.add_theme_color_override("font_color", Color.WHITE)
    _toast_stack.add_child(label)
    var tween := label.create_tween()
    tween.tween_interval(1.5)
    tween.tween_property(label, "modulate:a", 0.0, 0.5)
    tween.tween_callback(label.queue_free)
```

Multiple toasts stack vertically. Each 2.0s total (1.5s solid + 0.5s fade). No cap on simultaneous toasts — in practice ≤3 materials collected in quick succession.

---

### Upgrade Toast

Fires on `GameManager.upgrade_applied`. Same toast mechanism, 2.5s duration.

```gdscript
func _on_upgrade_applied(spell_id: StringName, new_tier: int) -> void:
    var spell_name := _get_spell_display_name(spell_id)
    _spawn_toast_timed("%s → Tier %d" % [spell_name, new_tier], 2.5)
```

Upgrade toasts appear in the same `_toast_stack`. No visual distinction from material toasts at MVP.

---

### Signal Connections (complete list)

```gdscript
func _ready() -> void:
    GameManager.health_changed.connect(_on_health_changed)
    GameManager.mana_changed.connect(_on_mana_changed)
    GameManager.attack_cooldown_changed.connect(_on_attack_cooldown_changed)
    SpellSlotSystem.active_spell_changed.connect(_on_active_spell_changed)
    SpellSlotSystem.slot_unlocked.connect(_on_slot_unlocked)
    SpellSlotSystem.loadout_changed.connect(_on_loadout_changed)
    GameManager.boss_appeared.connect(_on_boss_appeared)
    GameManager.boss_health_changed.connect(_on_boss_health_changed)
    GameManager.boss_defeated.connect(_on_boss_defeated)
    GameManager.player_died.connect(_on_player_died)
    GameManager.dialogue_ended.connect(_on_dialogue_ended)
    GameManager.material_collected.connect(_on_material_collected)
    GameManager.upgrade_applied.connect(_on_upgrade_applied)
    _sync_initial_state()

func _sync_initial_state() -> void:
    _on_health_changed(GameManager.current_health, GameManager.max_health)
    _on_mana_changed(GameManager.current_mana, 100.0)
    _rebuild_slots(SpellSlotSystem.slot_count, SpellSlotSystem.slots)
```

## Formulas

### Health Pip Fill Ratio

```
filled_pips = current_health
empty_pips  = max_health - current_health
total_pips  = max_health

pip_row_width = (PIP_SIZE + PIP_GAP) × max_health - PIP_GAP
             = (8 + 2) × 14 - 2 = 138 px   (at max health 14)
             = (8 + 2) × 6  - 2 = 58 px    (at base health 6)
```

### Mana Bar Fill

```
bar_fill = current_mana / MAX_MANA        -- range [0.0, 1.0]
low_mana = current_mana <= MANA_LOW_THRESHOLD (25.0)

-- Color transitions instantly (no lerp) to avoid misleading the player
-- about available casts during rapid state changes
```

### Cooldown Overlay Fill

```
overlay_fill = remaining_cooldown / ATTACK_COOLDOWN   -- range [0.0, 1.0]
-- 1.0 = just cast (full dark overlay)
-- 0.0 = ready (overlay invisible)
-- Radial fill drains clockwise as cooldown expires
```

### Boss Bar Fill

```
bar_fill = float(current_hp) / float(max_hp)   -- range [0.0, 1.0]
-- No lerp — instant update on each boss_health_changed signal
-- Phase 2 threshold at 0.6 has no explicit visual marker at MVP
--   (polish: add notch mark at 60% bar position)
```

### Toast Timing

```
toast_total_duration  = solid_duration + fade_duration
material toast:         1.5s solid + 0.5s fade = 2.0s total
upgrade toast:          2.0s solid + 0.5s fade = 2.5s total

-- Stacking: each toast occupies one row in ToastStack
-- VBoxContainer auto-positions; oldest toast at top, newest at bottom
```

### Variable Definitions

| Variable | Value | Description |
|----------|-------|-------------|
| `PIP_SIZE` | 8 px | Health pip width and height |
| `PIP_GAP` | 2 px | Space between pips |
| `MANA_LOW_THRESHOLD` | 25.0 | Mana below which bar turns amber |
| `MANA_COLOR_FULL` | `Color(0.3,0.5,1.0)` | Bar color at normal mana |
| `MANA_COLOR_LOW` | `Color(1.0,0.6,0.1)` | Bar color at low mana |
| Mana bar size | 64×6 px | Display dimensions |
| Slot frame size | 32×32 px | Per-slot icon frame |
| Boss bar size | 240×10 px | Boss health bar dimensions |
| Material toast duration | 2.0s | Total visible time |
| Upgrade toast duration | 2.5s | Total visible time |

## Edge Cases

**EC-01 — `health_changed` fires with `maximum` different from pip count.**
Pip row child count checked against `maximum` each call. If different: full rebuild. Handles max HP upgrades cleanly — pips added without manual tracking.

**EC-02 — `health_changed` fires before HUD `_ready()` completes.**
`_sync_initial_state()` called at end of `_ready()` pulls current values. Any signal fired before `_ready()` is missed; sync call covers it. No visual lag on first frame.

**EC-03 — `active_spell_changed` fires with `null` spell.**
`SpellSlotFrame.set_spell(null)` shows placeholder icon, no crash. Cooldown overlay hidden on null slot. Active border still drawn — slot is active but empty.

**EC-04 — `attack_cooldown_changed` fires when slot row is empty.**
`_slot_row.get_child(active_index)` returns null. Guard: `if active_frame:` — no-op. No crash.

**EC-05 — `slot_unlocked` fires mid-combat.**
`_rebuild_slots()` queues_free all existing frames and recreates. Single-frame visual stutter acceptable — slot unlocks never happen mid-fight at MVP (story-triggered only).

**EC-06 — `boss_appeared` fires when boss bar already visible.**
`_boss_bar_container` already shown — `show()` idempotent. Name and max HP overwrite. No duplicate bar.

**EC-07 — `player_died` fires outside boss fight.**
`_boss_bar_container.hide()` on already-hidden container — idempotent, no crash.

**EC-08 — Multiple material pickups in rapid succession.**
Each fires `_spawn_toast()` independently. Toast stack fills vertically. Toasts free themselves via tween callback — no memory leak. Visual crowding possible if >5 toasts stack; acceptable at MVP.

**EC-09 — `upgrade_applied` fires while upgrade UI is still open.**
Toast spawns behind the upgrade UI (separate CanvasLayer above HUD). Upgrade UI closes, toast visible for remaining duration. No conflict.

**EC-10 — HUD loads before GameManager signals are available.**
All signals connected in `_ready()`. Godot autoloads initialize before scene nodes — GameManager always ready before HUD `_ready()`. No null signal target.

## Dependencies

| System | Direction | What this system needs |
|--------|-----------|----------------------|
| **Health System** | Subscribes | `GameManager.health_changed(current, max)` — drives pip row |
| **Spell System** | Subscribes | `GameManager.mana_changed`, `GameManager.attack_cooldown_changed` — drives mana bar and cooldown overlay |
| **Spell Slot System** | Subscribes | `active_spell_changed`, `slot_unlocked`, `loadout_changed` — drives slot row |
| **Boss System** | Subscribes | `boss_appeared`, `boss_health_changed`, `boss_defeated` — drives boss bar |
| **Material System** | Subscribes | `GameManager.material_collected` — drives material toast |
| **Spell Upgrade System** | Subscribes | `GameManager.upgrade_applied` — drives upgrade toast |
| **GameManager** | Reads initial state | `current_health`, `max_health`, `current_mana` for `_sync_initial_state()` on load |

**Reverse dependencies:** none. HUD is a pure subscriber — no other system reads from it.

**Hard blockers:**
- `GameManager` signals: `health_changed`, `mana_changed`, `attack_cooldown_changed`, `material_collected`, `upgrade_applied`, `boss_appeared`, `boss_health_changed`, `boss_defeated`, `player_died`
- `SpellSlotSystem` autoload with `active_spell_changed`, `slot_unlocked`, `loadout_changed` signals
- `SpellResource.icon: Texture2D` populated on all spell `.tres` files
- `HealthPip` and `SpellSlotFrame` scenes created

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `PIP_SIZE` | 8 px | 6–12 px | Below 6: hard to read at distance. Above 12: pips dominate screen corner. |
| `PIP_GAP` | 2 px | 1–4 px | Below 1: pips merge visually. Above 4: row too wide at 14 HP. |
| `MANA_LOW_THRESHOLD` | 25.0 | 15–40 | Color shift trigger. At 25: one default cast remaining — correct urgency cue. Below 15: too late. Above 40: false alarm (two casts still available). |
| `MANA_COLOR_LOW` | Amber `(1.0,0.6,0.1)` | any warm color | Must contrast with blue full-mana color. Avoid red — confusion with health. |
| Material toast solid duration | 1.5s | 0.8–3.0s | Below 0.8: barely readable mid-action. Above 3.0: toasts pile up in extended combat. |
| Upgrade toast solid duration | 2.0s | 1.5–4.0s | Longer than material toast — upgrade is a higher-stakes event. |
| Boss bar width | 240 px | 160–320 px | At 160: name text may overflow on long names. At 320: bar spans most of screen. |
| Slot frame size | 32×32 px | 24–48 px | Below 24: cooldown radial unreadable. Above 48: slots dominate bottom of screen. |

## Acceptance Criteria

**AC-01 — Health pips reflect current HP on load.**
Load game with `current_health = 4`, `max_health = 6`. HUD shows 6 pips: 4 filled, 2 empty. Verified by: load save, inspect pip row.

**AC-02 — Pip row rebuilds on max HP increase.**
6 pips shown. `health_changed(8, 8)` fires. Pip row shows 8 pips, all filled. Old nodes freed. Verified by: trigger HP upgrade, confirm row count and fill.

**AC-03 — Mana bar drains on cast.**
Full mana (100). Cast once. Bar at 75% immediately. Verified by: cast, confirm bar fill.

**AC-04 — Mana bar turns amber at low mana.**
Mana at 26 — bar blue. Cast once (25 cost) → mana at 1. Bar turns amber. Regen to 26 — bar turns blue. Verified by: drain and refill cycle, confirm color transitions.

**AC-05 — Cooldown overlay drains correctly.**
Cast spell. Overlay full (dark). Over 1.5s, overlay drains to empty. Verified by: cast, watch overlay drain, confirm timing matches `ATTACK_COOLDOWN`.

**AC-06 — Active slot border updates on cycle.**
Slot 0 active (border on). Cycle forward. Border moves to slot 1. Slot 0 border hidden. Verified by: cycle, confirm border position.

**AC-07 — Slot row expands on slot unlock.**
1 frame shown. `slot_unlocked(2)` fires. 2 frames shown. Second frame empty (placeholder icon). Verified by: trigger unlock, confirm frame count.

**AC-08 — Boss bar appears on fight start.**
Enter Devium room. `boss_appeared` fires. Boss bar visible, labeled "Devium", at 100% fill. Verified by: enter boss room, confirm bar.

**AC-09 — Boss bar drains with boss HP.**
Deal 20 damage to Devium. Bar at 90% (180/200). Verified by: track bar fill against known damage.

**AC-10 — Boss bar hides on defeat.**
`boss_defeated` fires. Bar container hidden within one frame. Verified by: defeat Devium, confirm bar gone.

**AC-11 — Boss bar hides on player death.**
`player_died` fires during fight. Bar hidden. Verified by: die mid-fight, confirm bar disappears.

**AC-12 — Material toast appears on pickup.**
Collect 1 Frost Crystal. Toast "+1 Frost Crystal" appears top-right. Visible ~1.5s, fades 0.5s, freed. Verified by: collect material, observe lifecycle.

**AC-13 — Multiple toasts stack without overlap.**
Collect 3 different materials quickly. Three toasts stack vertically, no overlap, each fades independently. Verified by: multi-collect, inspect stack.

**AC-14 — Upgrade toast appears on upgrade.**
Purchase Fireball T1. Toast "Fireball → Tier 1" appears, visible ~2.0s. Verified by: purchase, confirm text and duration.

**AC-15 — HUD reflects save state on load without signal replay.**
Load save: 3/6 HP, 50 mana, Fireball in slot 0. HUD immediately shows 3 filled + 3 empty pips, mana bar at 50%, Fireball icon. No actions required. Verified by: load save, inspect HUD immediately.
