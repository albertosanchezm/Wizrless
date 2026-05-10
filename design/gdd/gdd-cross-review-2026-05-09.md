# Cross-GDD Review Report — 2026-05-09

**Scope:** All 22 MVP system GDDs  
**Mode:** Full (consistency + design theory + scenario walkthroughs)  
**Reviewer:** `/review-all-gdds` automated process  
**Branch:** dev

---

## Quick Summary

| Category | Count |
|----------|-------|
| 🔴 BLOCKER | 6 |
| ⚠️ WARNING | 10 |
| ℹ️ INFO | 5 |

**6 blockers must be resolved before architecture phase begins.** All 6 are in the Spell Interaction / Presentation layer and form a cluster — fixing the signal contract (B-04 / B-05) will unblock B-02, B-03, and the VFX/Audio systems simultaneously. B-01 (HP scale) and B-06 (missing `heal()`) are independent.

---

## Phase 2: Cross-GDD Consistency

### 2a. Dependency Bidirectionality

**Missing reciprocal entries:**

| GDD-A references | GDD-B | GDD-B mentions GDD-A? |
|-----------------|-------|----------------------|
| SpellVFX → SpellInteractionEngine | SpellInteractionEngine | ✗ |
| AudioFeedback → SpellInteractionEngine | SpellInteractionEngine | ✗ |
| AudioFeedback → HealthSystem | HealthSystem | ✗ |
| BossDialogueUI → HUD System | HUD System | ✗ |
| BossDialogueUI → Boss System | Boss System | ✗ |
| SpellUpgrade → HealthSystem (calls `heal()`) | HealthSystem | ✗ |
| Movement → "Progression System" | (no GDD exists) | ✗ |
| SpellSlot → "Progression System" | (no GDD exists) | ✗ |
| ZoneRoom → "Progression System" | (no GDD exists) | ✗ |

**Most critical:** Boss Dialogue UI places explicit implementation requirements on HUD System, but HUD System's Dependencies section does not list Boss Dialogue UI — so HUD implementers will not see this requirement.

---

### 2b. Rule Contradictions

**🔴 B-01 — HP Scale Mismatch: Health vs Hazard**

```
health-system.md:   BASE_HEALTH = 6, max with upgrades = 14
hazard-system.md:   "hit budget" references "Player max HP = 100"
hazard-system.md:   GroundSpike DAMAGE = 20
```

At base health 6, a single GroundSpike (20 damage) exceeds max HP — instant kill. The Hazard GDD was calibrated against a 100 HP scale that does not exist in this game. Hazard damage values require a full re-calibration against the 6–14 HP range from `health-system.md`.

**⚠️ W-01 — Room Respawn Override Conflict**

```
zone-room-system.md:        Room._ready() unconditionally calls GameManager.set_respawn()
checkpoint-respawn-system.md: Room._ready() must NOT call set_respawn() if active checkpoint
                               is in this room (checkpoint_room == self.scene_file_path)
```

Zone/Room GDD neither mentions this guard nor lists Checkpoint as a dependency. An implementer reading only Zone/Room GDD will ship the broken version.

**⚠️ W-02 — Dialogue Invulnerability Missing from Health Flow**

```
dialogue-system.md EC-05:    player gets full invulnerability during dialogue_active = true
health-system.md damage flow: iframe check → clamp → reduce → emit → set iframes → death check
```

No `dialogue_active` check in the Health System damage flow. Enemies can damage the player during the pre-fight Devium dialogue. The Dialogue GDD defines this rule; the Health GDD must implement it.

---

### 2c. Stale References

**⚠️ W-03 — Spell System Action Name**

```
spell-system.md Dependencies: action "attack" triggers the cast
input-system.md:               canonical action is named "cast", not "attack"
```

Stale reference. The Input System was likely iterated after the Spell System GDD was written. All Spell System references to `"attack"` action should be `"cast"`.

**⚠️ W-05 — Progression System Referenced but No GDD Exists**

The following GDDs reference a Progression System or `GameManager.has_ability()`:
- `movement-system.md` — ability gating (Dash, wall-jump)
- `health-system.md` — HP upgrade unlocks
- `spell-slot-system.md` — slot unlock milestones
- `zone-room-system.md` — `RoomExit.required_ability`

