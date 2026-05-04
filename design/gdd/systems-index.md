# Systems Index: Wizrless

> **Status**: Approved
> **Created**: 2026-04-17
> **Last Updated**: 2026-04-17
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Wizrless is a metroidvania action-platformer built around three interlocking pillars: Spell Alchemy (emergent interactions between spells), Earned Truth (story delivered through boss fights, not passive lore), and Controlled Ascension (the player starts constrained and earns freedom). The mechanical scope reflects this: the deepest systems are the spell and interaction engines, the boss system, and the zone/room architecture that enables metroidvania structure. Foundation systems (input, audio, save, camera) unblock everything else and must be designed first. The critical design challenge is that the Spell System and Zone/Room System are both bottlenecks — seven other systems each depend on them — and both carry significant design risk that should be prototyped early.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Input System | Core | MVP | Designed | design/gdd/input-system.md | — |
| 2 | Audio System | Audio | MVP | Designed | design/gdd/audio-system.md | — |
| 3 | Save/Load System | Persistence | MVP | Designed | design/gdd/save-load-system.md | — |
| 4 | Camera System | Core | MVP | In Review | design/gdd/camera-system.md | — |
| 5 | Health System | Core | MVP | In Review | design/gdd/health-system.md | Save/Load |
| 6 | Movement System | Core | MVP | In Review | design/gdd/movement-system.md | Input, Camera |
| 7 | Spell System | Gameplay | MVP | In Review | design/gdd/spell-system.md | Input, Audio |
| 8 | Enemy Base System (inferred) | Gameplay | MVP | In Review | design/gdd/enemy-base-system.md | Health |
| 9 | Zone/Room System | Core | MVP | In Review | design/gdd/zone-room-system.md | Save/Load, Camera |
| 10 | Spell Slot System | Gameplay | MVP | In Review | design/gdd/spell-slot-system.md | Spell System, Input |
| 11 | Enemy AI System (inferred) | Gameplay | MVP | In Review | design/gdd/enemy-ai-system.md | Enemy Base, Movement |
| 12 | Hazard System (inferred) | Gameplay | MVP | In Review | design/gdd/hazard-system.md | Health, Zone/Room |
| 13 | Checkpoint/Respawn System (inferred) | Gameplay | MVP | In Review | design/gdd/checkpoint-respawn-system.md | Health, Zone/Room, Save/Load |
| 14 | Dialogue System | Narrative | MVP | In Review | design/gdd/dialogue-system.md | Zone/Room, Input |
| 15 | Material System | Economy | MVP | In Review | design/gdd/material-system.md | Enemy Base, Save/Load |
| 16 | Spell Interaction Engine | Gameplay | MVP | In Review | design/gdd/spell-interaction-engine.md | Spell System, Spell Slot |
| 17 | Spell Upgrade System | Economy | MVP | In Design | design/gdd/spell-upgrade-system.md | Material System, Spell System |
| 18 | Boss System | Gameplay | MVP | In Design | design/gdd/boss-system.md | Enemy Base, Health, Enemy AI, Spell Interaction Engine |
| 19 | HUD System | UI | MVP | In Design | design/gdd/hud-system.md | Spell Slot, Health |
| 20 | Spell VFX System | UI | MVP | Not Started | — | Spell System, Spell Interaction Engine |
| 21 | Audio Feedback System (inferred) | Audio | MVP | Not Started | — | Spell System, Health, Audio |
| 22 | Boss Dialogue UI (inferred) | UI | MVP | Not Started | — | Dialogue, Boss |
| 23 | Ability Gate System | Gameplay | Vertical Slice | Not Started | — | Spell System, Zone/Room, Spell Slot |
| 24 | Tutorial/Onboarding System (inferred) | Meta | Vertical Slice | Not Started | — | Movement, Spell System, Spell Slot |
| 25 | Map System (inferred) | UI | Vertical Slice | Not Started | — | Zone/Room, Ability Gates |
| 26 | Main Menu (inferred) | UI | Vertical Slice | Not Started | — | Save/Load |
| 27 | Settings System (inferred) | Meta | Vertical Slice | Not Started | — | Audio, Input |
| 28 | Pause Menu (inferred) | UI | Vertical Slice | Not Started | — | Save/Load, Settings |
| 29 | Accessibility System (inferred) | Meta | Vertical Slice | Not Started | — | Settings |
| 30 | Lore Fragment System (inferred) | Narrative | Alpha | Not Started | — | Zone/Room, Save/Load |

