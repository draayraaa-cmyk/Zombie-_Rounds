# Zombie Siege — Changelog

Version format: `x.y.z` — x is fixed at 1, y = major updates (new content/systems), z = minor updates (fixes/polish).

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
