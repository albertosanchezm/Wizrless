# Spell VFX System

> **Status**: In Design
> **Author**: Alberto Sánchez + Claude Code agents
> **Last Updated**: 2026-05-05
> **Implements Pillar**: Spell Alchemy (visual legibility of interactions), Earned Truth (spell identity)

## Overview

The Spell VFX System defines the visual identity of every spell and interaction in the game. It owns four categories of visual output:

1. **Projectile visuals** — the in-flight appearance of each spell (sprite, trail particles, light)
2. **Impact VFX** — the hit/expire effect when a projectile contacts an enemy or surface
3. **Interaction VFX** — the effect fired by the Spell Interaction Engine when a combo triggers (Steam Burst, Cryoblast, Extinguish, Amplify, Inferno)
4. **Status effect visuals** — persistent visual indicators on enemies for FROZEN, BURNING, MARKED, SLOWED, STUNNED

The system does not own audio — that is the Audio Feedback System. It does not own damage numbers — those belong to Enemy Base System. It does not own the mana bar or cooldown overlay — those are HUD.

**Architecture:** Most VFX are self-contained inside their respective projectile scenes or enemy nodes. The Spell VFX System's primary structural contribution is the `SpellVFXSpawner` autoload, which listens to `SpellInteractionEngine.interaction_triggered` and spawns the correct interaction VFX scene at the correct world position. Projectile VFX require no central coordinator — each scene handles its own birth, life, and death visuals.

**Visual law:** Any two spells must be distinguishable at a glance. Color alone cannot be the only differentiator — shape and motion must carry the distinction for colorblind players. This is a hard constraint, not a guideline.

## Player Fantasy

Spells are the only color in the world.

Everything else in Wizrless is stone, shadow, and ice. The wizard moves through spaces built to suppress. When he raises his hand and Fireball leaves it — orange and alive against the dark — that is the first moment of color the player has seen in that room. It earns attention. It should feel earned.

Each spell has a visual personality the player should be able to name before they know its name. Fireball feels eager — it moves fast, it trails heat, it wants to hit something. Ice Shard feels precise — crystalline, cold, minimal. Shadow Tendril feels wrong in a way that is hard to articulate until it curves. These are not purely aesthetic choices. They communicate danger, range, and timing. A player watching Cryoblast for the first time should stop moving for a half-second. Not because a prompt told them something happened. Because something obviously, spectacularly happened, and they did it.

Status effects on enemies are quieter — information, not spectacle. The ice crystal overlay on a frozen enemy and the MARKED sigil need to be readable at combat distance without dominating the character art.

## Detailed Design

### 1. Architecture

```
SpellVFXSpawner (autoload)
  └─ subscribes: SpellInteractionEngine.interaction_triggered
  └─ on signal: instantiate InteractionBurst scene at enemy.global_position, add to root

StatusVFXComponent (Node2D, child of each enemy scene)
  └─ subscribes: SpellInteractionEngine.status_applied(enemy, status, duration)
  └─ subscribes: SpellInteractionEngine.status_expired(enemy, status)
  └─ owns: per-status overlay nodes (sprite overlays, CPUParticles2D)

ProjectileScene (per spell)
  └─ owns: Sprite2D/AnimatedSprite2D + CPUParticles2D trail
  └─ owns: impact burst (CPUParticles2D or AnimationPlayer one-shot)
  └─ on body_entered / lifetime: play impact VFX, queue_free
```

Interaction burst scenes are added to the **scene root** (not as children of the enemy) so they survive `enemy.queue_free()` and play to completion.

---

### 2. Projectile Visuals

Each spell has a required visual identity. The VFX spec below defines what each projectile scene must produce:

