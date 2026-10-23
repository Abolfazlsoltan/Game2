# Small Warriors ⚔️

A touch-friendly 2D lane-strategy game built with Godot 4 and GDScript.

## Gameplay
- Recruit swordsmen, archers, and guards.
- Defend your keep while attacking the enemy keep.
- Survive increasingly difficult enemy waves.
- Earn gold, upgrade your army, and save progress locally.
- Touch-friendly interface, pause/resume, restart, health bars, and combat effects.
- Offline gameplay; no external assets or network access required.

## Run locally
1. Install Godot 4.5.x.
2. Import `project.godot`.
3. Run the main scene (F6/F5).

## Download an APK
A GitHub Actions workflow builds a debug APK on each push to the default branch:
1. Open the repository's **Actions** tab.
2. Open the latest successful **Build Android APK** run.
3. Under **Artifacts**, download `SmallWarriors-Android-APK`.
4. Extract the ZIP and install `SmallWarriors.apk` on an Android device.

The APK is for testing. A production Play Store release needs a protected release keystore, release signing, device QA, store assets, and a privacy review. Never commit keystore passwords or signing keys.

## Build details
- Engine: Godot 4.5.x
- Renderer: Compatibility / OpenGL ES
- Android target: ARM64 debug APK
- Persistent save: `user://small_warriors.cfg`

## QA checklist
- [ ] Open project without parser errors.
- [ ] Start battle and recruit all three unit types.
- [ ] Verify gold costs, attacks, health bars, deaths, wave rewards, and upgrade effects.
- [ ] Pause/resume and restart.
- [ ] Verify progress survives app restart.
- [ ] Install and test the generated APK on a physical Android device.
- [ ] Before release, test multiple screen sizes and lower-end hardware.

## Official references
- [Godot Android export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Android Developers: Export Godot projects](https://developer.android.com/games/engines/godot/godot-export)
