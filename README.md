# Blob Island (prototype)

Godot 4.7, Jolt physics, orthographic isometric camera. Everything is built in code from `scripts/main.gd`.

## Run
- Play: `godot --path ~/Documents/Blob_Island`
- Edit: `godot -e --path ~/Documents/Blob_Island` (or open Godot.app and import this folder)
- Screenshot test: `godot --path . -- --screenshot=/abs/path.png` (auto-throws bombs at the nearest enemy, saves frame 95 or `--shotframe=N`, quits)

## Controls
- WASD / arrows: move. Space: jump, or climb when on a ladder
- Mouse: aim. Left click: fire. 1 / 2 / 3: Bomb, Blaster (hold to auto-fire), Splatter (shotgun)
- Shift: hold to grab a crate, barrel or small enemy (it rides above your head); release or click to throw
- Right-drag or Q/E: rotate camera. Scroll or pinch: zoom. H: hide help. R: restart

## What's on the island
- Random 36 x 36 island, a railway with a train every 15 to 20 s (rails flash red first), a two-floor building with a ladder, breakable windows and an elevator to the roof chest, trampolines, crates and explosive barrels, coins
- Enemies: pink spitters (goo), orange gunners (3-round burst), yellow flyers (stomp them), purple brutes (ground slam), and KING GLOOP on every 5th wave
- Pickups: coins, heart (+35 HP), shield (8 s), allies (3 friendly blobs for 25 s)

## Files
- `scripts/main.gd`: game flow, HUD, waves, spawning, blasts, shots, pickups, lives, game over
- `scripts/world.gd`: island, building, railway, elevator, ladders, trampolines, props
- `scripts/blob.gd`: shared body (health, teeth, brows, footprints, shield); `player.gd`; `enemy.gd` base brain; `spitter.gd`, `gunner.gd`, `flyer.gd`, `brute.gd`, `boss.gd`
- `scripts/bomb.gd`, `projectile.gd`, `prop.gd`, `glass.gd`, `elevator.gd`, `train.gd`, `pickup.gd`, `health_bar.gd`
- `scripts/fx.gd`: particles, goo puddles, footprints, cracks, explosions, respawn gather
- `scripts/sfx.gd`: every sound is synthesized in code at startup

## Test screenshots
`godot --path . -- --screenshot=/abs/path.png --shotframe=N` plus optional `--wave=N`, `--weapon=N`, `--at=building`, `--gameover`. The test auto-fires at the nearest enemy every 30 frames.

See DESIGN.md for the game loop and idea backlog.

## Tuning knobs
`ISLAND_SIZE`, `STEP`, `MAX_ENEMIES`, `SPAWN_EVERY` in main.gd; `RADIUS`, `FORCE`, `FUSE` in bomb.gd; `accel`, `max_speed` per blob.