| Spell | Primary Shape | Trail | Color Anchor | Motion Signature |
|-------|--------------|-------|-------------|-----------------|
| Fireball | Pulsing sphere, animated scale ±10% | Warm particle stream, 20–30 particles | Orange `#FF6A00`, red `#C0392B` | Fast, eager — speed 220 px/s |
| Ice Shard | Elongated 4-sided crystal, no animation | Scattered ice fragments, 8–12 particles | Ice blue `#A8D8EA`, white `#FFFFFF` | Precise, straight — speed 160 px/s |
| Light Bolt | Thin bright beam (Line2D or elongated Sprite2D) | Short forward glow, 5 particles | White `#FFFFFF`, gold `#FFD700` | Instant-feeling — speed 300 px/s |
| Shadow Tendril | Wispy irregular shape (animated frame strip) | Trailing smoke, 15–20 particles | Deep purple `#4A235A`, near-black | Curves downward — arc trajectory |
| Conjure | Pulsing orb, slow rotation outer ring | Slow-moving sparkles, 10 particles | Teal `#00BCD4`, emerald `#2ECC71` | Stationary — placed at cast point |
| Rupture | Dense mass, no inner animation | No trail | Dark crimson `#7B241C`, near-black outer | Heavy — speed 120 px/s, short lifetime |

**Shape rule:** Fireball = round. Ice Shard = elongated faceted. Light Bolt = thin line. Shadow Tendril = irregular wisp. Conjure = ringed orb. Rupture = dense blob with rough silhouette. All distinguishable by silhouette alone.

**Impact VFX** (plays at projectile death position, then frees):

| Spell | Impact Effect | Duration |
|-------|--------------|---------|
| Fireball | Burst of orange/red particles outward, brief flame flash | 0.4 s |
| Ice Shard | Shatter — blue/white fragments spray | 0.3 s |
| Light Bolt | Flash of white light, fade | 0.2 s |
| Shadow Tendril | Purple smoke puff | 0.35 s |
| Conjure | Orb collapse inward (reverse pulse) — expiry only, no contact burst | 0.5 s |
| Rupture | Dark explosion, brief screen-edge flash | 0.5 s |

---

### 3. Status Effect Overlays (`StatusVFXComponent`)

One component per enemy. Owns child nodes for each possible status. Nodes hidden by default; shown when status is active.

| Status | Visual | Node Type | Placement |
|--------|--------|-----------|-----------|
| `frozen` | Ice crystal sprite + blue tint (`modulate = Color(0.6, 0.9, 1.0)`) on overlay sprite | Sprite2D overlay | Centered on enemy |
| `burning` | Upward flame particles | CPUParticles2D | Above enemy head (+Y offset) |
| `marked` | Pulsing arcane sigil, scale 1.0→1.1→1.0 at 0.5 Hz | Sprite2D + AnimationPlayer | Above enemy head (+Y offset, higher than burning) |
| `slowed` | Semi-transparent cyan ring around feet, slow rotation | Sprite2D, modulated cyan | At enemy feet |
| `stunned` | Stars/swirl loop above head | AnimatedSprite2D | Above head (highest) |

**Coexistence rule:** All active overlays visible simultaneously — no mutual exclusion. Z-order: `stunned` top → `marked` → `burning` → `frozen` → `slowed` bottom. Y offsets prevent overlapping obscurement.

**Status expire:** On `status_expired`, tween `modulate.a` from 1.0 to 0.0 over 0.2 s, then hide node.

**Blue tint rule:** FROZEN tint lives on the `StatusVFXComponent` overlay sprite — not on the enemy's own sprite. This allows hit flash (white modulate on enemy sprite) to coexist without conflict.

---

### 4. Interaction Burst VFX (`SpellVFXSpawner`)

`SpellVFXSpawner` maintains a preloaded dictionary:

```gdscript
const BURST_SCENES: Dictionary = {
    &"steam_burst": preload("res://vfx/interactions/steam_burst.tscn"),
    &"cryoblast":   preload("res://vfx/interactions/cryoblast.tscn"),
    &"extinguish":  preload("res://vfx/interactions/extinguish.tscn"),
    &"amplify":     preload("res://vfx/interactions/amplify.tscn"),
    &"inferno":     preload("res://vfx/interactions/inferno.tscn"),
}
```

On `interaction_triggered(enemy, element, final_damage)`:
1. Derive interaction name from signal (interaction name must be added to signal payload — see Dependencies).
2. Instantiate burst scene at `enemy.global_position`.
3. Add to scene root (not enemy child).
4. Scene self-destructs via `CPUParticles2D` one-shot + `queue_free` on finished, or `AnimationPlayer` end callback.

