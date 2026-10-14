# Blob Island: design notes

Working title. Reference games: BombSquad (physics chaos), Thronefall (build by day, defend by night, very few buttons), Bloons TD 6 and Rogue Tower (tower defense with upgrades), Archero and Vampire Survivors (short runs, pick-one-of-three upgrades).

## Why games like these get replayed

Most hit casual games use the same four loops, nested inside each other:

| Loop | Length | What the player gets | In Blob Island |
|---|---|---|---|
| Moment | 1 to 3 s | A satisfying hit: sound, shake, splat, number | Bomb blast, enemy pops into goo |
| Wave | 30 to 90 s | Tension, then relief and a reward | Night wave, "WAVE CLEARED", loot |
| Run | 10 to 20 min | A build that feels like it's yours; a story of how you won or lost | Random island, towers you chose, upgrades you picked |
| Meta | Days to weeks | Permanent progress between runs | New blob heroes, bomb types, islands, cosmetics |

The rule of thumb: every loop ends by showing the player a choice for the next one. Death should show "you reached night 7, best is 9" and a button to go again within 2 seconds.

## Proposed core loop (Thronefall-style)

1. **Day (calm, about 40 s).** Walk the island. Collect gold that dropped from last night's goo. Spend it at build spots: a tower, a wall, a bomb launcher, a goo-proof barrier. Building happens by standing on a spot, which Thronefall uses to avoid menus, and it works well on a phone.
2. **Night (danger).** Enemy blobs land from boats or fall from the sky and head for your Crystal Heart. You fight with bombs while your towers help. Physics matters: knock enemies into the sea, chain bombs, use the terraces.
3. **Dawn.** Pick 1 of 3 upgrades (roguelite card). Examples below.
4. Repeat. Every 5 nights a boss blob. Lose the Heart and the run ends; you keep some "pearls" for meta unlocks.

## Upgrade card ideas (one of three after each night)

- Sticky bombs: bombs stick to the first blob they hit
- Cluster bombs: explode into 3 mini bombs
- Bouncy bombs: bounce 3 times, each bounce damages
- Bigger blast radius, shorter fuse, two bombs per throw
- Ground pound: jump then press Space again to slam down, knocking blobs away
- Goo immunity: you absorb enemy puddles and heal from them
- Magnet: gold flies to you
- Tower upgrades: faster fire, splash, freeze

## Enemy ideas (add one at a time)

| Enemy | Behaviour | Counter |
|---|---|---|
| Pink spitter (done) | Lobs goo, puddles slow you | Keep moving, bomb its wind-up |
| Green bouncer | Hops in big arcs, lands with a shockwave | Bomb it mid-air |
| Blue splitter | Splits into two small blobs when killed | Area damage |
| Yellow shield | Takes no damage from the front | Bomb behind it |
| Purple sapper | Ignores you and runs for the towers | Walls, prioritise it |
| Big Mama (boss) | Huge, absorbs smaller blobs to heal | Knock the small ones into the sea first |

## Islands

- Biomes: grass, snow (slippery physics), desert (sand slows), volcano (lava tiles)
- Hazards: crumbling edge tiles, rising tide each night that shrinks the island, wind gusts that push everything
- Interactive props: barrels that explode, trees that can be blasted down into bridges

## Feel and juice backlog

- Sound: bomb fuse hiss, goo "blorp", pop on kill, rising pitch on combo kills
- Combo counter: kills within 2 s chain into x2, x3 with bigger text
- Hit stop: freeze the game for 40 ms on a big blast
- Squash on blobs touching each other; faces that change (angry eyes on wind-up, dizzy stars when stunned)
- Tilt-shift depth of field like the city screenshot, as a toggle

## Phone controls (needed before mobile)

- Left half of the screen: virtual joystick for movement
- Right side: bomb button. Hold to show the arc, drag to aim, release to throw
- Double tap to jump; two-finger drag to rotate camera; pinch to zoom

## Monetisation options (decide later)

- Paid upfront (around Rs 199 / $2.99) with no ads. Thronefall's model, cleanest for a small game.
- Free with one-time "remove ads" plus cosmetic hats and blob skins. Common on mobile.
- Avoid energy timers and pay-to-win. They hurt reviews for a game this size.

## Suggested build order

1. Crystal Heart + day/night cycle + gold drops
2. One tower type and stand-to-build spots
3. Upgrade cards after each night
4. Sound effects
5. Phone controls, then a first Android test build
6. Second enemy type, then the boss
