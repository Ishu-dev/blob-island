# Blob Island (prototype)

Godot 4.7, Jolt physics, orthographic isometric camera. Everything is built in code from `scripts/main.gd`.

## Run
- Play: `godot --path ~/Documents/Blob_Island`
- Edit: `godot -e --path ~/Documents/Blob_Island` (or open Godot.app and import this folder)
- Screenshot test: `godot --path . -- --screenshot=/abs/path.png` (auto-throws bombs at the nearest enemy, saves frame 95 or `--shotframe=N`, quits)

## Lobby (Brawl Stars style)
- Opens first. Drag the brawler to spin it. PLAY starts a run; M in a run banks your rewards and comes back here
- Top bar: trophies, coins, gems. Runs pay coins (coins picked up + kills x2 + waves x5), gems (5 per boss, 25 for a win) and trophies (3 per wave, 10 per boss, 30 for a win)
- BRAWLERS: Blobby (free), Chonk (tanky, big punches), Zippy (fast, double jump), Sparky (towers 40% cheaper), Gloopy (regenerates)
- GUNS: buy a starting gun; upgrade any gun to level 5 (+20% damage and +25% ammo per level)
- GARAGE: Buggy, Monster Truck, Tankette (cannon), Hover UFO (floats on water); upgrades add speed and armour
- SHOP: hats and glasses, paid in gems. DAILY GIFT: 60 coins and 5 gems once a day
- Trophy road: free rewards at trophy milestones (coins, gems, Zippy, Monster Truck, Sparky, Crown, Hover UFO...)
- Saved in `user://profile.cfg`

## Controls
- WASD / arrows: move. Space: jump, or climb when on a ladder. Jumping while running does a front flip
- Mouse: aim. Left click: fire, or punch with the fist (3rd punch in a row is a big uppercut)
- 1 to 6: weapon slots. Guns have limited ammo; an empty gun is dropped and you're back to fists
- Shift: hold to grab a crate, barrel, small or netted enemy; release or click to throw. It lands on the cursor (dotted arc and ring show where), range 8
- F: get in or out of a car. Driving: WASD steers toward that direction, Space hops, Space in the air flips, Shift boosts. Run blobs over; air time and flips pay coins. Tankette: click fires the cannon
- B: build mode (1 to 5 pick Turret, Laser, Barracks, Spikes, Net trap; click to place, rooftops included; right click or Esc to leave)
- N or Enter: end the day early and start the night
- Rotate camera: two-finger swipe sideways on the trackpad, Q/E, the < > buttons, or right/middle drag
- Zoom: pinch, two-finger swipe up/down, or scroll. H: help. R: restart. M: back to the lobby

## Game loop
- DAY (25 s): collect coins and power-ups (they have light beams), build towers and traps
- NIGHT: a wave attacks; weather is random (rain, storm with lightning, snow, fog, wind)
- Every 5th night is KING GLOOP. Beat him and you move to the next LEVEL: a new island and biome (meadow, snowfield, desert, autumn), a taller hill, that level's car, tougher enemies, better guns
- Beat the level 4 boss to win (ISLAND CHAMPION)
- Kill combos within 2.5 s: DOUBLE KILL, TRIPLE KILL, MEGA SPLAT, RAMPAGE, each pays bonus coins
- Supply drops parachute in every 30 to 45 s with a gun from the current level's tier

## What's on each island
- Railway with a train every 15 to 20 s (rails flash red first)
- One-floor building: ladder outside and elevator up to a flat roof (chest up there; you can build turrets and lasers on it), breakable windows
- A hill with one tier per level (1 to 4), coins on top. Wooden jump ramps for cars
- Cars: your garage car near the spawn, plus the level's car (1 buggy, 2 monster truck, 3 tankette, 4 hover UFO). A wrecked car comes back after 15 s
- Islet across the water: drawbridge lowers only while a crate sits on the pressure plate. Golden chest on the far side
- Trampolines, crates, explosive barrels, coins
- Enemies route to you: through the door, onto the elevator, across the bridge. Flyers rise to your height; the boss leaps onto the roof

## Weapons by level
- Level 1: Blaster, Splatter (shotgun), Crossbow (pierces 3), Bombs
- Level 2 adds: Net gun (catch and carry enemies), Laser (hold to burn)
- Level 3 adds: Rocket launcher

## Files
- `scripts/main.gd`: game flow, lobby hand-off, HUD, day/night waves, levels, cars, build mode, spawning, blasts, shots, pickups, combos, rewards
- `scripts/menu.gd`: the lobby UI and podium showroom; `profile.gd`: bank, ownership, upgrades, trophy road, save file; `cosmetics.gd`: hats and glasses
- `scripts/vehicle.gd`: raycast-suspension cars and their models
- `scripts/world.gd`: island, hill, ramps, building, ladder, railway, elevator, trampolines, islet, drawbridge, enemy routing
- `scripts/blob.gd`: shared body (health, teeth, footprints, shield, ragdoll, bowling crashes, nets); `player.gd`; `enemy.gd`; `spitter.gd`, `gunner.gd`, `flyer.gd`, `brute.gd`, `boss.gd`
- `scripts/structure.gd`: turrets, lasers, barracks, spike and net traps
- `scripts/weather.gd`: day/night lighting and weather
- `scripts/bomb.gd`, `projectile.gd`, `prop.gd`, `glass.gd`, `elevator.gd`, `train.gd`, `drawbridge.gd`, `plate.gd`, `pickup.gd`, `health_bar.gd`, `fx.gd`, `sfx.gd`

## Test screenshots
`godot --path . -- --screenshot=/abs/path.png --shotframe=N` plus optional `--level=N`, `--wave=N`, `--gun=ID`, `--at=building|roof|bridge|hill`, `--gameover`, `--night`, `--weather=MODE`, `--build`, `--roofbuild`, `--drive`, `--debugcar`, `--hold`, `--tomenu`, `--yaw=DEG`. Lobby: `--menu [--menutab=shop|brawler|gun|car] [--menuplay]`. Note: test runs that end a run write rewards to the real profile.

See DESIGN.md for the idea backlog.

## Tuning knobs
`ISLAND_SIZE`, `STEP`, `MAX_ENEMIES`, `SPAWN_EVERY` in main.gd; `RADIUS`, `FORCE`, `FUSE` in bomb.gd; `accel`, `max_speed` per blob.
