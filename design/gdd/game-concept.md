# Game Concept: Wizrless

*Created: 2026-04-17*
*Status: Draft*

---

## Elevator Pitch

> The son of a banished demon grows up inside the very order that expelled his father — until they discover the truth and move to eliminate him before he realizes what he is and claims his birthright. A metroidvania where spell combinations are the weapon and former friends are the final bosses.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Metroidvania / Action-Platformer |
| **Platform** | PC (Steam) |
| **Target Audience** | Mid-core to hardcore action-platformer fans, 18–30 |
| **Player Count** | Single-player |
| **Session Length** | 30–90 minutes |
| **Monetization** | Premium |
| **Estimated Scope** | Medium-Large (6–9 months solo for launch build; 12+ months for full vision) |
| **Comparable Titles** | Hollow Knight, Blasphemous, Hades |

---

## Core Fantasy

You are a wizard who was never supposed to exist. The most powerful order in the world trained you, mentored you, called you brother — and has now sent every one of them to kill you before you understand why.

The fantasy is discovering your own forbidden nature in real time: each new spell you unlock is another piece of what you are. Every boss you defeat is someone who knew the truth and chose silence over loyalty. By the end, you are not a novice anymore. You are exactly what they were afraid of — and you chose what that means.

---

## Unique Hook

Like Hollow Knight, AND ALSO spells interact with each other in unexpected ways — fire and ice can cancel each other out, light and shadow amplify, conjuration and destruction produce unstable results — turning every boss fight into an experiment in arcane chemistry that the player must discover and master.

Spell interactions are not telegraphed by the UI — they are revealed progressively through lore, NPC dialogue, and the wizard's own growing understanding of his demonic heritage. Learning a new interaction IS a story beat.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Fantasy** (make-believe, role-playing) | 1 | Forbidden power arc, demonic heritage reveal, wizard identity |
| **Challenge** (obstacle course, mastery) | 2 | Boss fights requiring spell combo mastery, limited slot management |
| **Discovery** (exploration, secrets) | 3 | Hidden spell interactions, locked zones, lore fragments in the world |
| **Narrative** (drama, story arc) | 4 | Pre-boss dialogue with former allies, incremental truth reveal |
| **Expression** (self-expression, creativity) | 5 | Spell loadout customization, interaction discovery as personal knowledge |
| **Sensation** (sensory pleasure) | 6 | Spell visual/audio feedback, interaction effects, environmental atmosphere |
| **Fellowship** (social connection) | N/A | Single-player focused |
| **Submission** (relaxation, comfort zone) | N/A | Not a relaxation game |

### Key Dynamics (Emergent player behaviors)

- Players will experiment with spell combinations before boss fights to find effective interactions
- Players will revisit old areas once new spell slots unlock to explore previously blocked paths
- Players will pay close attention to pre-boss dialogue for both emotional and tactical information
- Players will feel reluctant to fight certain bosses — the game should make players briefly not want to win
- Players will speculate about the father's story and the order's full history between sessions

### Core Mechanics (Systems we build)

1. **Spell Slot System** — player has 1 spell slot initially, unlocks more through progression (max 5). Forces curated loadout decisions and creates meaningful build choices.
2. **Spell Interaction Engine** — spells cast in sequence or combination produce emergent effects (amplify, cancel, transform). Interactions revealed through lore/story progression, not tutorials.
3. **Boss-as-Story-Delivery** — each boss fight is preceded by dialogue that advances the narrative. Boss design reflects the relationship and personality of the character. Defeating a boss is a story event.
4. **Exploration & Material Gathering** — interconnected zones with ability gates. Materials found in the world are used to upgrade spell properties (damage, duration, range, interaction weight).
5. **Metroidvania Progression** — new spells and abilities unlock access to previously unreachable zones. The map expands as the wizard's power (and self-knowledge) grows.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Spell loadout selection, upgrade priorities, exploration order | Core |
| **Competence** (mastery, skill growth) | Mastering spell interactions, reading boss patterns, optimizing loadouts | Core |
| **Relatedness** (connection, belonging) | Emotional weight of fighting former friends; caring about the wizard's identity | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion, collection, progression) — How: collecting all spells, defeating all bosses, upgrading the full arsenal
- [x] **Explorers** (discovery, understanding systems, finding secrets) — How: discovering spell interactions, finding hidden lore, unlocking the map
- [ ] **Socializers** (relationships, cooperation, community) — Not a focus
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — Not a focus