Per-interaction burst specs:

| Interaction | Color | Scale | Lifetime | Blend | Signature |
|-------------|-------|-------|---------|-------|-----------|
| Steam Burst | Orange `#FF8C00` + white `#FFFFFF` | 1.5× base | 0.8 s | Additive | Radial outward burst, ~80 px radius |
| Cryoblast | Ice blue `#AED6F1` + white | 1.2× base | 0.6 s | Additive | Ice shards spray outward |
| Extinguish | Grey `#95A5A6` + white | 1.0× base | 0.7 s | Normal | Steam cloud billowing upward |
| Amplify | Gold `#F1C40F` + white | 1.0× base | 0.4 s | Additive | Sigil flash at hit point |
| Inferno | Deep orange `#E74C3C` + bright orange | 1.3× base | 0.9 s | Additive | Flame eruption, taller than wide |

---

### 5. Hit Flash (All Hits)

Every projectile hit — interaction or not — produces a brief white flash on the enemy sprite. Owned by `BaseEnemy` hit response, not `SpellVFXSpawner`.

```gdscript
func _on_hit() -> void:
    var tween := create_tween()
    sprite.modulate = Color.WHITE
    tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
    tween.tween_property(sprite, "modulate", original_modulate, 0.10)
```

---

### 6. Emitter Budget

Design target: ≤12 simultaneous particle emitters in a single room.

| Source | Count |
|--------|-------|
| Projectile trails (max 2 in flight) | 2 |
| Status overlays — per-enemy merged into 1 CPUParticles2D (6 enemies) | 6 |
| Interaction burst (self-freeing) | 1 |
| Impact bursts (brief, auto-free) | 2 |
| **Worst case** | **11** |

Mitigation: `StatusVFXComponent` merges all particle-based status emitters (burning, stunned) into one shared `CPUParticles2D` per enemy using conditional emission parameters. Non-particle overlays (frozen crystal, marked sigil, slowed ring) use `Sprite2D` + `AnimationPlayer` — zero emitter cost.

## Formulas

```
-- Sigil pulse (MARKED overlay)
period     = 1.0 / 0.5 Hz = 2.0 s
scale_peak = 1.1
scale_base = 1.0
waveform   = sine interpolation over period

-- Hit flash timing
white_hold  = 0.05 s
fade_back   = 0.10 s
total       = 0.15 s

-- Status overlay fade-out on expire
alpha_start = 1.0
alpha_end   = 0.0
duration    = 0.2 s
curve       = linear
```

### Particle Count Budgets (`CPUParticles2D` `amount` property)

| Emitter | `amount` | Rationale |
|---------|---------|-----------|
| Fireball trail | 25 | Dense enough for heat feel; not overwhelming |
| Ice Shard trail | 10 | Sparse — precise spell, sparse particles |
| Light Bolt trail | 5 | Near-invisible trail; speed does the work |
| Shadow Tendril trail | 18 | Wispy — needs enough particles for smoke read |
| Conjure sparkle | 12 | Ambient; stationary orb breathes |
| Rupture | 0 | No trail by design |
| Per-enemy merged status emitter | 20 | Budget covers worst-case BURNING + STUNNED |
| Interaction burst | 40–60 | Per-interaction (Steam Burst highest at 60) |
| Impact burst | 15–25 | Per-spell (Rupture highest at 25) |

### Burst Scale Formula

```
burst_world_scale = base_scale × intensity_multiplier

where base_scale = 1.0  (16×16 px reference emitter)

Intensity multipliers:
  Steam Burst : 1.5×
  Cryoblast   : 1.2×
  Extinguish  : 1.0×
  Amplify     : 1.0×
  Inferno     : 1.3×
```

### Variable Definitions

| Variable | Value | Unit | Description |
|----------|-------|------|-------------|
| `SIGIL_PULSE_HZ` | 0.5 | Hz | MARKED sigil scale oscillation rate |
| `HIT_FLASH_HOLD` | 0.05 | s | White modulate hold duration |
| `HIT_FLASH_FADE` | 0.10 | s | Tween back to original modulate |
| `STATUS_FADE_OUT` | 0.2 | s | Overlay alpha fade on status expire |
| `MAX_EMITTERS` | 12 | count | Design budget for simultaneous emitters |

