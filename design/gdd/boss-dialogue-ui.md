# Boss Dialogue UI

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-05
> **Implements Pillar**: Earned Truth (visual delivery of the pre-fight moment)

## Overview

The Boss Dialogue UI is the Presentation Layer system that owns the visual execution of boss pre-fight dialogue sequences. It replaces the Dialogue Manager addon's default `ExampleBalloon` with `WizrlessBossBalloon` — a custom balloon scene with Wizrless visual design — and adds surrounding theatrical elements: a full-screen dim overlay and HUD suppression that transforms the game screen into a focused confrontation space.

Mechanics live in the Dialogue System. This system owns only what the player sees: how the balloon looks, how it enters and exits, what the screen does while the balloon is open.

Three responsibilities:

1. **Custom balloon scene** (`WizrlessBossBalloon.tscn`) — panel style, portrait frame, speaker name styling, text area layout
2. **Dim overlay** — semi-transparent full-screen panel behind balloon; creates visual focus without removing world context
3. **HUD coordination** — suppress HUD elements during dialogue; restore HUD and reveal boss health bar on exit

The Dialogue System GDD already specifies input handling, typewriter timing, portrait registry, trigger architecture, and persistence. This GDD specifies nothing in those domains. It specifies only the presentation layer wrapping them.

## Player Fantasy

The dialogue balloon should feel like the world narrowed.

Not that the game paused. That the wizard stopped walking and something in the room demanded his attention. The background dims — just enough that the room blurs behind the words. The balloon does not arrive as a popup. It rises from the bottom edge, unhurried. The boss's name appears before their first word does.

When the boss speaks, the presentation must carry the weight the words carry. If the writing says this person is dangerous, the balloon should not feel like a chat bubble. It should feel like a warning being read by someone who does not fully understand it yet.

The exit matters equally. The balloon descends. The dim fades. The HUD returns. The boss health bar appears — and its presence tells the player: what was a conversation is now a fight. This visual sequence choreographs the player's commitment to the encounter. The transition is the threshold.

## Detailed Design

### Custom Balloon Scene

`WizrlessBossBalloon.tscn` is a Dialogue Manager v2 custom balloon. It replaces `ExampleBalloon`. BossIdleState calls:

```gdscript
const BOSS_BALLOON := preload("res://ui/dialogue/wizrless_boss_balloon.tscn")

var balloon := DialogueManager.show_dialogue_balloon_scene(
    BOSS_BALLOON, resource, &"start"
)
await balloon.tree_exited
```

This is the only change required to Devium's existing dialogue trigger: `show_dialogue_balloon` → `show_dialogue_balloon_scene` with `BOSS_BALLOON` as the first argument.

The balloon is a `CanvasLayer` (layer = 5): above gameplay (layer 0), below HUD (layer 10).

**Scene structure:**

```
WizrlessBossBalloon (CanvasLayer, layer = 5)
└─ BalloonRoot (Control, anchor: full_rect)
   ├─ DimOverlay (ColorRect)
   │   # anchor: full_rect | Color(0, 0, 0, 0) at start — animated to 0.55
   └─ BalloonPanel (PanelContainer)
      # anchor: bottom-left / bottom-right stretch
      # offset_top: -160px, offset_bottom: -40px, offset_left: 40px, offset_right: -40px
      # StyleBoxFlat: bg #0D0D1A | border 2px #4A90D9 | corner_radius 6
      # position.y = +80 at start — animated to 0
      └─ HBoxContainer (margin: 16px all sides, separation: 16px)
         ├─ PortraitFrame (PanelContainer, custom_minimum_size: 128×128)
         │   # StyleBoxFlat: bg #1A1A2E | border 1px #4A90D9
         │   └─ Portrait (TextureRect, expand: FIT_HEIGHT_PROPORTIONAL, stretch_mode: KEEP_ASPECT)
         └─ TextArea (VBoxContainer, size_flags_horizontal: EXPAND_FILL)
             ├─ SpeakerLabel (Label)
             │   # uppercase: true | font_size: 18 | font_color: #E8D5A3
             ├─ Separator (HSeparator, custom_minimum_size: 0×4)
             └─ DialogueLabel (DialogueLabel)
                 # font_size: 14 | font_color: #D0D0E0 | line_spacing: 4
```

`ProgressIndicator` is an `AnimationPlayer` child of `TextArea`. It drives a blinking `Label` ("▼") visible only when the typewriter is complete and the player must press to advance. Hidden during typewriter playback.

---

### Visual States

