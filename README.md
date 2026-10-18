# Hungry Hole (Godot 4.7)

A remake of the Hole.io Classic mode built from the reverse-engineering docs in the parent folder. You and six bots are holes in a bright toy city. Swallow anything smaller than you, grow, swallow smaller holes, and have the most points when the two-minute timer ends.

## Run
```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --path godot
```
Controls: drag with mouse or touch (virtual joystick), or WASD / arrows / gamepad stick. Space or click to start. Esc pauses.

Debug flags (after `--`): `--autoplay` lets a Hard bot drive your hole, `--quit-after=N`, `--screenshot=/abs/path.png`, `--screenshot-at=N`. The run prints a final ranking and median FPS.

## Tests
```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path godot --script res://tests/run_tests.gd
```
Covers the balance and XP tables, movement model, camera curves, bot profiles, hole-vs-hole kills and ranking (105 assertions).

## Where the numbers come from
Every tuning value lives in a Resource script under `resources/` and is copied from the original game's ScriptableObjects. See `../03-systems/*.md` for the source of each constant.

## What is placeholder
- All eight 3D models come from four-view reference sheets (Tripo multiview). Old text-only versions are kept in `assets/tripo/old/` for comparison.
- Apartment stacks, M buildings, hedges, cones, bins, flowers and brick walls are primitive meshes in the palette.
- Sounds are generated tones in `autoload/audio_manager.gd`; drop OGG files in `assets/final/sfx/<tag>.ogg` to replace them.
