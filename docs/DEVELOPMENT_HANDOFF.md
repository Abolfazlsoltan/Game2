# Development handoff — Small Warriors

This document is a technical handoff for the next development session. It records what was checked and separates verified facts from items that still need manual testing.

## Current repository snapshot

- Engine: Godot 4.5, Compatibility renderer.
- Target: Android, landscape orientation.
- Main scene: `scenes/main.tscn`.
- Main script: `scripts/game.gd` (currently a large, single-file controller).
- Android build workflow: `.github/workflows/build-apk.yml`.
- App version in `project.godot`: `0.3.0`.
- Latest commit checked: `dbcf2ffd1510f66e78ad5563d5ff40955a6acc92`.
- The GitHub Actions run for that commit completed successfully and uploaded the `SmallWarriors-Android-APK` artifact.

## What is verified

The latest workflow run reports success. Its steps import/validate the Godot project, export a debug APK, test the APK archive, check for Android manifest/native library entries, and upload the artifact.

A successful export is not proof that every screen, touch target, save path, or gameplay state works correctly on a physical phone. Those still require smoke testing.

## Recommended next tasks

Keep the existing working APK pipeline intact while improving maintainability.

1. **Create a baseline before refactoring.** Download the current artifact and record a short screen recording of the menu, campaign map, one battle, pause/resume, result screen, and returning to the map.
2. **Split the large controller in small, reviewable steps.** Candidate boundaries:
   - campaign/progress persistence;
   - menu, map, help, pause, and result-screen drawing;
   - touch-coordinate conversion and input routing;
   - audio generation/playback;
   - battle state and simulation.
3. **Avoid changing behavior during extraction.** Move one responsibility at a time, run the existing Android workflow after each step, and compare against the baseline.
4. **Add explicit regression checks.** Confirm fresh-install defaults, saved progress after closing/reopening, restart and back navigation, sound toggle persistence (if intended), and input behavior at different phone aspect ratios.
5. **Keep Android export settings stable.** Do not replace the known-good container, SDK versions, export preset, artifact name, or output path without a demonstrated reason.
6. **Make changes easy to review.** Use focused commits with one purpose each; include the test result and any known limitation in each handoff.

## Phone smoke-test checklist

- [ ] App installs and launches from a fresh install.
- [ ] Menu buttons respond to taps and are not clipped.
- [ ] Campaign/map content remains readable in landscape.
- [ ] Touch controls work near screen edges and on a different aspect ratio.
- [ ] Pause, resume, restart, and return-to-menu navigation remain consistent.
- [ ] Closing and reopening the app preserves the expected progress.
- [ ] Sound toggle behaves consistently.
- [ ] No visible UI overlaps, stuck overlays, or repeated taps are needed.
- [ ] Latest APK was installed from the newest successful workflow run, not an older artifact.

## Important handoff note

The next contributor should inspect the current `scripts/game.gd` before editing and preserve existing behavior unless a specific bug is reproduced. The safest first code change is a small, behavior-preserving extraction with a successful Android build—not a broad rewrite.