## Edge Cases

**EC-01 — Enemy dies while status overlay is active.**
`StatusVFXComponent` is a child of the enemy scene. When enemy `queue_free()` fires, component frees with it — no dangling overlays. Interaction burst scenes are added to scene root, not enemy child, so they play to completion regardless of enemy death.

**EC-02 — Same status applied again while already active.**
`SpellInteractionEngine.status_applied` fires again with same status name. `StatusVFXComponent` checks if overlay node is already visible — if so, restart animation/tween without spawning a duplicate node. No double-overlay. Duration reset is handled by the engine; VFX component only cares whether to show or re-trigger.

**EC-03 — Two interactions fire in quick succession on the same enemy.**
Two `interaction_triggered` signals in rapid succession. `SpellVFXSpawner` spawns two burst scenes at same world position. Both play simultaneously — additive blend causes them to visually reinforce each other. No de-duplication logic needed; overlapping bursts are acceptable.

**EC-04 — Multiple statuses coexist; overlays visually conflict.**
FROZEN overlay (ice crystal, blue tint on overlay sprite) + MARKED sigil + BURNING particles simultaneously. Z-order and Y-offset rules in Detailed Design prevent any overlay fully obscuring another. The blue tint is on the `StatusVFXComponent`'s own sprite, not the enemy's sprite — hit flash on enemy sprite unaffected.

**EC-05 — Interaction burst scene file missing or not preloaded.**
`SpellVFXSpawner._ready()` preloads all five burst scenes. If a `.tscn` file is absent: `preload()` fails at startup (Godot hard error), not silently at runtime. Correct — missing VFX scenes are a deploy error, not a graceful-degradation case. All five scenes must exist before ship.

**EC-06 — Player fires Light Bolt against dark background.**
Light Bolt uses additive blend (`CanvasItem` blend mode `ADD`) — dark backgrounds make additive-blend colors brighter, not less visible. No special case needed. Additive blend is mandatory for Light Bolt; using normal blend would make it invisible against dark stone.

**EC-07 — Conjure orb expires at cast point where no enemy was hit.**
Orb lifetime ends — `LifeTimer` fires `queue_free()`. Impact VFX for Conjure is the "orb collapse inward" animation — plays at the orb's world position on expire, regardless of whether any enemy interaction occurred. The VFX is owned by the projectile scene. No `SpellVFXSpawner` involvement.

**EC-08 — Player switches active spell mid-projectile-flight.**
In-flight projectile scene is already instantiated. It retains its own VFX regardless of what the player subsequently equips. No re-skin, no visual update. Correct — the projectile was cast with that spell.

**EC-09 — Steam Burst AoE hits second enemy; does that trigger VFX?**
Secondary `take_damage()` hit on AoE targets may trigger another `interaction_triggered` if those enemies have statuses. `SpellVFXSpawner` fires a second burst at the secondary enemy position. Correct — chain reactions warrant chain VFX.

**EC-10 — Emitter budget exceeded in dense combat.**
If player somehow exceeds 12 simultaneous emitters (edge case: 6 enemies all with BURNING, 2 projectiles in flight, multiple bursts): Godot `CPUParticles2D` does not automatically cull — all emitters run. No crash. Visual becomes busier than intended but gameplay is unaffected. Post-MVP: add emitter pool with hard cap; at MVP room enemy count (≤6) + design rules keep this within budget.

## Dependencies

### Systems this requires

| System | What Spell VFX needs |
|--------|---------------------|
| **Spell System** | `SpellResource.projectile_scene` — each scene owns its own VFX; `SpellElement` enum for color/shape assignment |
| **Spell Interaction Engine** | `interaction_triggered(enemy, element, final_damage, interaction_name)` — see signal contract change below; `status_applied(enemy, status, duration)`; `status_expired(enemy, status)` |
| **Enemy Base System** | `StatusVFXComponent` attaches as child of `BaseEnemy` scene; requires `BaseEnemy` node hierarchy to be stable |

### Systems that require this

None. Spell VFX is a terminal leaf — no other system reads from it.

### Signal Contract Change (breaking)

