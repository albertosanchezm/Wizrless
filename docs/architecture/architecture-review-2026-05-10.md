# Architecture Review Report

**Date:** 2026-05-10
**Engine:** Godot 4.6
**GDDs Reviewed:** 22 (all MVP systems)
**ADRs Reviewed:** 0
**Prior Review:** docs/architecture/architecture-review-2026-05-09.md

---

## Summary

Second architecture review. 0 ADRs still exist — verdict unchanged: **FAIL**. Two GDDs revised since prior review (enemy-base-system, spell-interaction-engine) resolved 4 of 6 cross-review blockers. New engine API error found in spell-interaction-engine.md. 8 new TRs registered (125 total).

---

## Phase 2 — Technical Requirements (Delta from Prior Review)

### Modified GDDs

#### enemy-base-system.md (revised 2026-05-09)

New requirements not in prior registry:

| TR-ID | Requirement |
|-------|------------|
| TR-enemy-008 | `speed_modifier: float = 1.0` on BaseEnemy — multiplied into AI velocity per frame; FROZEN/STUNNED set to 0.0, SLOWED set to 0.5, expire resets to 1.0 |
| TR-enemy-009 | `health_changed(current: int, maximum: int)` signal on BaseEnemy (separate from HealthSystem's player health signal) |
| TR-enemy-010 | `burn_timer: Timer` required child node; started on BURNING apply via status_applied, stopped on BURNING expire or enemy death |
| TR-enemy-011 | BaseEnemy._ready() connects SpellInteractionEngine.status_applied and status_expired signals to local handlers |
| TR-enemy-012 | DamageNumber.spawn(parent, amount, position, color) called from take_damage(); suppressed when amount == 0 |

Resolved revision flags:

| TR-ID | Flag Cleared |
|-------|-------------|
| TR-enemy-002 | B-03: element parameter type confirmed StringName |

#### spell-interaction-engine.md (revised 2026-05-09)

New requirements not in prior registry:

| TR-ID | Requirement |
|-------|------------|
| TR-interaction-010 | Derived statuses &"stunned" (Cryoblast, 1.5 s) and &"slowed" (Extinguish, 2.0 s) defined and applied by SpellInteractionEngine._apply_status() |
| TR-interaction-011 | _processing_interaction bool guard in process_hit() prevents Steam Burst AoE recursion depth overflow |
| TR-interaction-012 | SpellInteractionEngine must be listed before GameManager in project.godot autoload order |

Resolved revision flags:

| TR-ID | Flag Cleared |
|-------|-------------|
| TR-interaction-004 | Method signature corrected to `process_hit(enemy: BaseEnemy, base_damage: int, element: StringName)` |
| TR-interaction-005 | B-02: Status tick now explicitly iterates both &"enemy" and &"boss" groups |
| TR-interaction-006 | B-03: StringName type unified across BaseEnemy and SpellInteractionEngine |
| TR-interaction-007 | B-04: interaction_triggered second param is now `interaction_name: StringName` |
| TR-interaction-008 | B-05: status_applied(enemy, status, duration) signal defined |
| TR-interaction-009 | B-05: status_expired(enemy, status) signal defined |

---

## Phase 3 — Traceability Matrix

**125 total TRs. 0 covered. 0 partial. 125 gaps.**

| Layer | TRs | Covered | Partial | Gaps |
|-------|-----|---------|---------|------|
| Foundation (input, audio, save, camera) | 23 | 0 | 0 | 23 |
| Core (health, movement, spell, enemy, zone) | 31 | 0 | 0 | 31 |
| Feature (slot, ai, hazard, checkpoint, dialogue, material, interaction, upgrade, boss) | 51 | 0 | 0 | 51 |
| Presentation (hud, vfx, audiofb, bossui) | 20 | 0 | 0 | 20 |
| **Total** | **125** | **0** | **0** | **125** |

All 125 gaps are listed in `docs/architecture/tr-registry.yaml`. No ADR exists to cover any requirement.

---

## Phase 4 — Cross-ADR Conflict Detection

No ADRs exist. No conflicts possible.

Dependency analysis: deferred until ADRs are created.

---

## Phase 5 — Engine Compatibility Audit

### ADR Coverage

0 ADRs with Engine Compatibility sections (0 ADRs total). No audit possible at ADR level.

### GDD-Level Engine Findings

#### 🔴 CRITICAL — spell-interaction-engine.md: `intersect_circle()` does not exist

**Confirmed by Godot specialist.**

The GDD Formulas section specifies:
```
Query method = PhysicsDirectSpaceState2D.intersect_circle(origin, radius, exclude=[primary])
```

`PhysicsDirectSpaceState2D` has no `intersect_circle()` method in any Godot 4.x release. This call would crash at runtime (`is not a method` error) when Steam Burst AoE executes.

**Correct Godot 4.6 API:**
```gdscript
var space_state := get_world_2d().direct_space_state
var shape := CircleShape2D.new()
shape.radius = 80.0
var params := PhysicsShapeQueryParameters2D.new()
params.shape = shape
params.transform = Transform2D(0.0, origin)
params.collision_mask = enemy_layer_mask
params.exclude = [primary_rid]
var hits: Array[Dictionary] = space_state.intersect_shape(params)
```

Action: revise spell-interaction-engine.md Formulas section before implementation.

#### ⚠️ MEDIUM — spell-interaction-engine.md: `get_nodes_in_group()` every _process() frame

Status tick calls `get_tree().get_nodes_in_group()` twice per frame (enemy + boss loops). Each call allocates a new Array. At low enemy counts invisible; scales poorly above ~20 enemies.

Mitigation: cache lists and invalidate on tree_entered/tree_exited, or use a registration pattern (enemies register/deregister with SpellInteractionEngine directly on _ready/tree_exiting).

### Engine Specialist Findings

Godot specialist confirmed both findings above. Additional note: `Time.get_ticks_msec() / 1000.0` pattern is correct — GDScript integers are 64-bit, no overflow risk. No other API errors in process_hit() or _tick_statuses() code sketches.

---

## Phase 5b — GDD Revision Flags

### New flags (this review)

| GDD | Assumption in GDD | Verified Reality | Action |
|-----|------------------|-----------------|--------|
| spell-interaction-engine.md | `PhysicsDirectSpaceState2D.intersect_circle()` for Steam Burst AoE | Method doesn't exist; runtime crash | Revise GDD — use `intersect_shape()` |
| spell-interaction-engine.md | `get_nodes_in_group()` called every _process() frame | 2 Array allocs/frame — scales poorly | Add caching note to Tuning Knobs |

### Outstanding from prior cross-review (unresolved)

| GDD | Flag | Description |
|-----|------|-------------|
| hazard-system.md | B-01 | Damage values not calibrated to 6–14 HP health scale |
| health-system.md | B-06 | `heal()` method missing from GDD |
| health-system.md | W-02 | dialogue_active invulnerability not specified in damage flow |
| zone-room-system.md | W-01 | Checkpoint guard logic for Room._ready() not in GDD |
| hud-system.md | W-06 | Boss bar reveal timing + HUD suppression unspecified |
| audio-feedback-system.md | W-07 | Both &"enemy" and &"boss" groups not explicitly listed |
| — | W-05 | `progression-system.md` not created |

---

## Phase 6 — Architecture Document Coverage

`docs/architecture/architecture.md` does not exist. No coverage gap analysis possible.

---

## Verdict: 🔴 FAIL

**Primary blocker:** 0 ADRs. All 125 requirements across Foundation, Core, Feature, and Presentation layers are architecturally uncovered.

**Secondary blocker:** `intersect_circle()` API error in spell-interaction-engine.md must be fixed before Steam Burst implementation begins.

### Progress Since 2026-05-09

| Item | Status |
|------|--------|
| Cross-review blocker B-02 (status tick groups) | ✅ Resolved |
| Cross-review blocker B-03 (StringName unification) | ✅ Resolved |
| Cross-review blocker B-04 (interaction_name in signal) | ✅ Resolved |
| Cross-review blocker B-05 (status signals defined) | ✅ Resolved |
| Cross-review blocker B-01 (hazard calibration) | ❌ Outstanding |
| Cross-review blocker B-06 (heal() method) | ❌ Outstanding |
| W-01 (zone checkpoint guard) | ❌ Outstanding |
| W-02 (health dialogue invulnerability) | ❌ Outstanding |
| W-05 (progression-system GDD) | ❌ Not created |
| W-06 (HUD boss bar) | ❌ Outstanding |
| W-07 (audio both groups) | ❌ Outstanding |
| New TRs registered | ✅ +8 (125 total) |
| ADRs created | ❌ 0 |

---

## Required ADRs — Priority Order

| Priority | ADR | TRs Covered |
|----------|-----|------------|
| 1 | **ADR-0001: Autoload Singleton Architecture** | TR-slot-001, TR-interaction-001, TR-vfx-001, TR-audiofb-001, TR-dialogue-001, TR-interaction-012 |
| 2 | **ADR-0002: Signal Hub / GameManager Contract** | TR-health-004, TR-spell-006, TR-slot-007, TR-boss-008, TR-material-006 |
| 3 | **ADR-0007: Damage API & SpellInteractionEngine Contract** | TR-interaction-004 through TR-interaction-012, TR-enemy-002 |

---

## Phase 9 — Handoff

**Immediate actions:**
1. Fix `intersect_circle()` API error in spell-interaction-engine.md (Formulas section)
2. Resolve outstanding GDD blockers B-01, B-06, W-01, W-02, W-06, W-07
3. Run `/architecture-decision autoload-singletons` to create ADR-0001

**Gate guidance:** When all blocking issues resolved, run `/gate-check pre-production` to advance.

**Rerun trigger:** Re-run `/architecture-review` after each new ADR to verify coverage improves.
