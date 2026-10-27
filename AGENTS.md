# Agent Instructions — Small Warriors

## Mission

Develop Small Warriors into a polished Android real-time strategy game with the breadth of systems and the mobile-first battle flow associated with Stick War: Legacy, while retaining original art, names, audio, maps, and story. Match the genre's gameplay pillars; do not copy proprietary assets, exact level layouts, logos, text, or source code.

## Non-negotiable project constraints

- Engine: Godot 4.5. Keep the Compatibility renderer unless a tested migration is approved.
- Primary target: Android, landscape, touch-first; desktop keyboard controls remain useful for development.
- Keep the current Android export pipeline working. Do not casually change the CI image, SDK versions, export preset, package id, artifact name, or APK output path.
- Existing game logic is concentrated in scripts/game.gd. Inspect the current source before changing it. Avoid replacing the entire file or performing a one-shot rewrite.
- Preserve campaign progress compatibility with user://small_warriors.cfg. If the save schema changes, migrate old saves safely and retain a reset/recovery path.
- Use new original visual/audio assets and a coherent visual identity. Never require copied assets from the reference game.
- Do not claim a feature or test is complete without implementing it and verifying it.

## Required workflow for every gameplay change

1. Inspect the current code and recent commits. Establish the exact behavior being changed.
2. Make the smallest coherent change and describe its intended effect.
3. Run the headless editor/import validation.
4. Run the battle simulation smoke test: Godot headless with user argument --smoke.
5. Export the Android debug APK, validate the ZIP, and verify AndroidManifest.xml plus the arm64 native library are present.
6. For input/UI/save changes, document a phone test checklist. CI passing alone is not proof that touch behavior or visuals are correct on a physical phone.
7. Keep the change focused. Do not combine a broad visual redesign, AI rewrite, and save migration in one commit.

## Current verified baseline

- Main scene: scenes/main.tscn.
- Main controller and drawing code: scripts/game.gd.
- Unit/stage configuration and most combat behavior currently live in that same script.
- Android workflow: .github/workflows/build-apk.yml.
- A --smoke path exists in game.gd. It must fail with a non-zero process exit when its movement assertion fails.
- Current player-facing app name: Small Warriors.
- Current campaign: 8 data-defined encounters, six unit archetypes, miner economy, attack/defend/garrison orders, direct unit control, and saved stars/unlocks.

## Architecture direction

Prefer an incremental migration toward the following responsibilities, keeping the playable game intact after each step:

- data: unit stats, stage definitions, faction definitions, balance values;
- campaign: map progression, unlocks, stage modifiers, rewards;
- save: validated load/save and schema migration;
- battle: deterministic-enough simulation, commands, AI, combat, abilities, projectiles;
- presentation: original unit rendering, environments, VFX and animation;
- UI: main menu, campaign map, battle HUD, pause/settings, results;
- input: touch, virtual joystick, keyboard and accessibility sizing;
- audio: generated/original SFX, music, volume and mute state;
- tests: data validation, simulation invariants, save migration, smoke play.

This is a destination, not a mandate for a large immediate refactor. First add tests around the current behavior, then extract one responsibility per change.

## Definition of done

A task is done only when its acceptance criteria are met, its failure modes are handled, CI passes, and any unverified manual checks are explicitly listed. Prioritize a stable, enjoyable game over the number of files or features.