`SpellInteractionEngine.interaction_triggered` currently emits `(enemy, element, final_damage)`. `SpellVFXSpawner` needs the interaction name to look up the correct burst scene. Two options:

**Option A (preferred):** Add `interaction_name: StringName` as fourth param:
```gdscript
signal interaction_triggered(enemy: BaseEnemy, element: StringName, final_damage: int, interaction_name: StringName)
```

**Option B:** `SpellVFXSpawner` re-derives the interaction name from the enemy's active status at hit moment. Fragile — status may already be removed by the time the signal fires.

Option A is preferred. `SpellInteractionEngine` already knows the name when emitting — passing it is trivial. This change must be coordinated with Audio Feedback System (same subscriber, same signal).

### Systems that run in parallel (same signals)

| System | Shared signal | Independence |
|--------|--------------|-------------|
| **Audio Feedback System** | `interaction_triggered`, `status_applied`, `status_expired` | Fully independent — both subscribe, neither calls the other |

### Hard Blockers

- `SpellInteractionEngine` signals must exist and fire correctly before `SpellVFXSpawner` can be tested
- `BaseEnemy` scene hierarchy must be stable so `StatusVFXComponent` can be added as child
- All five burst `.tscn` files must exist (placeholder one-node scenes acceptable at MVP) — `preload()` is a hard dependency at startup

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `SIGIL_PULSE_HZ` | 0.5 Hz | 0.25–2.0 Hz | Below 0.25: barely perceptible. Above 2.0: flickering. 0.5 readable at combat distance. |
| `HIT_FLASH_HOLD` | 0.05 s | 0.03–0.15 s | Too short: unnoticeable on fast hits. Too long: distracting during rapid multi-hit. |
| `HIT_FLASH_FADE` | 0.10 s | 0.05–0.25 s | Longer = softer return to color. Tune paired with HOLD. |
| `STATUS_FADE_OUT` | 0.2 s | 0.1–0.5 s | Fast enough to feel clean. Above 0.5: expired status lingers confusingly. |
| `FROZEN_TINT` | `Color(0.6, 0.9, 1.0)` | R 0.4–0.8, G 0.7–1.0, B 0.9–1.0 | Stronger blue = more readable freeze state. Too strong = obscures enemy art. |
| Fireball trail `amount` | 25 | 15–50 | Below 15: sparse — loses heat feel. Above 50: CPU cost, visual noise. |
| Ice Shard trail `amount` | 10 | 6–20 | Sparse by design. Keep low — precision spell. |
| Interaction burst lifetime | per-interaction ±0.2 s | −0.2 s to +0.4 s | Shorter = snappier. Longer = more dramatic but may outlast gameplay moment. |
| Interaction burst scale | per-interaction table | ×0.7–×2.0 | Scale down if bursts obscure enemy position readability. Scale up for more spectacle. |
| `MAX_EMITTERS` | 12 | 8–20 | Design budget only — not enforced in code at MVP. Below 8: VFX feels sparse. Above 20: CPU risk on low-end hardware. |

### Interaction Notes

- Hit flash total duration (HOLD + FADE) must stay ≤ `ATTACK_COOLDOWN` (1.5 s) — no hit should flash longer than the minimum cast interval.
- Burst lifetimes must not exceed 1.0 s — VFX that outlasts the next possible cast action distracts from gameplay.
- `STATUS_FADE_OUT` must be visually faster than the shortest status duration (`stunned` = 1.5 s) by at least 5× — fades must not be mistaken for an expiring status.

## Acceptance Criteria

**AC-01 — All six projectiles visually distinguishable.**
Place all six projectiles on screen simultaneously. Convert display to grayscale. QA tester identifies all six by silhouette + motion alone. Pass: zero misidentifications.

**AC-02 — Fireball visual matches spec.**
Fire Fireball. Pulsing orange/red sphere visible in flight. Warm particle trail follows. On contact: orange/red burst, ≤0.4 s, then scene frees. Pass.

**AC-03 — Ice Shard visual matches spec.**
Fire Ice Shard. Elongated blue/white crystal. Sparse ice-fragment trail. On contact: blue/white shard spray ≤0.3 s. Pass.