| State | Condition | DimOverlay alpha | BalloonPanel position.y |
|-------|-----------|-----------------|------------------------|
| HIDDEN | Balloon not in scene tree | — | — |
| ENTERING | `_ready()` → tween start | 0 → 0.55 | +80 → 0 |
| ACTIVE | Tween finished | 0.55 | 0 |
| EXITING | Final line advanced | 0.55 → 0 | 0 → +80 |

**Entry tween** — fires in `_ready()`:

```gdscript
var tween := create_tween().set_parallel(true)
tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
tween.tween_property(balloon_panel, "position:y", 0.0, ENTRY_DURATION).from(80.0)
tween.tween_property(dim_overlay, "color:a", DIM_ALPHA, ENTRY_DURATION).from(0.0)
await tween.finished
can_advance = true
```

**Exit tween** — fires when final dialogue line is advanced:

```gdscript
can_advance = false
var tween := create_tween().set_parallel(true)
tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
tween.tween_property(balloon_panel, "position:y", 80.0, EXIT_DURATION).from(0.0)
tween.tween_property(dim_overlay, "color:a", 0.0, EXIT_DURATION).from(DIM_ALPHA)
await tween.finished
queue_free()
```

`queue_free()` triggers `tree_exited` → `await balloon.tree_exited` resolves in BossIdleState → `_start_combat()` fires. Combat cannot start before exit animation completes.

---

### Input Guard

`can_advance: bool = false` — toggled true when ENTERING → ACTIVE tween finishes. All input handling in `_unhandled_input()` checks `if not can_advance: return`. Prevents accidental line advance while balloon is still animating in.

---

### HUD Suppression and Boss Bar Reveal

The Dialogue System already handles `dialogue_active = true` and HUD suppression via `DialogueManager.dialogue_started` signal. Boss Dialogue UI places one additional requirement on the HUD System:

**Boss health bar deferred reveal:** `boss_appeared(id, name, max_hp)` fires when Devium spawns (before dialogue). The HUD System must not show the boss health bar while `dialogue_active == true`. When `dialogue_active` becomes false (on `DialogueManager.dialogue_ended`), HUD System shows the boss health bar with a `BOSS_BAR_REVEAL_DURATION` fade-in.

This is a HUD System implementation requirement, not a Boss Dialogue UI code responsibility. Boss Dialogue UI specifies it here because it is part of the post-dialogue visual choreography this system owns at the design level.

**Full post-dialogue sequence (ordered):**

1. Player presses `ui_accept` on final line
2. Exit tween plays (0.25 s)
3. `queue_free()` called
4. `tree_exited` fires → `await balloon.tree_exited` resolves
5. `DialogueManager.dialogue_ended` fires → `GameManager.dialogue_active = false`
6. HUD System: re-shows HealthRow, ManaBar, SpellSlotRow
7. HUD System: fades in boss health bar (0.5 s)
8. BossIdleState: `_start_combat()` fires

Steps 6–8 are concurrent. Combat begins while boss bar is fading in — acceptable, as the player is already committed.

---

### Portrait Frame

