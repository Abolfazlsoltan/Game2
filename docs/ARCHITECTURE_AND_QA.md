# Architecture and QA Roadmap

## Why this exists

The current game is intentionally small but puts data, simulation, rendering, input, audio, menus and persistence into scripts/game.gd. Splitting it all at once would be high risk. This roadmap gives future contributors a safe migration order.

## Safe extraction order

### 1. Stabilize the baseline
- Keep a known-good APK artifact for comparison.
- Run editor import, simulation smoke test and Android export in CI.
- Add manual phone checks for menu/map/battle/pause/result and progress persistence.
- Record the starting behavior before altering movement, unit stats or touch rectangles.

### 2. Extract data first
Move unit stats, unit order and stage definitions into a data-only script or resource. Validate every unit key referenced by a stage, every unlock name, costs/population/training times, and required objective fields. There must be one source of truth for values used by both simulation and UI.

### 3. Extract save service
Create a small service with a versioned save format and validation. It must accept old saves that contain campaign.unlocked, campaign.wins, campaign.sfx and campaign.stars. Invalid/missing fields should fall back safely. Save to a temporary file then replace the primary save where supported, and do not erase valid progress on a transient read error.

### 4. Extract simulation systems
Separate training/economy, commands and unit behavior, combat/projectiles, enemy AI, statue/objective rules and effects. Preserve unit IDs and ownership invariants. Where possible, simulation functions should accept state and timestep explicitly so they can be tested without drawing.

### 5. Extract presentation
Keep gameplay rules out of draw functions. Gradually move battlefield drawing, unit animation, HUD controls, menus, campaign map and result screens into dedicated scripts/scenes. Use explicit data passed from the controller; avoid circular node lookups.

### 6. Extract input and audio
Normalize touch coordinates and define input ownership (joystick, unit selection, buttons, map scrolling). Add a testable layout map for touch targets. Audio service should expose named events plus master/music/SFX levels and safe mute handling.

### Suggested future layout

- scripts/core/game_controller.gd — high-level screen and lifecycle coordination
- scripts/data/unit_definitions.gd — single source of truth for units
- scripts/data/campaign_definitions.gd — stages, factions, objectives and rewards
- scripts/systems/battle_simulation.gd — battle tick and state transitions
- scripts/systems/economy_system.gd — mining, delivery, training and costs
- scripts/systems/combat_system.gd — attacks, damage, abilities and projectiles
- scripts/systems/ai_system.gd — enemy decisions and unit tactical behavior
- scripts/systems/save_service.gd — validation, migration and persistence
- scripts/ui/main_menu.gd — menu/settings/help
- scripts/ui/campaign_map.gd — territory path, locks, rewards and scrolling
- scripts/ui/battle_hud.gd — battle HUD and touch controls
- scripts/ui/result_screen.gd — reward/result actions
- scripts/presentation/battlefield_renderer.gd — terrain, statues, units and effects
- scripts/audio/audio_service.gd — music/SFX and volume settings
- tests/ — validation and headless simulation test scripts

Do not create empty files for every destination just to appear modular. Extract working code in small steps and keep the app playable after each one.

## CI contract

The Android workflow should run:
1. Godot headless editor import/validation.
2. Battle simulation smoke run using the built-in --smoke user argument; a failed assertion must exit non-zero.
3. Android debug export to build/SmallWarriors.apk.
4. ZIP integrity check and checks for AndroidManifest.xml and arm64 native library.
5. Artifact upload named SmallWarriors-Android-APK.

If the simulation smoke command fails due to a real gameplay regression, fix the regression or update the test only with an explained rationale. Do not weaken it just to get a green check.

## Test matrix

### Automated
- [ ] Project editor import completes without parser/resource errors.
- [ ] Smoke simulation proves friendly combat units advance or the battle ends legitimately.
- [ ] Unit/stage data validation catches unknown kinds, non-positive times/health, negative costs and invalid unlocks.
- [ ] Economy: miner delivery raises gold; training charges the right cost and population; failed training does not partially mutate state.
- [ ] Combat: damage is bounded; dead units stop acting; ranged units create and resolve projectiles; battle end triggers once.
- [ ] Orders: attack advances, defend holds a useful line, garrison retreats miners and combat units.
- [ ] Save migration: current saves still load; missing/corrupt values are clamped or safely reset without crashing.
- [ ] Campaign unlock and star records never regress after replaying a stage.
- [ ] Stress simulation with large armies and effects remains within performance budgets.
- [ ] APK archive and required Android files exist.

### Manual Android smoke
- [ ] Fresh install opens in landscape and the main menu is readable.
- [ ] All menu buttons respond once per tap; no stuck touch/pointer state.
- [ ] Campaign map has legible unlocked/locked states, rewards and usable back navigation.
- [ ] Recruit buttons show costs and queue progress and cannot be accidentally triggered by the joystick.
- [ ] Virtual joystick direction and action button behave correctly on touchscreens of different aspect ratios.
- [ ] Select and directly control each unit archetype; confirm the correct ability triggers.
- [ ] Pause, resume, restart, Android back, app background/resume, and result navigation work.
- [ ] Progress and sound preference persist after force-closing and reopening.
- [ ] Small screen, tall phone, and larger display layouts have no clipped controls.
- [ ] Sound effects/music are not unexpectedly loud; mute is respected immediately.
- [ ] Long battle with many units does not stutter, leak effects, or freeze.
- [ ] Install and test the APK from the newest successful workflow run, not an older artifact.

## Change log expectation

Every feature PR/commit should mention:
- behavior changed;
- files touched;
- automated checks run and result;
- manual checks still needed;
- known limitations or follow-up ticket.

## Current limitation

CI runs on a hosted Linux container and cannot replace real touch/device QA. A successful APK export verifies packaging, not the complete UI or gameplay experience.
