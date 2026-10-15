# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

SILK SKIES is a Godot 4.7 (Forward+, GDScript) top-down spaceship duel roguelite. The design spec is `2026-10-05-ship-roguelite-design.md` in the project root (codename "Project Plunder" there). The game is built placeholder-first: ships and projectiles are boxes until real art lands in `assets/`.

## Commands

Godot is not on PATH. Use the **console** build (the plain exe prints nothing to the terminal):
`"C:\Users\Kevin Sukias\Downloads\New folder\Godot_v4.7.1-stable_win64_console.exe"` (written `<godot>` below). Run from the project root.

- **Import** (required after adding or renaming any `class_name` script, otherwise GUT fails with "class_names have not been imported"):
  `<godot> --headless --path . --import --quit`
- **All tests** (GUT 9.6.1, vendored in `addons/gut`, config `.gutconfig.json`):
  `<godot> --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd`
  Always pass `--fixed-fps 60`: it removes real-time sync, so the suite runs in ~15 s and the AI tests depend on it.
- **One test file:** add `-gselect=test_damage_model` (file name, no path). **One test:** also add `-gunit_test_name=<part of the name>`. Note `-gtest=` does *not* filter: it adds a file on top of the `.gutconfig.json` dirs.
- **Balance probe** (not part of the suite): `-gtest=res://tests/probe/probe_balance.gd -gselect=probe_balance` prints AI-frigate-vs-enemy duel lengths (target 20–35 s). Results vary run to run (weapon spread RNG is randomized).
- The suite occasionally fails on an engine warning, "Jolt Physics job system exceeded the maximum number of jobs"; it is intermittent and passes on rerun.
- **Visual smoke test:** write a throwaway `extends SceneTree` script in a scratch directory that instantiates a scene (for example `res://scenes/debug/sandbox.tscn`), drives it with `Input.action_press(...)`, and saves `root.get_texture().get_image()` to PNG. Run it with `<godot> --path . --resolution 1280x720 -s <script>`, then look at the PNG. Such a script compiles before autoloads exist, so it must not name project classes or autoloads (use untyped vars and `root.get_node("ContentDB")`), and it must `await process_frame` twice before touching them.

`tests/`, `addons/gut/`, `.gutconfig.json`, `docs/` and the spec are **gitignored** and exist only locally. Don't assume git can restore them.

## Architecture

**Data-driven content.** All gameplay content is `.tres` resources under `data/` (hulls, weapons, projectiles, techmods, fighter bays, crew, enemies, AI profiles, acts, roll pools), each with a unique `id`. The resource classes live in `scripts/data/`. The `ContentDB` autoload loads everything under `res://data/` through `ContentLoader`, runs `ContentValidator` (pure checks; tests feed it broken data), and indexes by id. New content usually means a new `.tres` plus validator coverage, not new code.

**Autoloads:** `EventBus` (global signals: `ship_hit`, `ship_destroyed`, `weapon_fired`, `phase_started`, `fighters_launched`, `shield_broken`), `ContentDB`, and `RunState`. `RunState` holds the current run: mode (`ORIGINAL` = real run, `DEBUG` = sandbox/gauntlet), the player hull and `ShipLoadout`, the act, the duel index and the seed. The sandbox and the duel scene share the same loadout object.

**Ship composition.** One `Ship` (`CharacterBody3D`, `scenes/ship/ship.tscn`) serves player and enemies. Controllers drive it only through its command API: `PlayerInput` for the human, `AIController` (with the pure `AISteering`, data from `AIProfile`) for enemies, and `PhaseController` for boss phases. Child components: `StatsComponent`, `MovementComponent` (+ `SailingModel`), `HealthComponent` (shield → armor → hull via `DamageModel`; a shield break leaves the hull exposed for 2 s at ×1.25 damage), and one `HardpointMount` per hull hardpoint holding a `WeaponController` or a `FighterBayController`.

**Weapons and fighters.** There is no auto-fire on ships. Every weapon is `AIMED` (fires at the aim point while held, optionally after a charge) or `LOCK_ON` (locks on hold, fires on release), and belongs to a fire group: PRIMARY = LMB, SECONDARY = RMB, triggered via `Ship.set_trigger(group, held)`. A weapon's group is `WeaponData.default_fire_group`, overridden per item by `ItemInstance.fire_group` (right-click in the refit screen); lock-on is always SECONDARY. Rapid weapons build heat and overheat (`heat_per_shot`). Auto-aim lives on fighters: `Ship.activate(i)` (Q/E/R, in `Ship.active_items()` order) launches a bay; `Fighter` uses the pure `AutoAim` to pick and lead targets (interceptors zap enemy missiles, bombers make diving runs) and sits on physics layer 4 so projectiles can hit it. Enemy weapons draw an `AimTelegraph` on the floor (style per `WeaponData.telegraph`); enemy charged shots stop tracking for the last 0.2 s. AI aims from a delayed estimate of the target (`reaction_time`), so it is fooled by turns and burns.

**Juice.** `HitFeel` (shake, hit-stop, final-kill slow-mo) and `ThreatIndicators` (off-screen arrows) are added by Duel and Sandbox and only listen to `EventBus`. HitFeel's time effects are off in headless runs.

**Stats.** Use the `Stats` constants for keys, never raw strings. `StatAggregator` is pure: `final = (base + ΣFLAT) * (1 + ΣPERCENT)`, filtered by `StatMod.Scope`. `StatsComponent` recomputes only when the loadout changes; `HullData` itself is never mutated. Per-weapon stats come from `WeaponStats` and loadout totals from `LoadoutStats`.

**Items and loadout.** `ItemData` (base of `WeaponData`/`TechmodData`/`FighterBayData`/`CrewData`) is the definition. `ItemInstance` is a rolled copy with a `Rarity` and `StatMod`s, made by the seeded `ItemRoller` from `RollPool`s. `ShipLoadout` (slots + fixed-size cargo with null cells) owns every move rule, so the UI only asks "can I?" and "do it". `Loadout.can_equip` defines slot fit. `LootGenerator` builds the post-duel reward offers.

**Flow.** `scenes/menu/start_screen.tscn` (main scene) → `scenes/duel/duel.tscn` (`Duel`: preview → fight → reward/result, pausing behind overlays; enemies built by `EnemyFactory` from `EnemyData`) or the debug sandbox (`scenes/debug/sandbox.tscn`, F2 panel, refit screen on I).

**Art hooks.** `ArtLookup` resolves visuals: an explicit Inspector field on the content resource wins, else a file named after the `id` in `assets/`, else `null` (placeholder). UI art goes through `UiArt` / `ArtBar`. `assets/README.md` holds the naming conventions. Keep the placeholder fallback working when touching visuals.

## Conventions and gotchas

- Static typing is expected (`untyped_declaration` warns). A typed variable that holds a freed `Ship` can't be compared with `!= null`; guard with `is_instance_valid()`.
- Combat tests extend `res://tests/helpers/ship_test.gd` (not `GutTest`). It builds ships and steps the simulation by hand with `sim()`. Tests that spawn ships must `autofree()` them, or the ships keep fighting in later tests. Weapons only fire with a trigger held: aim and call `set_trigger`/`set_all_triggers`. Combat is lethal, so AI behaviour tests give the player `god_mode`.
- Crew and techmod actives are still inert shells until the `Effect` pipeline (M4) exists; fighter bays are live.
- Work goes milestone by milestone. The user playtests each milestone before it is committed. Don't push; `origin` is the user's GitHub remote.