**AC-04 — Light Bolt visual matches spec.**
Fire Light Bolt. Thin bright white/gold beam. Additive blend — visible against dark background. On contact: white flash ≤0.2 s. Pass.

**AC-05 — Shadow Tendril visual matches spec.**
Fire Shadow Tendril. Wispy irregular purple/dark shape. Smoke trail. Curves downward during flight. On contact: purple smoke puff ≤0.35 s. Pass.

**AC-06 — Conjure visual matches spec.**
Fire Conjure. Teal/emerald pulsing orb at cast point. Slow rotation outer ring. Ambient sparkles while active. On lifetime expire: orb collapses inward ≤0.5 s. Pass.

**AC-07 — Rupture visual matches spec.**
Fire Rupture. Dense dark crimson/near-black mass. No trail. On contact: dark explosion ≤0.5 s. Pass.

**AC-08 — FROZEN overlay appears and expires cleanly.**
Hit enemy with Ice Shard. Ice crystal overlay appears centered on enemy. Blue tint applied to overlay sprite (not enemy sprite). Wait 3.0 s — overlay fades over 0.2 s and disappears. Enemy returns to normal appearance. Pass.

**AC-09 — BURNING overlay appears and expires cleanly.**
Hit enemy with Fireball. Flame CPUParticles2D appears above enemy head. Wait 4.0 s — particles stop, overlay gone. Pass.

**AC-10 — MARKED overlay pulses and expires cleanly.**
Fire Conjure at enemy. Pulsing sigil appears above enemy head. Scale oscillates visibly (1.0→1.1→1.0) approximately every 2 s. Wait 5.0 s — sigil fades over 0.2 s and disappears. Pass.

**AC-11 — SLOWED overlay appears on Extinguish.**
Trigger Extinguish (BURNING + ICE). Cyan ring appears at enemy feet after interaction. Ring persists 2.0 s then fades. Pass.

**AC-12 — STUNNED overlay appears on Cryoblast.**
Trigger Cryoblast (FROZEN + RUPTURE). Stars/swirl animation appears above enemy head. Persists 1.5 s then disappears. Pass.

**AC-13 — Multiple status overlays coexist.**
Apply FROZEN and MARKED to same enemy simultaneously. Both overlays visible: ice crystal on body, sigil above head. Neither obscures the other. Hit flash (white) on enemy sprite does not affect overlays. Pass.

**AC-14 — Steam Burst VFX fires and survives enemy death.**
Freeze enemy, fire Fireball to trigger Steam Burst. Enemy killed by burst. Orange/white radial explosion at enemy position plays to full 0.8 s lifetime. VFX not cut short by enemy `queue_free()`. Pass.

**AC-15 — Cryoblast VFX fires.**
Freeze enemy, fire Rupture. Ice shard spray at enemy position, cold blue/white, ≤0.6 s. Pass.

**AC-16 — Extinguish VFX fires.**
Burn enemy, fire Ice Shard. Steam cloud at enemy position, grey/white, ≤0.7 s. BURNING overlay disappears simultaneously with burst. Pass.

**AC-17 — Amplify VFX fires.**
Mark enemy with Conjure, fire any other spell. Gold/white sigil flash at hit point, ≤0.4 s. Pass.

**AC-18 — Inferno VFX fires.**
Burn enemy, fire Fireball. Flame eruption at enemy position, deep orange/red, ≤0.9 s. BURNING overlay persists (not cleared). Pass.

**AC-19 — Hit flash on every projectile contact.**
Fire each spell at each enemy type. Every contact produces visible white flash on enemy sprite, ≤0.15 s total. Flash visible even when status overlays are active. Pass.

**AC-20 — No emitter leak after combat.**
Complete a full combat room: 6 enemies, all statuses applied, all 5 interactions triggered. After all enemies dead and all bursts expired, inspect Godot scene tree. Zero orphaned `CPUParticles2D` nodes. Pass.

**AC-21 — `SpellVFXSpawner` startup with missing burst scene crashes loudly.**
Remove one burst `.tscn` file. Launch game. Godot reports `preload()` error at startup — does not fail silently at runtime. Pass: explicit error, not a silent miss.