---

## Categories

| Category | Description |
|----------|-------------|
| **Core** | Foundation systems everything else depends on |
| **Gameplay** | The systems that make the game fun — combat, spells, AI, movement abilities |
| **Economy** | Resource creation and consumption — materials, upgrades |
| **Persistence** | Save state and continuity |
| **UI** | Player-facing information — HUD, menus, VFX, dialogue screens |
| **Audio** | Sound and music — bus management, SFX triggers, adaptive layers |
| **Narrative** | Story and dialogue delivery |
| **Meta** | Systems outside the core loop — tutorials, accessibility, settings |

---

## Priority Tiers

| Tier | Definition | Target Milestone |
|------|------------|-----------------|
| **MVP** | Required to test the core hypothesis: "Is spell combination discovery in a boss fight context engaging enough to experiment repeatedly, and does pre-boss dialogue create emotional investment?" | First playable prototype (2–3 months) |
| **Vertical Slice** | Required for one complete, polished zone experience. Needed before external playtesting. | Vertical slice (4–5 months) |
| **Alpha** | All features present. Polish layer added. | Full launch build (6–9 months) |

---

## Dependency Map

### Foundation Layer (no dependencies — design first)

1. **Input System** — all interaction routes through here; nothing runs without input abstraction
2. **Audio System** — music and SFX bus management; audio feedback is a core interaction signal (not polish)
3. **Save/Load System** — zone state, material inventory, and slot unlocks all require persistence from day one
4. **Camera System** — phantom_camera addon installed; zone traversal requires follow behavior immediately

### Core Layer (depends on Foundation only)

1. **Health System** — depends on: Save/Load
2. **Movement System** — depends on: Input, Camera
3. **Spell System** ⚠️ BOTTLENECK — depends on: Input, Audio
4. **Enemy Base System** — depends on: Health
5. **Zone/Room System** ⚠️ BOTTLENECK — depends on: Save/Load, Camera

### Feature Layer (depends on Core)

1. **Spell Slot System** — depends on: Spell System, Input
2. **Enemy AI System** — depends on: Enemy Base, Movement System (reads player position)
3. **Hazard System** — depends on: Health, Zone/Room
4. **Checkpoint/Respawn System** — depends on: Health, Zone/Room, Save/Load
5. **Dialogue System** — depends on: Zone/Room (triggers), Input (advance)
6. **Material System** — depends on: Enemy Base (drops), Save/Load
7. **Spell Interaction Engine** ⚠️ BOTTLENECK — depends on: Spell System, Spell Slot System
8. **Spell Upgrade System** — depends on: Material System, Spell System
9. **Boss System** — depends on: Enemy Base, Health, Enemy AI, Spell Interaction Engine
10. **Ability Gate System** (VS) — depends on: Spell System, Zone/Room, Spell Slot System

### Presentation Layer (depends on Feature)

1. **HUD System** — depends on: Spell Slot, Health
2. **Spell VFX System** — depends on: Spell System, Spell Interaction Engine
3. **Audio Feedback System** — depends on: Spell System, Health, Audio
4. **Boss Dialogue UI** — depends on: Dialogue System, Boss System
5. **Map System** (VS) — depends on: Zone/Room, Ability Gates
6. **Main Menu** (VS) — depends on: Save/Load
7. **Pause Menu** (VS) — depends on: Save/Load, Settings

### Polish Layer

1. **Tutorial/Onboarding System** (VS) — depends on: Movement, Spell System, Spell Slot
2. **Settings System** (VS) — depends on: Audio, Input
3. **Accessibility System** (VS) — depends on: Settings System
4. **Lore Fragment System** (Alpha) — depends on: Zone/Room, Save/Load

---

## Recommended Design Order