### Flow State Design

- **Onboarding curve**: First zone teaches movement and a single spell. First boss is a classmate who still believes in the wizard — dialogue is sorrowful, fight is forgiving. The player understands stakes and tone before difficulty ramps.
- **Difficulty scaling**: Boss complexity scales with spell slot count. Early bosses are solvable with 1-2 interactions. Later bosses require multi-step combo chains and knowledge of interaction edge cases.
- **Feedback clarity**: Spell interactions produce distinct visual and audio feedback. Damage numbers are secondary to "did the effect trigger?" The player always knows if a combo worked.
- **Recovery from failure**: No permadeath. Death returns the player to the zone entrance with full spells. Defeat is educational — bosses have telegraphed patterns that become readable with repetition.

---

## Core Loop

### Moment-to-Moment (30 seconds)
Navigate the environment (forgiving platforming — traversal not punishment) → encounter enemies → select from equipped spell loadout → chain spells to trigger interactions → adjust based on enemy response → defeat and collect.

The 30-second loop is: **cast, observe, adapt**.

### Short-Term (5–15 minutes)
Clear a zone section → find a new spell or material cache → decide which spells to equip and which to upgrade → test the new loadout in the next section → approach a mini-challenge or locked gate with the new understanding.

### Session-Level (30–90 minutes)
Enter a zone → explore and gather → encounter environmental storytelling (notes, remnants of the order's presence) → reach the boss → pre-fight dialogue reveals a story beat → fight using everything learned in the zone → defeat unlocks new area and delivers a lore payoff → player is left with an unanswered question that pulls them into the next session.

### Long-Term Progression
- Spell slots grow: 1 → 2 → 3 → 4 → 5 (tied to story milestones)
- Spell library expands (targeting ~15–20 spells at launch)
- Interactions unlock through lore (not menu tutorials)
- Materials improve spell properties
- Truth about father's origin and the order's history unfolds boss by boss
- Final confrontation: the player chooses what kind of wizard — and what kind of demon — they are

### Retention Hooks

- **Curiosity**: "Why did [boss name] say that before the fight? What does it mean about my father?" — unanswered questions drive return
- **Investment**: Spell loadout is personally authored; players feel ownership over their build and want to keep refining it
- **Social**: N/A (single-player) — but shareable "which interactions did you discover first?" moments create organic community content
- **Mastery**: Harder optional challenges; faster boss completions; finding unexpected interaction chains

---

## Game Pillars

### Pillar 1: Spell Alchemy
*Every fight is an experiment. Player power comes from understanding, not grinding.*

*Design test*: "Should we add a new spell or a new interaction between existing spells?" → Spell Alchemy says **add the interaction** — depth from existing systems beats breadth from new content.

### Pillar 2: Earned Truth
*Story beats are rewards, not interruptions. Lore is unlocked through combat, not cutscenes.*

*Design test*: "Should this lore moment happen in a journal entry the player might miss, or in a pre-boss dialogue they cannot skip?" → Earned Truth says **pre-boss dialogue** — story must be earned and impossible to accidentally avoid.

### Pillar 3: Controlled Ascension
*The player starts small and ends formidable. Every unlock must feel earned, not given.*

*Design test*: "Should the player start with 2 spell slots to reduce early-game friction?" → Controlled Ascension says **1 slot** — feel the constraint before the freedom. The first new slot must feel like liberation.

### Anti-Pillars (What This Game Is NOT)

- **NOT randomized loot**: Would undermine Controlled Ascension — power must be found and chosen, not randomly dropped. Every spell acquisition is a deliberate story beat.
- **NOT multiplayer**: Would undermine Earned Truth — the story is a personal revelation. Shared experience diffuses the isolation that makes the wizard's situation emotionally real.
- **NOT punishing platforming**: Would compete with Spell Alchemy as the primary skill expression. Movement is traversal; combat is the test.
- **NOT passive stat trees**: Expression lives in spell combinations, not in numbers. A +15% fire damage node does not create the same discovery moment as "fire after ice cancels — but ice *after* fire explodes."

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Hollow Knight | Interconnected world, metroidvania structure, atmospheric tone | Spell interactions replace charm combos; story delivered through bosses not lore tablets | Validates the commercial viability of dark, deep 2D metroidvanias from small teams |
| Blasphemous | Boss encounters as lore delivery, dark religious aesthetic, pre-boss dialogue | Demonic/arcane aesthetic instead of Catholic horror; player IS the heresy, not fighting it | Proves players engage deeply with narrative embedded in boss fights |
| Hades | Narrative through encounter repetition, emotional weight in repeated NPC meetings | No roguelike reset — encounters are permanent, which raises the stakes of each boss fight | Shows that strong character writing on bosses creates emotional investment in combat |

**Non-game inspirations**: The Name of the Wind (Rothfuss) — a student wizard in a school that fears what he might become. Fullmetal Alchemist — power discovered through personal cost and understanding, not raw strength. Classic betrayal mythology (Dante, Paradise Lost) — the outcast who contains multitudes.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18–30 |
| **Gaming experience** | Mid-core to hardcore |
| **Time availability** | 1–2 hour sessions on evenings/weekends |
| **Platform preference** | PC |
| **Current games they play** | Hollow Knight, Dead Cells, Blasphemous, Hades |
| **What they're looking for** | A metroidvania with systemic depth and a story they want to see through to the end |
| **What would turn them away** | Punishing platforming that doesn't serve the challenge; thin story; spell combos that feel random rather than discoverable |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4 — already in active use; GDScript codebase, dialogue manager addon, phantom camera installed |
| **Key Technical Challenges** | Spell interaction system architecture (combination detection, effect resolution); Metroidvania map with non-linear ability gating; Boss state machines with personality-driven behavior |
| **Art Style** | 2D — pixel art or hand-drawn (TBD in /art-bible); dark fantasy palette, expressive spell VFX |
| **Art Pipeline Complexity** | Medium — custom 2D character/environment art; high-impact spell effect animations |
| **Audio Needs** | Moderate-high — spell audio feedback critical for interaction clarity; atmospheric music; voiced or text boss dialogue |
| **Networking** | None |
| **Content Volume** | ~15–20 spells, ~7 bosses, ~5–6 zones, ~8–12 hours completion time |
| **Procedural Systems** | None — hand-crafted zones and encounters preserve narrative intentionality |

---

## Risks and Open Questions

### Design Risks
- **Spell interaction balance**: With 15 spells, there are 105 possible pairs. Most won't have defined interactions, but the system must handle undefined pairs gracefully without feeling like a bug.
- **Boss differentiation**: 7 bosses who are all "former friends" risk feeling samey. Each must have a distinct personality, fighting style, and emotional dynamic.
- **Progression pacing**: Too many spells too early removes the constraint that makes loadout decisions interesting. Too few spells too late frustrates exploration.

### Technical Risks
- **Spell combination detection**: Order-dependent interactions (ice *then* fire vs fire *then* ice) require careful implementation in the combat system.
- **Metroidvania map gating**: Non-linear map design with ability gates requires upfront zone dependency mapping to avoid soft-locks or trivial sequence breaks.
- **Boss dialogue-to-combat transitions**: Pre-fight cutscene/dialogue must feel seamless rather than mode-switching. Godot's animation and dialogue systems need to work in concert.

### Market Risks
- **Saturated metroidvania market**: Hollow Knight casts a long shadow. Differentiation must be clear and legible in screenshots and trailers (spell combo VFX is the hook).
- **First game polish gap**: The genre expects high visual and mechanical polish (Hollow Knight set the bar). Scope discipline is essential.

### Scope Risks
- **Boss content density**: Each boss needs unique art, animation, dialogue, and fight design. 7 bosses is ambitious for a 6–9 month solo timeline.
- **Spell interaction content**: Each defined interaction needs design, implementation, and audio/visual feedback. This multiplies with spell count.

### Open Questions
- What is the right total number of spell interactions at launch? (Prototype answer: run /prototype spell-combo to find the minimum that feels rich)
- How does the player learn interactions exist without a tutorial? (Hypothesis: environmental hints + lore fragments + one "accidental discovery" early in zone 1)
- What does the endgame choice look like? Is it binary (embrace/reject demonic heritage) or nuanced? (Narrative design question for /design-system on the narrative system)

---

## Visual Identity Anchor

*Note: Full visual identity to be defined in /art-bible. This section captures the brainstorm-level anchor.*

**Direction**: Dark Academic Arcane
- The world looks like a prestigious institution whose walls are rotting from the inside. Stone corridors, library architecture, formal robes — all decaying under something that doesn't belong.
- The wizard's spells are the only color in most scenes. Spell VFX should be visually expressive and distinct per element — the player's power is literally the most vivid thing on screen.
- As the wizard's demonic power grows, a second visual language bleeds in: geometric, dark, wrong. Not evil — unfamiliar.

**Visual rule**: *The world is fading; the wizard is becoming.*

---

## MVP Definition

**Core hypothesis**: "Players find spell combination discovery in a boss fight context engaging enough to experiment repeatedly, and pre-boss dialogue creates emotional investment in the fight outcome."

**Required for MVP**:
1. 1 complete zone with platforming traversal and enemy encounters
2. 1 boss with unique pre-fight dialogue and fight design that rewards 1–2 discovered spell interactions
3. 6 spells with 3 defined interactions (1 cancel, 1 amplify, 1 unexpected result)
4. Spell slot system with 1 starting slot, 1 upgrade during the zone
5. Material collection with 1 upgrade path demonstrated

**Explicitly NOT in MVP**:
- Full story arc or father's history
- Metroidvania map gating / zone interconnection
- Spell upgrade depth beyond 1 example
- More than 1 boss

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 zone, 1 boss, 6 spells, 3 interactions | Core combat loop, slot system, dialogue | 2–3 months |
| **Vertical Slice** | 2 zones, 2 bosses, 10 spells, 6 interactions | Full loop + material upgrades + map gating demo | 4–5 months |
| **Launch Build** | 4–5 zones, 5–6 bosses, 15 spells, 10+ interactions | Complete story arc (abbreviated), full progression | 6–9 months |
| **Full Vision** | 5–6 zones, 7–8 bosses, 20 spells, 15+ interactions | Complete story, full material system, secrets layer | 12+ months |

---

## Next Steps

- [ ] Run `/setup-engine` — configure Godot 4 formally and populate technical-preferences.md
- [ ] Run `/art-bible` — define full visual identity before writing any GDDs (do this BEFORE design-system)
- [ ] Run `/design-review design/gdd/game-concept.md` — validate concept completeness
- [ ] Run `/map-systems` — decompose concept into individual systems with dependencies
- [ ] Run `/design-system` for each MVP system (combat, spell system, boss design, exploration, narrative)
- [ ] Run `/create-architecture` — master architecture blueprint and Required ADR list
- [ ] Run `/architecture-decision` ×N — one per decision in the Required ADR list
- [ ] Run `/gate-check` — validate readiness before committing to production
- [ ] Run `/prototype spell-combo` — validate the interaction loop before full implementation
- [ ] Run `/playtest-report` — validate core hypothesis after prototype
- [ ] Run `/sprint-plan new` — plan first sprint if prototype validates
