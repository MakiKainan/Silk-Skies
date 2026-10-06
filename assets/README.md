# SILK SKIES assets

Everything the player sees or hears that is not code. Right now the game runs on placeholder
boxes; this folder is where the real designs go. **Nothing needs code changes**: name a file
after the thing it belongs to (its `id`) and put it in the right folder, or set the matching
field in the Godot Inspector on the content `.tres`.

An explicit Inspector field always wins over a file found by name.

## Folders

| Folder | What goes there | File name |
|---|---|---|
| `models/hulls/` | ship hulls | `<hull_id>.glb` + `<hull_id>_model.tscn` |
| `models/weapons/` | turret barrels | `<weapon_id>_barrel.tscn` or `.glb` |
| `models/projectiles/` | bolts, slugs, missiles | `<projectile_id>.tscn` or `.glb` |
| `icons/items/` | inventory icons | `<item_id>.png` |
| `icons/hulls/` | hull portraits (no screen shows them yet) | `<hull_id>.png` |
| `ui/theme/` | `game_theme.tres`, the project-wide UI theme | |
| `ui/fonts/`, `ui/frames/` | fonts, rarity borders and panels | |
| `vfx/scenes/` | hit and explosion effects | `<projectile_id>_impact.tscn` |
| `vfx/textures/`, `vfx/materials/` | particle textures, shaders, materials | |
| `audio/sfx/` | sound effects | `<weapon_id>_fire.ogg`, `<projectile_id>_impact.ogg` |
| `audio/music/` | music | |
| `textures/` | arena floor, skybox | |

## What each hook replaces

| Content field | Found automatically as | Without it |
|---|---|---|
| `HullData.model_scene` | (always set explicitly) | box hull in `scenes/ship/models/` |
| `ItemData.icon` | `icons/items/<id>.png` | two-letter badge |
| `HullData.icon` | `icons/hulls/<id>.png` | nothing shown |
| `WeaponData.barrel_scene` | `models/weapons/<id>_barrel` | coloured box barrel |
| `WeaponData.fire_sound` | `audio/sfx/<id>_fire` | silent |
| `ProjectileData.visual_scene` | `models/projectiles/<id>` | generated bolt/slug/capsule |
| `ProjectileData.impact_scene` | `vfx/scenes/<id>_impact` | expanding ring (blasts only) |
| `ProjectileData.impact_sound` | `audio/sfx/<id>_impact` | silent |
| UI look | `ui/theme/game_theme.tres` (set in Project Settings) | Godot default theme |

### UI art (`UiArt`, found by file name, no Inspector field)

| File in `ui/` | Used for | Without it |
|---|---|---|
| `frames/panel.png` | refit, duel preview/result, tooltip window (nine-patch, 30 px corners) | flat dark box |
| `frames/slot_frame.png` | every item slot, tinted by rarity / category (nine-patch, 14 px) | flat coloured box |
| `frames/glyph_*.png` | faint category icon in empty slots (white, tinted) | blank |
| `frames/icon_discard.png` | the discard bin | "X" |
| `frames/button_*.png` | all buttons, via `theme/game_theme.tres` | default button |
| `hud/bar_frame.png` + `bar_fill.png` | HUD and enemy bars (fill is tinted per bar) | flat bar |
| `hud/boss_bar_frame.png` | the enemy hull bar of a boss | plain bar frame |
| `hud/icon_{shield,hull,armor,burn}.png` | status icons beside the HUD bars | no icon |
| `hud/dmg_{energy,kinetic,explosive}.png` | weapon bars and tooltips, tinted by damage type | no icon |

Keep UI glyphs and bar fills white or grey: the game tints them. Nine-patch margins are
constants at the top of `scripts/ui/ui_art.gd`; change them if a frame is re-drawn with
different border widths.

Ids come from the `.tres` in `data/` (for example `pulse_laser`, `starter_frigate`).
Extensions tried, in order: textures `png webp svg jpg`; scenes `tscn scn glb gltf`;
audio `ogg wav mp3`. Lookups are cached for the session, so restart the game after dropping
a file in.

## Rules for 3D art

- 1 unit = 1 metre. Hulls are about 3 to 8 units long (the Raider body is 2.2 x 3.6).
- **Forward is -Z**, up is +Y. The origin sits at the middle of the hull, at deck level.
- Barrels and projectiles point toward -Z with the origin at their pivot / centre.
  A barrel swings around its origin; it does not recoil or glow (the box placeholder does).
- Keep the root node a `Node3D`. Effect scenes should free themselves when finished
  (a 5 second timer removes them if they do not).
- Hull scenes need one `Marker3D` per hardpoint, named exactly as in the hull `.tres`
  (`Turret_A`, `Turret_B`, ...). The game checks this at startup.

### Adding a new hull model

1. Export `<hull_id>.glb` into `models/hulls/`.
2. In Godot, make a new *inherited scene* from it, add the `Marker3D` hardpoints, save it as
   `<hull_id>_model.tscn` (this keeps the art file re-exportable without losing the markers).
3. On `data/hulls/<hull_id>.tres`, set `model_scene` to that scene.
4. Run the game or the tests: a wrong marker name is reported by name.

## Rules for 2D and audio

- Icons: square PNG with transparency, 128 x 128 (the validator accepts 64 to 512). They are
  drawn about 44 px wide in a slot, 56 px in the tooltip; the rarity border is added by the game.
- Sound effects: `.ogg`, mono (they are positioned in 3D). Music: `.ogg`, stereo.
- Fonts: `.ttf` or `.otf`. Put them in `ui/fonts/`, then set the theme's default font in
  `ui/theme/game_theme.tres`.
- Audio buses are `Master`, `SFX`, `Music` (`default_bus_layout.tres`). Sound effects play on `SFX`.

## Checks

`ContentValidator` runs at startup and in the tests. Art is optional, but art that is present
must be usable: scenes must load and have a `Node3D` root, icons must be square and 64 to 512 px,
and every art file must live under `res://assets/`. Problems are listed by file.

Imported assets create `.import` files next to them. **Commit those too**; the `.godot/` cache
folder is the only thing that is ignored.
