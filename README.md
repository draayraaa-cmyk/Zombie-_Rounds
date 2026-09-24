Zombie Siege v1.0.1
Bug fixes
Shop buttons: Clicking near the top edge of the shop's CLOSE button no longer triggers the weapon-cycle or pause button behind it. Buttons on top now get the click.
Game-over screen: The HUD buttons hidden behind the game-over overlay can no longer be clicked. Previously, clicking where SHOP sits could drop you into the shop after you died.
Exploder zombies: Exploders now detonate when they reach you, with the blast, particles, screen shake and sound, instead of silently biting like a normal zombie.
Balance changes
Exploders that touch you now deal their full blast damage (25) instead of the old 10 contact damage. This matches what they already did when shot near you. It replaces the contact hit, so you don't take both.
Contact explosions don't count as kills and don't pay coins or gems.
Under the hood
The code is split into modules (src/) instead of one large file. Gameplay, saves and controls are unchanged, and existing save files work as before.
The per-frame update is broken into smaller steps (player, bullets, spawning, zombies, pickups, wave flow, effects) to make future changes easier.
