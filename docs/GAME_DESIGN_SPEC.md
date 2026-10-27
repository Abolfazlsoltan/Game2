# Game Design Specification — Small Warriors

## Product target

Small Warriors should grow from its current eight-battle prototype into a complete, touch-first, side-view stick-figure RTS. The reference is Stick War: Legacy's *genre-level* experience: mining and spending gold, unit training, army orders and direct control, a territory-style campaign, multiple modes, unlocks, difficulty, and satisfying battle feedback. Small Warriors must have its own identity, visual language, faction names, maps, animations, audio, writing, balance, and progression.

Reference feature list checked against the public Google Play description on 27 October 2026:
https://play.google.com/store/apps/details?id=com.maxgames.stickwarlegacy

That listing describes army formations and direct unit control, mining gold, sword/spear/archer/mage/giant unit archetypes, a campaign and territory progression, missions, survival, tournament, difficulty crowns, skins with perks, and scenario variations. These are reference pillars, not a mandate to copy the original's assets or exact implementation.

## Current baseline — do not confuse this with the target

The repository currently provides:
- an original 2D landscape battlefield and statue objective;
- miner gold economy and six archetypes: Miner, Sword, Archer, Spear, Mage, Giant;
- training queues, population cap, enemy AI and projectiles;
- Attack, Defend and Garrison orders;
- direct control and unit skills;
- an eight-stage data-driven campaign with unlocks and 0–3 stars;
- custom-drawn menus/map/HUD/results and generated audio;
- local progression saving.

Many target features are not present yet. This document is a plan and acceptance contract, not a claim that every item is implemented.

## Core battle loop

1. Start with a small budget, a protected home monument and a limited number of units.
2. Assign miners to gather ore and carry gold back to the base. Mining must visibly show progress, carrying, delivery, and feedback when resources increase.
3. Spend gold and population to train units. Training queues must show cost, duration/progress, queued units, and clear disabled/unavailable states.
4. Choose an army command: advance, hold/defend, or retreat/garrison. Later formations should include compact, balanced, and ranged-protection options.
5. The player may select a soldier and directly control movement and its special action. The virtual joystick/action control must never block common battle UI targets.
6. Units make role-appropriate decisions: melee closes distance, ranged units maintain distance and aim, defenders guard allies/base, miners avoid danger and return to work, and heavy units create readable area impact.
7. Win by destroying the enemy monument or completing the current scenario objective. Lose if the home monument falls or the specific scenario's failure condition triggers.

## Battle HUD requirements

- Gold, population used/cap, home and enemy monument health, stage name, and objective remain readable at phone landscape sizes.
- Recruitment buttons show distinct original icons, unit name/cost, queue/progress, availability, and a short help tooltip or detail panel.
- Special abilities display availability, cooldown/resource cost, and a clear unavailable state.
- Army orders have a visible selected state and immediate feedback when changed.
- Selected-unit status shows health, role, and ability state. Direct-control joystick and action button must have large touch targets and must not overlap training controls.
- Pause/settings/back handling must work through touch and Android system navigation.
- No tiny text, clipped labels, invisible touch targets, or ambiguous icon-only actions without an accessible hint.
- Provide readable contrast, non-color-only team indicators, reduced screen shake, and volume controls.

## Unit and faction roadmap

Keep roles distinct rather than merely changing health and color.

- Miner: gather, carry, deliver, optionally flee or garrison; the economy should be visible and understandable.
- Fast melee: low-cost, fast pressure; leap/rage-style ability may be introduced with an original animation.
- Archer: ranged single-target damage, deliberate aim and projectile travel; protect it from close combat.
- Spear/shield defender: durable front line, block or defensive stance.
- Mage/support: costly area damage or a support effect; telegraph attacks so damage is readable and fair.
- Giant/heavy unit: slow, high-impact frontline, area attack with a visible wind-up.
- Future faction-specific units: add only when each fills a distinct gameplay role and receives original art/animations/AI.

