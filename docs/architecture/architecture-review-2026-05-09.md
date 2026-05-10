# Architecture Review Report

> **Date**: 2026-05-09
> **Engine**: Godot 4.6 (pinned 2026-02-12)
> **GDDs Reviewed**: 22 / 22 MVP
> **ADRs Reviewed**: 0
> **Verdict**: 🔴 **FAIL**

---

## Executive Summary

No ADRs exist. All 22 MVP GDDs are architecturally uncovered. Compounded by 6 unresolved cross-GDD blockers (see `design/gdd/gdd-cross-review-2026-05-09.md`), the architecture phase cannot begin productively until those blockers are reconciled at the GDD level.

This report extracts the full Technical Requirement (TR) baseline (117 TRs registered in `tr-registry.yaml`), maps where each one will need an ADR, and prioritises the ADR backlog by dependency layer.

| Metric | Count |
|--------|-------|
| Total TRs extracted | 117 |
| ✅ Covered by ADR | 0 |
| ⚠️ Partial | 0 |
| ❌ Gap | 117 (100%) |
| ADRs required (estimated) | ~22 |

---

## Phase 2: Technical Requirement Baseline

Full TR extraction written to `docs/architecture/tr-registry.yaml`. Summary by system:

| Layer | System | TR Count | GDD Status |
|-------|--------|---------:|-----------|
| Foundation | input | 5 | Designed |
| Foundation | audio | 7 | Designed |
| Foundation | save | 6 | Designed |
| Foundation | camera | 5 | In Review |
| Core | health | 7 | In Review (B-06, W-02 fixes pending) |
| Core | movement | 5 | In Review |
| Core | spell | 7 | In Review (W-03 fix pending) |
| Core | enemy | 7 | In Review (B-03 fix pending) |
| Feature | zone | 7 | In Review (W-01 fix pending) |
| Feature | slot | 7 | In Review |
| Feature | ai | 5 | In Review |
| Feature | hazard | 3 | In Review (B-01 fix pending) |
| Feature | checkpoint | 4 | In Review |
| Feature | dialogue | 6 | In Review |
| Feature | material | 6 | In Review |
| Feature | interaction | 9 | In Review (B-02, B-04, B-05 fixes pending) |
| Feature | upgrade | 6 | In Design (depends on B-06) |
| Feature | boss | 9 | In Design |
| Presentation | hud | 8 | In Design (W-06 fix pending) |
| Presentation | vfx | 7 | In Design |
| Presentation | audiofb | 7 | In Design (W-07 fix pending) |
| Presentation | bossui | 6 | In Design |
| **Total** | | **117** | |

---

## Phase 3: Traceability Matrix

Trivial — every TR is a gap. Compressed matrix:

```
| TR-input-* (5)        → ❌ GAP — no ADR
| TR-audio-* (7)        → ❌ GAP — no ADR
| TR-save-* (6)         → ❌ GAP — no ADR
| TR-camera-* (5)       → ❌ GAP — no ADR
| TR-health-* (7)       → ❌ GAP — no ADR
| TR-movement-* (5)     → ❌ GAP — no ADR
| TR-spell-* (7)        → ❌ GAP — no ADR
| TR-enemy-* (7)        → ❌ GAP — no ADR
| TR-zone-* (7)         → ❌ GAP — no ADR
| TR-slot-* (7)         → ❌ GAP — no ADR
| TR-ai-* (5)           → ❌ GAP — no ADR
| TR-hazard-* (3)       → ❌ GAP — no ADR
| TR-checkpoint-* (4)   → ❌ GAP — no ADR
| TR-dialogue-* (6)     → ❌ GAP — no ADR
| TR-material-* (6)     → ❌ GAP — no ADR
| TR-interaction-* (9)  → ❌ GAP — no ADR
| TR-upgrade-* (6)      → ❌ GAP — no ADR
| TR-boss-* (9)         → ❌ GAP — no ADR
| TR-hud-* (8)          → ❌ GAP — no ADR
| TR-vfx-* (7)          → ❌ GAP — no ADR
| TR-audiofb-* (7)      → ❌ GAP — no ADR
| TR-bossui-* (6)       → ❌ GAP — no ADR
```

---

## Phase 4: Cross-ADR Conflict Detection

**Skipped — no ADRs exist.**

When ADRs are written, the cross-GDD blockers from `gdd-cross-review-2026-05-09.md` will surface as ADR-vs-ADR conflicts unless the GDDs are reconciled first. Specifically:

- B-02/B-03/B-04/B-05 (Spell Interaction Engine) will manifest as conflicting integration contracts between any combat-flow ADR and any presentation-layer ADR.
- B-01 (HP scale) will manifest as an unresolvable damage-budget calibration in any health-system ADR.
- B-06 (missing `heal()`) will manifest as a missing API in the health-system ADR with a downstream caller in the upgrade-system ADR.

**Recommendation:** Fix all 6 blockers in the GDDs before writing any combat-related ADR.

---

## Phase 5: Engine Compatibility

**Skipped — no ADRs to audit.**

Engine reference state (verified):