Design these systems in order. Foundation-layer systems unblock everything else. Independent systems at the same layer can be designed in parallel.

| Order | System | Priority | Layer | Effort |
|-------|--------|----------|-------|--------|
| 1 | Input System | MVP | Foundation | S |
| 2 | Audio System | MVP | Foundation | S |
| 3 | Save/Load System | MVP | Foundation | M |
| 4 | Camera System | MVP | Foundation | S |
| 5 | Health System | MVP | Core | S |
| 6 | Movement System | MVP | Core | M |
| 7 | **Spell System** ⚠️ | MVP | Core | L |
| 8 | Enemy Base System | MVP | Core | S |
| 9 | **Zone/Room System** ⚠️ | MVP | Core | L |
| 10 | Spell Slot System | MVP | Feature | M |
| 11 | Enemy AI System | MVP | Feature | M |
| 12 | Hazard System | MVP | Feature | S |
| 13 | Checkpoint/Respawn System | MVP | Feature | S |
| 14 | Dialogue System | MVP | Feature | M |
| 15 | Material System | MVP | Feature | S |
| 16 | **Spell Interaction Engine** ⚠️ | MVP | Feature | L |
| 17 | Spell Upgrade System | MVP | Feature | M |
| 18 | Boss System | MVP | Feature | L |
| 19 | HUD System | MVP | Presentation | M |
| 20 | Spell VFX System | MVP | Presentation | M |
| 21 | Audio Feedback System | MVP | Presentation | M |
| 22 | Boss Dialogue UI | MVP | Presentation | S |
| 23 | Ability Gate System | VS | Feature | M |
| 24 | Tutorial/Onboarding System | VS | Polish | M |
| 25 | Map System | VS | Presentation | M |
| 26 | Main Menu | VS | Presentation | S |
| 27 | Settings System | VS | Polish | S |
| 28 | Pause Menu | VS | Presentation | S |
| 29 | Accessibility System | VS | Polish | S |
| 30 | Lore Fragment System | Alpha | Polish | M |

*Effort: S = 1 session, M = 2–3 sessions, L = 4+ sessions. A session is one focused design conversation producing a complete 8-section GDD.*

⚠️ = bottleneck system — many other systems block on this one. Design and prototype early.

---

## Circular Dependencies

**None detected.** The dependency graph is acyclic. All system boundaries are clean.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Spell System | Design | Order-dependent interactions (ice→fire ≠ fire→ice) require the data model to track cast sequence, not just active spells. Wrong data model here propagates to Spell Interaction Engine and Boss System. | Design the data model in the GDD before any implementation. Prototype with 2 spells first. |
| Spell Interaction Engine | Design + Technical | With 15+ spells there are 105+ pairs, most undefined. System must handle undefined pairs gracefully without reading as a bug. "Undefined" must be a deliberate designed state. | GDD must spec the undefined-pair fallback explicitly. Run `/prototype spell-combo` before full implementation. |
| Zone/Room System | Technical | Non-linear metroidvania map requires upfront zone dependency mapping to avoid soft-locks and trivial sequence breaks. Wrong structure at this layer means level design is blocked. | GDD must include zone dependency graph as an appendix. Verify with a paper map before implementing. |
| Boss System | Scope | Each boss needs unique AI state machine, pre-fight dialogue, art, animation, and fight design. 7 bosses is ambitious for a solo timeline. The system must be flexible enough for distinct personalities without re-engineering per boss. | Design the system for data-driven boss configs. Validate with 1 boss at MVP before committing to the full system architecture. |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 30 |
| Design docs started | 19 |
| Design docs reviewed | 5 |
| Design docs approved | 3 |
| MVP systems designed | 19 / 22 |
| Vertical Slice systems designed | 0 / 7 |
| Alpha systems designed | 0 / 1 |

---

## Next Steps

- [ ] Design MVP Foundation systems first — run `/design-system input-system` to start
- [ ] Run `/design-review` on each completed GDD before moving to the next
- [ ] Run `/prototype spell-combo` early — the Spell Interaction Engine is the highest-risk MVP system
- [ ] Run `/gate-check pre-production` when all 22 MVP GDDs are designed