No `progression-system.md` exists. `GameManager.has_ability()` is undefined. How ability unlocks are triggered, stored, and checked is unspecified in any GDD.

**⚠️ W-04 — Save Keys Not in Save/Load Registry**

```
dialogue-system.md:    saves "seen_dialogues" — not listed in save-load-system.md known keys
spell-slot-system.md:  saves slot_count, known_spell_ids, equipped_spell_ids, active_index
                        — none in save-load-system.md known keys
material-system.md:    flag-based API (get_flag/set_flag) for MaterialCache
                        — save-load-system.md describes provider-based API only
```

The Save/Load GDD is the authoritative registry of save keys. It is incomplete. Implementers building the save system will not know these keys exist.

---

### 2d. Tuning Knob Ownership Conflicts

**⚠️ W-08 — Fireball Damage Dual Ownership**

```
spell-system.md:       Fireball BASE_DAMAGE = 20
enemy-base-system.md:  FIREBALL_DAMAGE = 10 (used in Devium burn interaction design)
boss-system.md:        fight duration formula uses "player dealing 10 HP/hit"
```

Two GDDs define Fireball's effective damage differently. Spell System is authoritative for the projectile. Enemy Base and Boss System calibrate against a value that is half the Spell System value. All balance math in Boss/Enemy GDDs is off by ×2.

**No other tuning knob conflicts found.** All other knobs are owned by a single GDD.

---

### 2e. Formula Compatibility

**🔴 B-01 (detailed) — Damage Formula vs HP Range**

```
Hazard GroundSpike: DAMAGE = 20
Health base HP:     6
Health max HP:      14
```

`DAMAGE / HP_range = [20/6, 20/14] = [333%, 143%]`  
GroundSpike is a 1–3-hit kill across all player health states. Intentional? Hazard GDD says "3 hits kills an unupgraded player" — this requires `DAMAGE = 2` at base health 6, not 20. Re-calibrate before architecture.

**⚠️ Formula Compatibility: Ice Shard + Rupture**

```
spell-system.md:              Ice Shard cost 25 mana (FROZEN primer, 15 dmg)
spell-system.md:              Rupture cost 35 mana (25 base dmg)
spell-interaction-engine.md:  Cryoblast = FROZEN + RUPTURE → ×3.0
```

Combined cost: 60 mana. Combined damage: 15 + 75 = 90.  
Fireball spam equivalent in same time window (3s): ~40 damage.  
Combo is 2.25× more efficient. This is intentional for Spell Alchemy pillar, but is the highest-damage combo accessible from turn 1 — no gating. Monitor in playtesting.

---

### 2f. Acceptance Criteria Contradictions

**🔴 B-01 (AC version) — Hazard vs Health**

```
hazard-system.md AC:    "3 GroundSpike hits kill an unupgraded player"
health-system.md:       BASE_HEALTH = 6, GroundSpike DAMAGE = 20
```

`6 / 20 = 0.3` — one hit kills. The AC cannot pass if GroundSpike DAMAGE stays at 20 and base health is 6.

**Boss Dialogue UI vs HUD — Boss Bar Timing**

```
boss-dialogue-ui.md AC-BDU-005: boss health bar NOT visible during dialogue
hud-system.md:                  boss_appeared → immediately show bar
```

HUD GDD has no deferral logic. AC-BDU-005 cannot pass without changes to HUD that are not specified in the HUD GDD.

---

## Phase 3: Game Design Holism

### 3a. Progression Loop Competition

**CLEAN.** One clear primary loop: Explore → Fight → Collect Materials → Upgrade Spells → Access new areas. SpellSlot unlocks are story-milestone-gated, not grind-gated. No competing XP systems. No second progression currency competing with materials.

### 3b. Player Attention Budget

**Active systems during boss combat:**

| # | System | Demand type |
|---|--------|-------------|
| 1 | Movement (Dash, Jump, position) | Active — requires constant input |
| 2 | Spell casting + cooldown tracking | Active — timing decisions |
| 3 | Spell cycling / loadout choice | Active — tactical selection |
| 4 | Status effect combo opportunities | Active — pattern recognition |
| 5 | Boss pattern reading | Active — threat anticipation |