- Engine: Godot 4.6 (post-cutoff, January 2026 release)
- Physics: Jolt (default in 4.6)
- Rendering backend: D3D12 default on Windows
- LLM training cutoff: ~Godot 4.3 — 4.4/4.5/4.6 require reference lookup before any API decision
- Risk areas (per `docs/engine-reference/godot/VERSION.md`): accessibility (AccessKit), variadic args, `@abstract`, shader baker, SMAA, glow rework, IK restored

Anticipated engine-sensitive ADRs that will require `Engine Compatibility` sections:

- ADR for state machine (LimboHSM addon — verify Godot 4.6 compat)
- ADR for camera (PhantomCamera2D addon — verify Godot 4.6 compat)
- ADR for dialogue (Dialogue Manager v2 addon — verify Godot 4.6 compat)
- ADR for physics integration (Jolt default — confirm 2D physics still uses Godot Physics 2D, not Jolt 2D)
- ADR for save format (FileAccess return type changed in 4.4 — relevant)

---

## Phase 5b: GDD Revision Flags

The cross-GDD review (2026-05-09) already documents 6 blockers and 10 warnings that require GDD revision. No new flags from this architecture review — the existing list is the prerequisite reading list.

| GDD | Required Revisions | Source |
|-----|--------------------|--------|
| `spell-interaction-engine.md` | B-02 (group coverage), B-03 (element type), B-04 (signal payload), B-05 (status signals) | Cross-GDD review |
| `hazard-system.md` | B-01 (damage recalibration to 6–14 HP scale) | Cross-GDD review |
| `health-system.md` | B-06 (add `heal()`), W-02 (dialogue invuln) | Cross-GDD review |
| `enemy-base-system.md` | B-03 (align element type with Spell Interaction Engine) | Cross-GDD review |
| `hud-system.md` | W-06 (dialogue suppression + boss bar deferral) | Cross-GDD review |
| `audio-feedback-system.md` | W-07 (cover `&"boss"` group), W-09 (signal sig alignment) | Cross-GDD review |
| `zone-room-system.md` | W-01 (Room respawn guard), W-05 (Progression dep) | Cross-GDD review |
| `save-load-system.md` | W-04 (missing save keys, flag API documentation) | Cross-GDD review |
| `spell-system.md` | W-03 (action name `cast` not `attack`), W-08 (canonical Fireball damage) | Cross-GDD review |
| `boss-system.md` | W-08 (calibration note alignment) | Cross-GDD review |
| `progression-system.md` | W-05 (does not exist — needs creation) | Cross-GDD review |

---

## Phase 6: Architecture Document Coverage

**Skipped — `docs/architecture/architecture.md` does not exist.**

When ADRs are complete, an `architecture.md` overview document should be authored to map systems → layers → ADRs. This is a pre-implementation deliverable.

---

## Required ADR Backlog (Prioritised)

The following 22 ADRs are the minimum architecture coverage for the 22 MVP systems. Foundation-layer ADRs must be Accepted before any Core/Feature ADR can be written.

### Foundation Layer ADRs (write first, no dependencies)

| ADR # | Title | TRs Covered | Engine-Sensitive |
|-------|-------|-------------|------------------|
| ADR-0001 | Autoload Singleton Architecture | TR-slot-001, TR-interaction-001, TR-vfx-001, TR-audiofb-001, plus implicit GameManager/SaveManager/AudioSystem | Yes — Godot autoload boot order |
| ADR-0002 | Signal Hub Pattern (GameManager) | TR-health-004, TR-spell-006, TR-slot-007, TR-boss-008, TR-material-006, TR-interaction-007/008/009, TR-upgrade-005 | Low |
| ADR-0003 | Save System Design | TR-save-001/002/003/004/005/006 | Yes — FileAccess 4.4 changes |
| ADR-0004 | Input Action Schema and Context Stack | TR-input-001/002/003/004/005, TR-spell-007 | Yes — Godot Input API |
| ADR-0005 | Camera Architecture (PhantomCamera2D) | TR-camera-001/002/003/004/005 | Yes — addon compat |
| ADR-0006 | Audio Bus, Pool, and Music State Machine | TR-audio-001/002/003/004/005/006/007 | Yes — AudioServer API |

### Core Layer ADRs (depend on Foundation)

| ADR # | Title | TRs Covered | Engine-Sensitive | Prerequisite |
|-------|-------|-------------|------------------|--------------|
| ADR-0007 | Damage and Status API Contract | TR-enemy-002, TR-interaction-004/005/006, TR-health-006 | Low | B-02, B-03 fixed in GDDs |
| ADR-0008 | Player + Enemy State Machines (LimboHSM) | TR-movement-001, TR-ai-001, TR-boss-005 | Yes — addon compat |
| ADR-0009 | Resource-Driven Spell System | TR-spell-001/002, TR-upgrade-002/003 | No |
| ADR-0010 | Health Component Contract | TR-health-001/002/003/005/007 | No | B-06 fixed in GDD |

### Feature Layer ADRs (depend on Core)

