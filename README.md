# Blob Island (prototype)

Godot 4.7, Jolt physics, orthographic isometric camera. Everything is built in code from `scripts/main.gd`.

## Run
- Play: `godot --path ~/Documents/Blob_Island`
- Edit: `godot -e --path ~/Documents/Blob_Island` (or open Godot.app and import this folder)
- Screenshot test: `godot --path . -- --screenshot=/abs/path.png` (auto-throws bombs at the nearest enemy, saves frame 95 or `--shotframe=N`, quits)

## Controls
- WASD / arrows: move. Space: jump
- Left click: throw a bomb at the cursor (the dotted arc and ring show where it lands; max range 9 tiles, so close enemies get a short lob)
- F: throw a bomb 4 tiles ahead
- Right-drag or Q/E: rotate camera. Scroll or pinch: zoom
- R: new island

## Files
- `scripts/main.gd`: island generation (noise + radial falloff, largest landmass kept), sea, light, camera, HUD, spawning, fall-off scoring
- `scripts/blob.gd`: shared physics sphere + squishy visual + eyes
- `scripts/player.gd`, `scripts/enemy.gd`: input vs chase AI
- `scripts/bomb.gd`: curved wick that burns down, spark particles and glow, tumble spin, swell and blink, blast with damage + knockback + chain reactions
- `scripts/goo.gd`: enemy spit projectile, wobble, drip trail, splat puddles that slow you
- `scripts/health_bar.gd`: screen-space bars with hit punch and lingering white damage segment

See DESIGN.md for the game loop and idea backlog.

## Tuning knobs
`ISLAND_SIZE`, `STEP`, `MAX_ENEMIES`, `SPAWN_EVERY` in main.gd; `RADIUS`, `FORCE`, `FUSE` in bomb.gd; `accel`, `max_speed` per blob.