Portrait registry lookup is owned by the Dialogue System (`PORTRAIT_REGISTRY` dictionary in `WizrlessBossBalloon.gd`, replacing ExampleBalloon's hard-code). Boss Dialogue UI specifies frame behavior:

- Portrait registered: `PortraitFrame.visible = true`, `Portrait.texture = loaded texture`
- Portrait missing from registry: `PortraitFrame.visible = false`, `TextArea` expands to full balloon width via `size_flags_horizontal = EXPAND_FILL`
- Portrait texture load fails (null): `PortraitFrame.visible = false` (same as missing)

---

### Progress Indicator

`AnimationPlayer` on `ProgressIndicator` node plays a 0.4 s looping clip that alternates `Label.modulate.a` between `1.0` and `0.0`. The clip is named `"blink"`.

`DialogueLabel` emits `finished_typing` when typewriter completes. `WizrlessBossBalloon.gd` connects:

```gdscript
dialogue_label.finished_typing.connect(func(): progress_indicator.play("blink"))
```

On line advance (before next line begins): `progress_indicator.stop()`, `Label.modulate.a = 0.0`.

## Formulas

**F1 — Entry and Exit Tween Timing**

```
T_entry = ENTRY_DURATION = 0.3 s   (Tween.EASE_OUT | TRANS_CUBIC)
T_exit  = EXIT_DURATION  = 0.25 s  (Tween.EASE_IN  | TRANS_CUBIC)
```

Exit is 17% faster than entry — makes the transition into combat feel decisive rather than slow.

**F2 — Balloon Panel Geometry (1280×720 reference)**

```
panel_width  = viewport_width  - (2 × MARGIN_H) = 1280 - 80  = 1200 px
panel_height = auto (PanelContainer shrinks to content, max ~160 px with 128px portrait)
panel_bottom_offset = MARGIN_BOTTOM = 40 px from viewport bottom
```

Variables:
- `MARGIN_H` = 40 px (horizontal margin from screen edges)
- `MARGIN_BOTTOM` = 40 px (balloon bottom edge to screen bottom)
- All margins are absolute pixels. Balloon anchors horizontally — scales correctly at non-1280 widths.

**F3 — Dim Overlay Alpha**

```
DIM_ALPHA = 0.55
```

At 0.55: background remains legible (player retains world context) but balloon visually dominates. Below 0.40: balloon fights background for attention. Above 0.70: world disappears. 0.55 is the Wizrless aesthetic target — present but not void.

**F4 — Boss Bar Reveal**

```
BOSS_BAR_REVEAL_DURATION = 0.5 s   (Tween.EASE_OUT | TRANS_QUAD)
```

Applied to `boss_health_bar.modulate.a` from 0.0 → 1.0 immediately after `dialogue_ended` fires.

## Edge Cases

**E1 — Player presses ui_accept during entry animation**
`can_advance = false` while ENTERING state active. `_unhandled_input()` returns early. Input is ignored. No line advance during 0.3 s entry window.

**E2 — Player holds ui_accept through final line into exit animation**
Final line advances. Exit tween begins. `can_advance = false`. Input ignored during 0.25 s exit. `queue_free()` fires after tween. No double-advance, no crash.

**E3 — boss_appeared fires after dialogue has already started**
Not possible at MVP: BaseBoss._ready() fires (emits `boss_appeared`), then BossIdleState detects player range and triggers dialogue. `boss_appeared` always precedes `dialogue_started`. HUD System stores `boss_appeared` data; defers boss bar display until `dialogue_active` is false.

**E4 — Viewport is not 1280 px wide**
BalloonPanel anchors left/right with `MARGIN_H = 40 px` absolute offsets. At 960 px wide: panel is 880 px. At 1920 px: panel is 1840 px. Portrait remains 128×128 fixed. TextArea fills remaining width. Acceptable at all target resolutions (720p and above).

**E5 — Portrait texture null after load**
`load(path)` returns null. Rule: `portrait_frame.visible = portrait.texture != null`. Frame hidden. TextArea expands. No broken image rendered. Silent — not an in-game error, a missing asset.

**E6 — DimOverlay alpha not fully reset before queue_free**
Exit tween targets `color:a = 0.0`. `await tween.finished` guarantees tween is complete before `queue_free()`. If scene unloads mid-tween (unlikely): balloon is freed, CanvasLayer removed — no visual artifact persists because DimOverlay is a child of the CanvasLayer being freed.

**E7 — HUD System does not implement boss bar deferral**
If HUD System shows boss health bar immediately on `boss_appeared` (before this requirement is implemented), the bar appears during dialogue. Cosmetically wrong — not game-breaking. Track as HUD System implementation task blocking Boss Dialogue UI acceptance.

**E8 — Two dialogue sequences triggered in same room (future)**
Not in MVP scope. One pre-fight dialogue per boss room at MVP. No guard needed.

## Dependencies

| System | Direction | What Boss Dialogue UI needs |
|--------|-----------|---------------------------|
| Dialogue System | Wraps | `DialogueManager.show_dialogue_balloon_scene()` API; `PORTRAIT_REGISTRY` migrated to `WizrlessBossBalloon.gd`; `dialogue_started` / `dialogue_ended` signals; `GameManager.dialogue_active` flag |
| Boss System | Caller | `BossIdleState` must change `show_dialogue_balloon()` → `show_dialogue_balloon_scene(BOSS_BALLOON, ...)` — one-line change per boss idle state script |
| HUD System | Requirement placed on | Must defer boss health bar display while `dialogue_active = true`; reveal with 0.5 s fade on `dialogue_ended` |
| GameManager | Reads | `dialogue_active` (written by Dialogue System) |
| AudioSystem | None | BOSS_PREFIGHT music is triggered by BossIdleState before `show_dialogue_balloon_scene()` — AudioSystem has no dependency on this system |

**Reverse dependency:** Dialogue System GDD must note that its `ExampleBalloon` reference is superseded by `WizrlessBossBalloon` for boss sequences. `example_balloon.tscn` may remain in the project (addon-provided) but is not used by any boss trigger.

## Tuning Knobs

| Knob | Default | Safe Range | Affects |
|------|---------|------------|---------|
| `ENTRY_DURATION` | 0.3 s | 0.15–0.5 s | Balloon slide-in speed. <0.15 = abrupt; >0.5 = sluggish |
| `EXIT_DURATION` | 0.25 s | 0.15–0.4 s | Balloon slide-out speed. Intentionally slightly faster than entry. |
| `DIM_ALPHA` | 0.55 | 0.35–0.70 | Focus intensity of background dim. Lower = world competes; Higher = world disappears. |
| `BOSS_BAR_REVEAL_DURATION` | 0.5 s | 0.2–1.0 s | Boss health bar fade-in after dialogue ends. 0.2 = abrupt; 1.0 = cinematic. |
| Progress indicator blink interval | 0.4 s | 0.2–0.6 s | Speed of "▼" advance cue blink. |
| `MARGIN_H` | 40 px | 24–60 px | Balloon horizontal margin from screen edges. |
| `MARGIN_BOTTOM` | 40 px | 24–60 px | Balloon distance from screen bottom. |
| `can_advance` delay | `ENTRY_DURATION` | matches entry | Time before player input accepted. Always equal to ENTRY_DURATION. |
| SpeakerLabel font_size | 18 px | 14–22 px | Boss name readability at 720p. 14 is minimum. |
| DialogueLabel font_size | 14 px | 12–16 px | Body text readability. 12 is accessibility floor at 720p. |
| BalloonPanel bg color | #0D0D1A | — | Deep navy. Part of visual identity — do not change without art direction sign-off. |
| BalloonPanel border color | #4A90D9 | — | Cold blue. Do not change without art direction sign-off. |

## Acceptance Criteria

**AC-BDU-001 — Balloon entry animation plays on dialogue trigger**
Enter Devium boss room. Dialogue triggers. `WizrlessBossBalloon` enters scene tree. DimOverlay fades from alpha 0 to 0.55 over 0.3 s. BalloonPanel slides from y+80 to y+0 over 0.3 s. Both animations play simultaneously. Verified by: visual check and tween timing with print log.

**AC-BDU-002 — Combat starts only after balloon exits**
Player presses `ui_accept` on final Devium line. BalloonPanel slides to y+80 over 0.25 s. DimOverlay fades to 0. Balloon exits scene tree. `_start_combat()` fires no earlier than 0.25 s after final advance. Verified by: timestamp log on `_start_combat()`, confirm ≥0.25 s delay.

**AC-BDU-003 — Player cannot advance during entry animation**
During 0.3 s entry tween, spam `ui_accept`. First dialogue line does not advance — typewriter starts from char 0 after tween completes. Verified by: monitor `dialogue_label.visible_ratio` during entry.

**AC-BDU-004 — HUD hidden during dialogue**
While balloon is open: HealthRow, ManaBar, SpellSlotRow are not visible. Verified by: check HUD node visibility during dialogue playback.

**AC-BDU-005 — Boss health bar deferred until dialogue ends**
Devium spawns (boss_appeared fires). During dialogue, boss health bar is NOT visible. After balloon exits, boss health bar fades in over 0.5 s. Verified by: visual check; confirm bar absent during dialogue, present after.

**AC-BDU-006 — HUD restored after dialogue ends**
After balloon exits: HealthRow, ManaBar, SpellSlotRow visible again. Player movement enabled. Verified by: complete dialogue, confirm HUD shows and movement works.

**AC-BDU-007 — Devium portrait renders in frame**
Devium's 128×128 portrait texture appears in PortraitFrame during dialogue. PortraitFrame border visible. Verified by: visual check.

**AC-BDU-008 — Missing portrait hides frame**
Trigger test dialogue with character not in PORTRAIT_REGISTRY. PortraitFrame not visible. No broken texture. TextArea expands to full balloon width. Verified by: author test dialogue line with unknown character.

**AC-BDU-009 — SpeakerLabel shows uppercase name in gold**
Devium dialogue: SpeakerLabel text = "DEVIUM" (uppercase, regardless of .dialogue file casing). Color matches #E8D5A3 ±10% tolerance. Verified by: visual check and color picker.

**AC-BDU-010 — Progress indicator shows only after typewriter completes**
During typewriter playback: progress indicator `Label.modulate.a = 0.0`. After typewriter finishes: progress indicator blinks at 0.4 s interval. After player advances: indicator hides again. Verified by: watch one full dialogue line cycle.

**AC-BDU-011 — Balloon uses Wizrless color scheme**
BalloonPanel background: #0D0D1A ±10%. Border: #4A90D9 ±10%. Verified by: color picker on rendered frame at ACTIVE state.

**AC-BDU-012 — Boss Dialogue UI uses custom balloon, not ExampleBalloon**
`BossIdleState` calls `show_dialogue_balloon_scene(BOSS_BALLOON, ...)`. No `show_dialogue_balloon()` calls remain in boss scripts. Verified by: grep `show_dialogue_balloon\b` in `scripts/bosses/`, result must be zero matches (only `show_dialogue_balloon_scene` present).