| ADR # | Title | TRs Covered | Engine-Sensitive | Prerequisite |
|-------|-------|-------------|------------------|--------------|
| ADR-0011 | Room and Zone Loading Pipeline | TR-zone-001/002/003/004/005/006 | Yes — scene loading API |
| ADR-0012 | Checkpoint and Respawn Priority | TR-checkpoint-001/002/003/004, TR-zone-007 | No | W-01 fixed in GDD |
| ADR-0013 | Spell Interaction Engine Integration Contract | TR-interaction-001/002/003/004/005/007/008/009, TR-vfx-004, TR-audiofb-002 | No | B-02, B-04, B-05 fixed in GDD |
| ADR-0014 | Boss Architecture (BaseBoss/BossConfig/Phases) | TR-boss-001/002/003/004/005/006/007/008/009 | No |
| ADR-0015 | Progression System (ability flag store) | (new TRs, GDD does not yet exist) | No | progression-system.md created |
| ADR-0016 | Material Economy and Cache Persistence | TR-material-001/002/003/004/005/006 | No |
| ADR-0017 | Hazard Component Pattern | TR-hazard-001/002/003 | No | B-01 fixed in GDD |
| ADR-0018 | Spell Slot System Contract | TR-slot-001/002/003/004/005/006/007 | No |
| ADR-0019 | Dialogue System Integration (DM v2) | TR-dialogue-001/002/003/004/005/006 | Yes — addon compat |

### Presentation Layer ADRs (depend on Feature)

| ADR # | Title | TRs Covered | Engine-Sensitive | Prerequisite |
|-------|-------|-------------|------------------|--------------|
| ADR-0020 | HUD Subscriber Pattern + Dialogue Suppression | TR-hud-001/002/003/004/005/006/007/008 | No | W-06 fixed in GDD |
| ADR-0021 | VFX Spawner and Status Component | TR-vfx-001/002/003/004/005/006/007 | Yes — CPUParticles2D budget |
| ADR-0022 | Audio Feedback Routing + Group Subscription | TR-audiofb-001/002/003/004/005/006/007 | No | W-07 fixed in GDD |

### Cross-Cutting

| ADR # | Title | Notes |
|-------|-------|-------|
| ADR-0023 | Frame Budget Allocation (60fps / 16.6ms) | Distributes budget across physics/AI/rendering/scripts. Write after combat ADRs to ground the numbers. |
| ADR-0024 | Engine Version Pinning and Post-Cutoff Risk | Documents Godot 4.6 commitment, Jolt 3D, D3D12 Windows default, addon compat list. |

---

## Recommended Implementation Order

```
Phase A — Fix GDD blockers (BLOCKING)
  └─ See gdd-cross-review-2026-05-09.md "Recommended Fix Order"
  └─ Re-run /design-review on each revised GDD
  └─ Re-run /review-all-gdds to confirm consistency before continuing

Phase B — Foundation ADRs (after Phase A)
  ├─ ADR-0001 (Autoload Singletons)
  ├─ ADR-0002 (Signal Hub)
  ├─ ADR-0003 (Save System)
  ├─ ADR-0004 (Input)
  ├─ ADR-0005 (Camera)
  └─ ADR-0006 (Audio)

Phase C — Core ADRs (after Phase B)
  ├─ ADR-0007 (Damage API) — unlocks combat
  ├─ ADR-0008 (State Machines)
  ├─ ADR-0009 (Spell Resource Model)
  └─ ADR-0010 (Health Contract)

Phase D — Feature ADRs (after Phase C)
  ├─ ADR-0013 (Spell Interaction Engine) — highest design risk
  ├─ ADR-0011, 0012, 0014, 0015, 0016, 0017, 0018, 0019

Phase E — Presentation ADRs (after Phase D)
  ├─ ADR-0020 (HUD)
  ├─ ADR-0021 (VFX)
  └─ ADR-0022 (Audio Feedback)

Phase F — Cross-Cutting (after Phase E)
  ├─ ADR-0023 (Frame Budget)
  └─ ADR-0024 (Engine Pinning)

Phase G — /architecture-review re-run → expect PASS
Phase H — /gate-check pre-production
```

---

## Blocking Issues (must resolve before PASS)

1. **No ADRs exist.** Architecture is unwritten. Core deliverable for the architecture phase.
2. **6 cross-GDD blockers unresolved.** ADRs written against current GDDs would inherit broken integration contracts.
3. **No Progression System GDD.** Ability gating is referenced by 4 systems but unspecified.
4. **No `architecture.md` overview.** No layer/system map, no data-flow diagram.
5. **No frame budget breakdown.** 60fps target stated but not allocated across systems.

---

## Verdict: 🔴 FAIL

Architecture phase is at zero. Output of this review:
- TR registry populated (117 entries) — provides stable IDs for future stories.
- ADR backlog defined (~22 ADRs across 4 layers).
- Implementation order specified.
- GDD blocker prerequisites flagged.

**Next action:** fix the 6 GDD blockers per `gdd-cross-review-2026-05-09.md`, then begin `/architecture-decision` for ADR-0001.