Each unit needs an explicit data definition for cost, population, training duration, health, movement, attack style, range, damage, attack interval, ability, unlock conditions, and AI behavior. Balance values should be data-driven and covered by basic validation rather than duplicated across UI and simulation.

## Campaign and progression

Target a campaign with a main story arc and bonus encounters, presented as a scrollable territory/saga map. The current eight stages are a foundation, not the finish line.

- Use data-defined stage nodes with name, original thumbnail/environment, enemy roster, objectives, restrictions, rewards, recommended difficulty, prerequisites and unlocks.
- Add Normal, Hard and Insane difficulty through explicit multipliers/rules; do not make difficulty a single hidden damage multiplier.
- Award up to three medals/stars based on clear, explainable conditions such as monument health, time, or optional objective completion.
- Save unlocked nodes, best rewards, selected difficulty, records, and settings. A fresh install, corrupted save and upgrade from the current format must all have safe behavior.
- Make progress map navigation work with touch and provide clear locked/unlocked/completed states.
- Do not block core offline play behind sign-in, ads, or network services.

## Modes — phased delivery

### Phase A: finish and stabilize classic battles
- Polish the current eight encounters, combat roles, tutorial, pause/settings, training HUD, progression and save behavior.
- Validate all six current unit types and all army orders.
- Add selectable difficulty and scenario modifiers with clear instructions.

### Phase B: full campaign
- Expand the campaign content, enemy faction identities, environments and bonus encounters.
- Add stage-specific events/objectives, optional rewards, and improved territory map progression.
- Give every stage a distinct tactical decision rather than only inflating enemy health.

### Phase C: tournament
- Build a bracket/ladder of AI challengers with escalating, varied rosters.
- Add tournament rules, match result/reward screens, run progression and a clear final reward.
- Save the best result and safely resume or restart a run.

### Phase D: endless survival
- Create escalating enemy waves and increasingly difficult night cycles.
- Use survival objectives rather than requiring an enemy statue in every mode.
- Provide between-wave breathing room, repair/recruit decisions, high-score records, and an end-of-run summary.

### Phase E: missions and challenge scenarios
- Add a local data-driven mission catalog that can be updated with app releases, with a future optional feed design that does not break offline access.
- Support modifiers such as a time limit, restricted roster, defended resources, fortified monument, a mini-boss, or a special win condition.
- Keep mission definitions separate from core battle logic.

### Phase F: unlocks, cosmetics and polish
- Add original unit looks and equipment. Any gameplay perks must be balanced, clearly described, and obtainable without manipulative monetization.
- Add upgrade choices with costs, caps, previews, and explicit effects.
- Improve sound, animation timing, impact effects, environmental variety, settings and first-run tutorial.
- Add localization support before adding large amounts of new interface text.

## Visual direction

Use the existing dark/navy and warm-gold foundation, with a restrained secondary accent for friendly units and a separate enemy treatment. Improve the battlefield with layered distant terrain, parallax-like slow background movement, ore deposits, original monumental silhouettes, readable shadows, weapon trails/projectiles, hit reactions and role-specific poses. Maintain stable frame timing on low-end Android devices.

Do not imitate exact screenshots pixel-for-pixel and do not use extracted game sprites, logos, sound effects, level art, names, or text. The goal is a polished original game with comparable systems and clarity.

## Performance and reliability targets

- 60 FPS target on typical Android devices; stable 30 FPS minimum on low-end supported devices during large battles.
- Avoid per-frame expensive resource generation, avoid unbounded arrays for particles/projectiles, and cap active effects.
- Update simulation with a capped timestep; separate simulation updates from redraw work where practical.
- No stalled UI when many units are active. If profiling reveals spikes, add repeatable stress scenarios.
- Save only at sensible checkpoints and on pause/quit, not every frame.
- Preserve the existing arm64 APK export until other architectures are intentionally tested.
