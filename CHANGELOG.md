# Zombie Siege — Changelog

Version format: `x.y.z` — x is fixed at 1, y = major updates (new content/systems), z = minor updates (fixes/polish).

## v1.1.0 "Arsenal"

Existing saves carry over -- nothing was renamed or removed, only added.

### New weapons (10 total)
- **Arc Gun** -- instant chain lightning that jumps between zombies.
- **Crossbow** -- a slow, heavy bolt that pierces everything in a line and knocks zombies back.
- **Mine Layer** -- drops mines that arm, then detonate when a zombie gets close.
- **Orbital Blades** -- blades orbit you continuously, shredding anything that gets close.
- **Boomerang** -- flies out and back, hitting on both passes.
- Each new weapon has its own relic (unlocked by 150 kills with it) and achievement (100 kills), and its own fire sound.

### Weapon mastery
- Every weapon now tracks kills and earns Tier I/II/III (100/500/1000 kills) for a damage and fire-rate bonus while it's equipped.
- New **Weapon Stats** screen on the main menu shows kills, tier, and progress toward the next tier for every weapon.
- New **starting-weapon picker**: set which weapon you begin a run with, either from the Weapons shop or from a row on the mode-select screen.

### New enemies
- **Charger** -- stops and telegraphs with a red line before committing to a fast, straight-line dash. Dodge the line and it overshoots, leaving it briefly vulnerable.
- **Necromancer** -- holds at range and periodically heals nearby zombies. A priority target once it shows up.
- **Boss variety** -- boss waves now roll between the original boss, a **Summoner** (calls in reinforcements) and a **Charger boss** (all melee, no ranged attack), unlocking as you go deeper.

### New modes and difficulty
- **Roulette mode** -- same wave rules as Classic, but your weapon is forced to a random unlocked one every 30 seconds. Manual weapon switching is disabled while it's active.
- **Nightmare difficulty** -- a tier above Hard, unlocked by reaching wave 20 or surviving 5 minutes in Horde.

### New pickups
- **Freeze** -- slows every zombie to a crawl for 5 seconds.
- **Magnet** -- pulls every pickup on the field toward you for 6 seconds.
- **Nuke** -- very rare; hits everything on screen with a large flat burst of damage. Has its own pulsing warning visual so you can't miss it on the ground.

### New upgrades
- **Critical Hits** and **Deadly Precision** (run and permanent) -- chance to deal double damage.
- **Regeneration** and **Vitality** (run and permanent) -- passive HP regen.

### Polish
- The weapon shop now scrolls properly with all 10 weapons instead of drawing off the bottom of the screen.
- Mode select, the shops, relics, stats, settings, pause, and the game-over screen now all respect notches and rounded corners, matching the main menu.
- Settings no longer overflows on short screens.
- New sounds for every Arsenal weapon and every new pickup.

### Bug fixes found and fixed during development
- The weapon shop briefly had no scrolling once the new weapons pushed it past 8 entries -- fixed before release.
- Roulette mode's weapon could still be changed manually with Tab or the HUD button -- now locked to the 30-second timer only.
- An earlier in-progress build of this update was found to contain a second, conflicting mastery system and a mode-select button with no handler; both were found and fixed before anything shipped.

## v1.0.2

### Improvements
- **Bigger main menu:** Buttons are larger, with bigger labels, and the menu resizes to fit your screen on phones and desktops, in portrait or landscape.
- **Notch support:** The HUD and its buttons now stay clear of notches, rounded corners and system bars.
- **Version number:** The version now shows at the bottom-right of the title screen.
- **Touch hint:** The title-screen hint no longer mentions keyboard controls on phones.

### Bug fixes
- **Off-screen shooting:** Shooter zombies and bosses no longer fire from outside the arena. They keep walking in until they're on screen, then stop and shoot.
- **Lost progress on phones:** Progress is saved the moment the app goes to the background. Swiping the app away no longer loses gems, kills or your best Horde time.

### Under the hood
- Debug cheats are disabled in release builds.
- Targeting and enemy shooting now share a single "inside the arena" check.

## v1.0.1

### Bug fixes
- **Shop buttons:** Clicking near the top edge of the shop's CLOSE button no longer triggers the weapon-cycle or pause button behind it. Buttons on top now get the click.
- **Game-over screen:** The HUD buttons hidden behind the game-over overlay can no longer be clicked. Previously, clicking where SHOP sits could drop you into the shop after you died.
- **Exploder zombies:** Exploders now detonate when they reach you, with the blast, particles, screen shake and sound, instead of silently biting like a normal zombie.

### Balance changes
- Exploders that touch you now deal their full blast damage (25) instead of the old 10 contact damage. This matches what they already did when shot near you. It replaces the contact hit, so you don't take both.
- Contact explosions don't count as kills and don't pay coins or gems.

### Under the hood
- The code is split into modules (`src/`) instead of one large file. Gameplay, saves and controls are unchanged, and existing save files work as before.
- The per-frame update is broken into smaller steps (player, bullets, spawning, zombies, pickups, wave flow, effects) to make future changes easier.
