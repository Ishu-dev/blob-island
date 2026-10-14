# Blob Island (prototype)

Godot 4.7, Jolt physics, orthographic isometric camera. Everything is built in code from `scripts/main.gd`.

## Run
- Play: `godot --path ~/Documents/Blob_Island`
- Edit: `godot -e --path ~/Documents/Blob_Island` (or open Godot.app and import this folder)
- Screenshot test: `godot --path . -- --screenshot=/abs/path.png` (auto-throws bombs at the nearest enemy, saves frame 95 or `--shotframe=N`, quits)

## Controls
- WASD / arrows: move. Space: jump, or climb when on a ladder
- Mouse: aim. Left click: fire, or punch with the fist (3rd punch in a row is a big uppercut)
- 1 to 6: weapon slots. Guns have limited ammo; an empty gun is dropped and you're back to fists
- Shift: hold to grab a crate, barrel, small or netted enemy; release or click to throw
- B: build mode (1 to 5 pick Turret, Laser, Barracks, Spikes, Net trap; click to place; right click or Esc to leave)
- N or Enter: end the day early and start the night
- Rotate camera: two-finger swipe sideways on the trackpad, Q/E, the < > buttons, or right/middle drag
- Zoom: pinch, two-finger swipe up/down, or scroll. H: help. R: restart

## Game loop
- DAY (25 s): collect coins and power-ups (they have light beams), build towers and traps
- NIGHT: a wave attacks; weather is random (rain, storm with lightning, snow, fog, wind)
- Every 5th night is KING GLOOP. Beat him and you move to the next LEVEL: a new island and biome (meadow, snowfield, desert, autumn), tougher enemies, better guns
- Supply drops parachute in every 30 to 45 s with a gun from the current level's tier

## What's on each island
- Railway with a train every 15 to 20 s (rails flash red first)
- Two-floor building: ramp inside to the upper floor, ladder outside to the roof, breakable windows, elevator, chest on the roof
- Islet across the water: drawbridge lowers only while a crate sits on the pressure plate. Golden chest on the far side
- Trampolines, crates, explosive barrels, coins
- Enemies route to you: through the door, up the ramp, onto the elevator, across the bridge. Flyers rise to your height; the boss leaps onto the roof

## Weapons by level
- Level 1: Blaster, Splatter (shotgun), Crossbow (pierces 3), Bombs
- Level 2 adds: Net gun (catch and carry enemies), Laser (hold to burn)
- Level 3 adds: Rocket launcher

## Files
- `scripts/main.gd`: game flow, HUD, day/night waves, levels, build mode, spawning, blasts, shots, pickups
- `scripts/world.gd`: island, building, ramp, ladder, railway, elevator, trampolines, islet, drawbridge, enemy routing
- `scripts/blob.gd`: shared body (health, teeth, footprints, shield, ragdoll, bowling crashes, nets); `player.gd`; `enemy.gd`; `spitter.gd`, `gunner.gd`, `flyer.gd`, `brute.gd`, `boss.gd`
- `scripts/structure.gd`: turrets, lasers, barracks, spike and net traps
- `scripts/weather.gd`: day/night lighting and weather
- `scripts/bomb.gd`, `projectile.gd`, `prop.gd`, `glass.gd`, `elevator.gd`, `train.gd`, `drawbridge.gd`, `plate.gd`, `pickup.gd`, `health_bar.gd`, `fx.gd`, `sfx.gd`

## Test screenshots
`godot --path . -- --screenshot=/abs/path.png --shotframe=N` plus optional `--wave=N`, `--gun=ID`, `--at=building|roof|bridge`, `--gameover`, `--night`, `--weather=MODE`, `--build`, `--yaw=DEG`.

See DESIGN.md for the idea backlog.

## Tuning knobs
`ISLAND_SIZE`, `STEP`, `MAX_ENEMIES`, `SPAWN_EVERY` in main.gd; `RADIUS`, `FORCE`, `FUSE` in bomb.gd; `accel`, `max_speed` per blob.
