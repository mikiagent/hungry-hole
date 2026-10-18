# Hungry Hole (Godot 4.7)

A Hole.io-style game built from the reverse-engineering docs in `~/re/holeio`. You and six bots are holes in a bright toy city.

Rules:
- Swallow anything that physically fits through your opening. Bigger things are worth more. Buildings you can't fit topple when you undercut them.
- Swallow smaller holes. Every hole has 3 lives and respawns after 3 s at the size it died, with 4 s of spawn protection.
- First hole to reach 90 m wins. Otherwise the most points after 5 minutes wins, or the last hole with lives left.
- The city is in three rings. The next ring spawns in and the walls move out once 30% of what's there has been eaten.
- Past level 30 a hole keeps growing slowly, each extra level costing more.

## Run
```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --path ~/Documents/HungryHole
```
Controls: drag with mouse or touch (virtual joystick), or WASD / arrows / gamepad stick. Space or click to start. Esc pauses.

Debug flags (after `--`): `--autoplay` lets a Hard bot drive your hole, `--quit-after=N`, `--screenshot=/abs/path.png`, `--screenshot-at=N`, `--diag-eat` (reports objects that should have fallen but didn't), `--kill-test`, `--edge-test`, `--topple-test`, `--overlap-test`. The run prints the ranking and median FPS.

## Tests
```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path ~/Documents/HungryHole --script res://tests/run_tests.gd
```
Covers the balance and XP tables, movement model, camera curves, bot profiles, hole-vs-hole kills and ranking (180 assertions).

## Where the numbers come from
Every tuning value lives in a Resource script under `resources/` and is copied from the original game's ScriptableObjects. See `../03-systems/*.md` for the source of each constant.

## What is placeholder
- Every object in the city is a real model made from a four-view reference sheet (Tripo multiview): 17 models. Old text-only versions are in `assets/tripo/old/`.
- Sounds are generated tones in `autoload/audio_manager.gd`; drop OGG files in `assets/final/sfx/<tag>.ogg` to replace them.