5 simultaneously active systems in boss fights. Research threshold for comfortable play is 3–4. However, this is a focused single-player action game — Hollow Knight, Dead Cells, and comparable titles run at 5+ concurrent active systems. Not automatically a problem, but worth monitoring in first playtests. If players report overwhelm, status effect tracking is the first candidate for simplification (make statuses more visually distinct so they're passive reads).

### 3c. Dominant Strategy Detection

**⚠️ Light Bolt has no synergy pathway**

All 5 other spells either deal high damage, apply a status (FROZEN, BURNING, MARKED), or trigger interactions. Light Bolt (18 dmg, no status, no interaction) is the only spell with no combo identity. Compared to Fireball (20 dmg + BURNING primer, same cost), Light Bolt is dominated on both damage and utility.

**Recommendation:** Give Light Bolt a role no other spell fills. Options: shortest cooldown (0.8s instead of 1.5s), bonus damage on MARKED targets (Light + Mark → Amplify path), or an interaction it can trigger (MARKED + LIGHT = new combo).

**Ice Shard → Rupture (Cryoblast)** is the highest-value combo in the game at ×3.0 with stun. All other combos are ×1.5–2.0. Cryoblast's dominance is partially offset by Rupture's higher mana cost (35 vs 25). Monitor whether players find Cryoblast and then ignore other combos in extended play.

### 3d. Economic Loop Analysis

**Materials:**

| Resource | Sources | Sinks |
|----------|---------|-------|
| Ember | Enemy drops + world caches (finite) | Fireball/Inferno upgrades (5+8+12 = 25 total) |
| Frost Crystal | Same | Ice Shard upgrades |
| Radiance | Same | Light Bolt upgrades |
| Void Shard | Same | Shadow Tendril upgrades |
| Aether | Same | Conjure upgrades |
| Shatter | Same | Rupture upgrades |

**Economy is closed and finite — well-designed.**

**⚠️ W-10 — Element-Locked Material Surplus**

Material type is 1:1 with spell element. If a player never upgrades Ice Shard (or switches away from it), Frost Crystal accumulates with no sink. At MVP with 6 spell slots and 6 material types, a player who prefers 3 spells will have 3 surplus material types. This is not an exploit (economy is finite either way) but reduces the sense that all collected materials are valuable.

### 3e. Difficulty Curve Consistency

**No formal scaling formula across zones.** Enemy stats are per-instance exports (`@export`). No zone progression multiplier defined in any GDD. Difficulty is hand-crafted, not formulaic.

This is not inherently wrong, but it means there's no consistency check between zones. Recommend adding a "Zone Difficulty Table" to `zone-room-system.md` listing intended HP/damage ranges per zone so level designers have a reference.

### 3f. Pillar Alignment

**All systems serve at least one pillar. No drift detected.**

| Pillar | Primary GDDs |
|--------|-------------|
| Spell Alchemy | SpellSystem, SpellInteractionEngine, SpellVFX, AudioFeedback, SpellUpgrade |
| Earned Truth | BossSystem, BossDialogueUI, DialogueSystem, MaterialSystem, EnemyAI |
| Controlled Ascension | SpellSlot, HealthSystem, CheckpointRespawn, MovementSystem, ZoneRoom |

**Anti-pillars respected:**
- No randomized loot (✓ — materials are deterministic drops)
- No multiplayer (✓ — single-player only)
- No punishing platforming (✓ — Checkpoint/Respawn system is forgiving)
- No passive stat trees (✓ — all upgrades are spell-level, no background attribute grind)

### 3g. Player Fantasy Coherence

**Coherent.** All system fantasies converge on: *"a precise, dangerous wizard who understands the world's rules and earns power through mastery, not luck."*

Movement ("acrobatic precision"), Spell System ("every kill is earned"), SpellInteractionEngine ("combining spells creates spectacle"), BossSystem ("the boss is a specific dangerous person"), CheckpointRespawn ("death is a lesson") — these do not conflict.

---

## Phase 4: Cross-System Scenario Walkthroughs

### Scenario 1: Player applies FROZEN → triggers Cryoblast on a boss

**Trigger:** Player casts Ice Shard at Devium (boss).

**Step-by-step:**

1. Ice Shard projectile `body_entered` → `SpellInteractionEngine.process_hit(devium, SPELL_ICE, 15)`
2. **B-03:** `take_damage(15, SPELL_ICE)` — `SPELL_ICE` is `StringName`; `BaseEnemy.take_damage` expects `SpellElement` enum → GDScript type mismatch
3. **B-02:** After `_apply_status_if_primer()`, status tick uses `get_nodes_in_group(&"enemies")` → Devium (in `&"boss"`) not in group → FROZEN never ticks → duration never expires, DOT never damages
4. **B-04:** `status_applied` signal fires — but `SpellVFXSystem` and `AudioFeedbackSystem` subscribed to this signal **which does not exist in `SpellInteractionEngine`** → no frozen overlay, no frozen SFX
5. Player casts Rupture → `process_hit(devium, SPELL_RUPTURE, 25)` → checks `active_statuses["frozen"]` → Cryoblast triggers → `interaction_triggered(devium, SPELL_RUPTURE, 75)` fires
6. **B-05:** `SpellVFXSpawner` needs 4th param `interaction_name` to look up burst scene → gets only 3 params → uses wrong VFX or crashes dict lookup
7. **B-05:** `AudioFeedbackSystem` needs `interaction_name` as second param (current signal has `element` as second) → plays wrong SFX or crashes routing table lookup

**Result:** Cryoblast is the signature mechanic of the game's Spell Alchemy pillar. Against the game's only MVP boss, it produces a type error, no audio, wrong VFX, and the combo may not register at all due to status tick group mismatch. **This scenario is fully broken.**

---

### Scenario 2: Player enters Devium room — dialogue → fight transition

**Trigger:** Player crosses BossTrigger.

**Step-by-step:**

1. `BossTrigger.body_entered` → `BossIdleState` begins
2. `BaseBoss._ready()` already fired → `GameManager.boss_appeared("devium", "Devium", 200)` emitted
3. **W-06:** HUD receives `boss_appeared` → **immediately shows boss health bar** — no deferral logic in HUD GDD
4. AudioSystem: `EXPLORATION → BOSS_PREFIGHT` music transition (correct)
5. Camera: Dialogue System activates DIALOGUE pcam (layer 25) — correct
6. `BossIdleState` calls `show_dialogue_balloon()` — **Boss Dialogue UI GDD requires `show_dialogue_balloon_scene(BOSS_BALLOON, ...)`** — one-line discrepancy
7. `WizrlessBossBalloon` enters at CanvasLayer 5 — dim overlay at layer 5 is behind HUD at layer 10
8. **W-06:** HUD health pips, mana bar, and spell slots are **visible above the dim overlay** — visual is broken
9. **W-02:** Enemy in room hits player during dialogue → Health System processes damage (no `dialogue_active` check) → player can die mid-cutscene
10. Player advances through dialogue → exit tween → `queue_free()` → `tree_exited` → `_start_combat()`
11. **W-06:** `dialogue_ended` fires → HUD should reveal boss bar with 0.5s fade — but HUD GDD has no such logic; bar was already visible since step 3

**Result:** Post-dialogue sequence is cosmetically broken (HUD floats over dim overlay), player is vulnerable during dialogue, and boss health bar appears too early.

---

### Scenario 3: Player dies during boss fight → respawn

**Trigger:** Devium hits player, HP drops to 0.

**Step-by-step:**

1. `HealthSystem.take_damage()` → HP = 0 → `player_died` emitted
2. AudioFeedback: GUARANTEED `sfx_player_death` plays (correct)
3. HUD: boss health bar hides on `player_died` (correct)
4. Boss System EC-02: CombatBarrier deactivates (correct)
5. Camera: scene reload → pcam reset per Camera GDD T-11
6. `CheckpointRespawn`: player teleports to last activated checkpoint
7. `HealthSystem.respawn()`: sets `current_health = max_health` (correct)
8. New scene loads → `Room._ready()` fires
9. **W-01:** `Room._ready()` calls `GameManager.set_respawn()` **unconditionally** → checkpoint room pointer overwritten → next death will respawn at room entrance, not checkpoint

**Result:** First respawn is correct. If player activates a checkpoint, dies, respawns, and dies again — they respawn at the room entrance instead of the checkpoint. The checkpoint activation becomes a one-shot benefit.

---

### Scenario 4: Shadow Tendril T2 upgrade effect fires during combat

**Trigger:** Player casts Shadow Tendril (Tier 2) and projectile hits an enemy.

**Step-by-step:**

1. Shadow Tendril projectile `body_entered` → applies MARKED status
2. Tier 2 upgrade effect activates
3. **B-06:** `player.heal(5)` called → `Health System` has no `heal()` method (only `take_damage()` and `respawn()`) → **crash / undefined method error**

**Result:** Hard crash on first T2 Shadow Tendril hit. This blocks a core upgrade path entirely.

---

## Blocker Summary Table

| ID | Severity | Systems | Issue | Fix Owner |
|----|----------|---------|-------|-----------|
| B-01 | 🔴 BLOCKER | Hazard ↔ Health | Hazard DAMAGE=20 calibrated against HP=100; actual max HP is 14 | hazard-system.md |
| B-02 | 🔴 BLOCKER | SpellInteractionEngine ↔ BossSystem | Status tick uses `&"enemies"` group; bosses in `&"boss"` → combos never apply to bosses | spell-interaction-engine.md |
| B-03 | 🔴 BLOCKER | SpellInteractionEngine ↔ EnemyBase | `take_damage(element: StringName)` vs `take_damage(element: SpellElement)` type mismatch | enemy-base-system.md or spell-interaction-engine.md (choose one) |
| B-04 | 🔴 BLOCKER | SpellInteractionEngine ↔ SpellVFX ↔ AudioFeedback | `interaction_triggered` needs `interaction_name: StringName` as param; current sig has `element` | spell-interaction-engine.md (coordinated change) |
| B-05 | 🔴 BLOCKER | SpellInteractionEngine ↔ SpellVFX ↔ AudioFeedback | `status_applied` and `status_expired` signals not defined in SpellInteractionEngine GDD | spell-interaction-engine.md |
| B-06 | 🔴 BLOCKER | SpellUpgrade ↔ HealthSystem | T2 Shadow Tendril calls `player.heal(5)` — method does not exist in HealthSystem | health-system.md (add `heal()`) |

---

## Warning Summary Table

| ID | Severity | Systems | Issue |
|----|----------|---------|-------|
| W-01 | ⚠️ | ZoneRoom ↔ Checkpoint | `Room._ready()` unconditionally calls `set_respawn()` — checkpoint override |
| W-02 | ⚠️ | Dialogue ↔ Health | Dialogue invulnerability not in Health damage flow |
| W-03 | ⚠️ | Spell ↔ Input | Spell System calls action `"attack"`, Input System defines `"cast"` |
| W-04 | ⚠️ | Dialogue/SpellSlot ↔ SaveLoad | seen_dialogues + slot save keys not in Save/Load GDD |
| W-05 | ⚠️ | Movement/Health/SpellSlot/ZoneRoom | No Progression System GDD — `GameManager.has_ability()` undefined |
| W-06 | ⚠️ | BossDialogueUI ↔ HUD | HUD GDD missing: (1) HUD suppression during dialogue, (2) boss bar deferral, (3) boss bar 0.5s fade-in |
| W-07 | ⚠️ | AudioFeedback ↔ Boss | Boss death SFX won't play — `AudioFeedbackSystem` subscribes only to `&"enemies"` group |
| W-08 | ⚠️ | Spell ↔ EnemyBase ↔ Boss | Fireball damage: Spell GDD = 20; Enemy/Boss calibration = 10 HP/hit |
| W-09 | ⚠️ | SpellVFX ↔ AudioFeedback | `status_applied` signature conflict: SpellVFX needs 3 params (includes `duration`), AudioFeedback needs 2 |
| W-10 | ⚠️ | Material ↔ SpellUpgrade | Element-locked materials create potential valueless surplus for unused spells |

---

## Info Table

| ID | Systems | Note |
|----|---------|------|
| I-01 | BossDialogueUI / HUD | Boss bar timing: `boss_appeared` fires before dialogue — bar visible during dialogue if W-06 not fixed |
| I-02 | Spell / Input | `move_up` action used by Spell System for aiming — verify this action is registered in Input System |
| I-03 | SpellInteractionEngine | No difficulty curve formula across zones — hand-crafted per enemy. Add zone difficulty table to ZoneRoom GDD. |
| I-04 | HUD | Phase 2 threshold (60% HP) has no visual marker at MVP — acknowledged as polish task in HUD GDD |
| I-05 | SpellSystem | Light Bolt has no combo synergy pathway — may be dominated by Fireball in extended play |

---

## Recommended Fix Order

**Do first (unblock architecture phase):**

1. **B-03** — Decide on `SpellElement` enum vs `StringName` across all combat APIs. This choice cascades everywhere. Recommendation: `StringName` (data-driven, avoids enum imports across files). Update `enemy-base-system.md` and `spell-system.md`.

2. **B-04 + B-05** — Update `spell-interaction-engine.md` with:
   - New `interaction_triggered(enemy, interaction_name, final_damage)` signature (drop `element`, add `interaction_name`)
   - New `status_applied(enemy, status_id, duration)` signal — use 3-param form to satisfy SpellVFX (W-09 resolved in favor of SpellVFX's 3-param spec; AudioFeedback GDD has wrong spec — fix that GDD too)
   - New `status_expired(enemy, status_id)` signal
   - Update status tick to include `&"boss"` group: `get_nodes_in_group(&"enemies") + get_nodes_in_group(&"boss")` → resolves B-02

3. **B-01** — Recalibrate `hazard-system.md` damage values against Health System's 6–14 HP range. Suggest: GroundSpike DAMAGE = 2 (1-hit = 33% base HP), DamageZone tick = 1/s, KillZone = instant (unchanged).

4. **B-06** — Add `heal(amount: int)` to `health-system.md` with spec: clamp to max_health, emit `health_changed`, no iframe interaction.

**Do second (before feature complete):**

5. **W-05** — Create `progression-system.md` stub GDD. Define `GameManager.has_ability()` contract, ability list, how unlocks are triggered.

6. **W-06** — Update `hud-system.md` with: subscribe to `DialogueManager.dialogue_started/ended`, suppress HUD elements during `dialogue_active`, defer boss bar until `dialogue_ended`, add `BOSS_BAR_REVEAL_DURATION = 0.5s` fade-in.

7. **W-01** — Update `zone-room-system.md` Room respawn rule: `if GameManager.checkpoint_room != self.scene_file_path: set_respawn()`

8. **W-02** — Update `health-system.md` damage flow: add `dialogue_active` check before iframe check (step 0 in flow).

9. **W-04** — Update `save-load-system.md` known keys to include: `seen_dialogues`, `slot_count`, `known_spell_ids`, `equipped_spell_ids`, `active_index`. Clarify flag-based API (`get_flag/set_flag`) alongside provider-based API.

**Do before ship (polish/consistency):**

10. **W-08** — Align Fireball damage. Recommend: Spell System is authoritative. Update Enemy Base and Boss System calibration notes to use 20 HP/hit.

11. **W-03** — Update Spell System references from `"attack"` action to `"cast"`.

12. **W-07** — Update `audio-feedback-system.md` enemy subscription to include `&"boss"` group, or update Boss System to add bosses to `&"enemies"` group as well.

13. **I-05** — Design direction decision: give Light Bolt a unique mechanic (shorter cooldown, bonus damage vs MARKED targets, or new interaction) to prevent it being dominated by Fireball.

---

## GDDs Requiring Revision

| GDD | Changes Required | Priority |
|-----|-----------------|----------|
| `spell-interaction-engine.md` | B-02, B-03, B-04, B-05 — signal redesign, group fix, API type | Critical |
| `hazard-system.md` | B-01 — damage recalibration | Critical |
| `health-system.md` | B-06 (add heal), W-02 (dialogue check) | Critical |
| `hud-system.md` | W-06 — dialogue suppression + boss bar deferral | High |
| `zone-room-system.md` | W-01 — respawn guard, W-05 dep reference | High |
| `save-load-system.md` | W-04 — add missing save keys, flag API | High |
| `enemy-base-system.md` | B-03 — take_damage type decision | High |
| `audio-feedback-system.md` | W-09 signal sig fix, W-07 group fix | Medium |
| `boss-system.md` | W-08 calibration note | Medium |
| `spell-system.md` | W-03 action name, W-08 canonical source | Medium |
| `progression-system.md` | W-05 — create this GDD | Medium |
| `spell-vfx-system.md` | W-09 signal sig (use 3-param) | Low |
