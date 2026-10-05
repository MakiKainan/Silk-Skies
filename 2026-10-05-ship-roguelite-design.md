# Ship Roguelite — Design Spec

- **Date:** 2026-10-05
- **Codename:** Project Plunder (placeholder until a real title is chosen)
- **Engine:** Godot 4 (latest stable 4.x), GDScript with static typing, Forward+ renderer
- **Status:** Design approved in brainstorming; awaiting spec review

---

## 1. Purpose & Brief

A 3D roguelite of 1v1 spaceship duels, inspired by the 2014 mobile game *PlunderNauts* but not a copy of it. The goal is to recapture its loot-and-refit satisfaction while playing with the modern pace and feel of *Enter the Gungeon* and *The Binding of Isaac*.

**What the user stated**
- Built for fun, with no deadline, but it must **scale to lots of content**.
- 3D, with a top-down battle camera like PlunderNauts' combat view.
- "Sailing" movement with weight and momentum, not twitchy twin-stick movement.
- Weapons on cooldowns, some auto-aimed and some manually aimed.
- Customization through **typed hardpoints only**.
- Item identity comes from a built-in behavior plus rolled stat lines.
- Synergies are **specific item combinations** (named duos and sets), not generic tag counts.
- Roguelite meta: salvage and forge.
- Runs are a **linear gauntlet**.
- PC controls: **WASD sailing and mouse aim**.
- Build approach: **data-driven vertical slice**.
- The vertical slice uses **generic items only** and tests **raw combat first**, with no synergies.

**Assumptions (correct these if they're wrong)**
- PC (Linux/Windows) is the primary target, with controller support later.
- Gameplay is confined to a flat plane (Y = 0); there's no full 6-degree-of-freedom flight.
- Art style is toon-shaded with outlines, like the PlunderNauts reference.
- Runs last 30–40 minutes, and each duel lasts 1–3 minutes.

**Success criteria**
1. Sailing is fun on its own in the sandbox, with no enemies present.
2. A duel lasts 1–3 minutes and is decided by positioning and weapon choice.
3. Adding a new item, hull, or enemy requires **only new `.tres` data**, unless it introduces a genuinely new mechanic.

---

## 2. Combat Core

### 2.1 Sailing
- Ships move on the XZ plane with **thrust, max speed, turn rate, and drag**.
- **Turn rate falls as speed rises.** At full speed a ship turns at 40% of its standstill turn rate. This forces a choice between fast-but-wide and slow-but-nimble.
- **Hard Burn** (Shift): a short directional boost on a cooldown, which works as the dodge.
- Hull stats (mass, thrust, turn, drag) define each hull's handling personality.

### 2.2 Damage layers
Damage is applied in order: **Shields → Armor → Hull**.
- **Shields** regenerate after a short delay without taking hits.
- **Armor** applies a flat reduction per hit, with a minimum of 1 damage.
- **Hull** reaching 0 destroys the ship.

| Damage type | vs Shields | vs Armor | vs Hull |
|---|---|---|---|
| Energy | ×1.5 | normal | ×0.75 |
| Kinetic | ×0.75 | ignores 50% armor | normal |
| Explosive | ×0.5 | normal | ×1.5 |

These are starting tuning values, adjusted through playtesting.

### 2.3 Weapons
- Each turret hardpoint has a **firing arc** (from 360° down to a narrow broadside) and a **size** (Small or Large).
- Every weapon has a **cooldown** and one **targeting mode**:
  - **Auto:** fires on its own when the enemy is inside its arc and range and the weapon is ready.
  - **Manual:** aims at the mouse cursor and fires on left-click.
  - **Lock-on:** hold right-click on the enemy to lock, then release to fire a homing salvo.

### 2.4 Actives
- Fighter launches, crew abilities, and techmod-granted abilities go on **Q / E / R**, each with a cooldown.
- Fighters are small AI drones that live for a limited time.

### 2.5 Readability & feel
- Enemy projectiles can be dodged by sailing well.
- Heavy attacks are telegraphed with a charge-up glow.
- Asteroids block projectiles and can be used as cover.
- Juice: hit-stop on heavy impacts, screen shake, hull debris, and sparks.

---

## 3. Ships, Hardpoints & Items

### 3.1 Hulls
A `HullData` resource holds the hull's stats and a list of **typed hardpoints**. Each hardpoint has:
- a type: Turret, Fighter Bay, Techmod, or Crew Seat
- a size (Small or Large), for turrets only
- a firing arc
- a `Marker3D` on the model, where equipped gear visibly mounts

### 3.2 Items
Each item has:
- a **built-in behavior** that defines it, which is always present
- **rolled stat lines**

Rarity sets the number and size of the rolls:

| Rarity | Stat lines | Notes |
|---|---|---|
| Common | 0 | base item |
| Rare | 1 | |
| Epic | 2 | larger roll ranges |
| Legendary | 2 | reserved for unique named items (P4); not in the slice |

Rolls are stat-only, for example +25% fire rate or −15% cooldown. Behavior always comes from the item definition.

Weapons are built from reusable parts:
- a targeting mode
- a `ProjectileData` resource (speed, damage, damage type, spread, homing, pierce)
- a list of `Effect` resources

### 3.3 Crew
Each crew member fills a Crew Seat and provides:
- one **active ability** on Q/E/R
- one **station bonus** that boosts a slot category

### 3.4 Techmods
Techmods are passive modules, and some also grant an active ability.

### 3.5 Synergies (P2, not in the slice)
Synergies are hand-authored `SynergyData` resources that list the required item IDs and what you gain: stat modifiers plus `Effect`s.
- **Duos:** two-item combos, intended to be numerous.
- **Sets:** 3–4 themed pieces. Completing a set gives a large transformation and changes the ship's visuals.

Supporting systems:
- The reward screen weights drops toward pieces of sets you've started and highlights any item that would complete one ("SET COMPLETE" preview).
- Undiscovered synergies appear as ??? in a codex until first triggered.
- The hangar shows "1 piece away" hints for synergies you've already discovered.
- Synergies reference item IDs, so adding one never requires editing item files.

---

## 4. Run Structure & Meta-Progression

### 4.1 Gauntlet (full game, P2)
- A run is **3 acts × (3 duels + 1 boss) = 12 fights**.
- Before each duel, an **enemy preview** shows the enemy's hull and visible weapons.
- Hull damage carries over between duels, while shields refill.
- Between acts there's a **Port**, where you spend Scrap to repair, reroll a reward, or recruit one of two crew offers.

### 4.2 Enemies
- An enemy is a `HullData`, a loadout of real `ItemInstance`s, and an **AI profile**: brawler, kiting sniper, carrier, or turtle.
- **Enemies drop what they were using.** At least one reward option is always drawn from the defeated enemy's loadout.
- Difficulty scales through enemy gear rarity and AI profile.
- Bosses have unique hulls with health-gated phases.

### 4.3 After each duel
1. **Loot reveal:** pick 1 of 3.
2. **Scrap:** break down unwanted items for Scrap, the in-run currency.
3. **Refit:** freely swap gear between hardpoints and a **limited cargo hold** (4 slots).

### 4.4 Meta (P3)
- When a run ends, by win or death, you keep **Materials** (scaled by how far you got) and **bank one item** in the vault.
- **Blueprints:** spend Materials to add items, hulls, crew, and synergy sets to the loot pool. Meta progression widens your options more than it raises raw power.
- **Forge:** combine Materials with a banked item to reroll its stats or upgrade its rarity.
- **Loadout:** you may start a run with one banked item. It's consumed when you take it.
- Difficulty tiers (Ascension-style) are out of scope until after the first full win.

---

## 5. Technical Architecture

### 5.1 Project layout
```
res://
  addons/gut/                 # GUT test framework (MIT), vendored
  data/
    hulls/  weapons/  fighters/  techmods/  crew/
    projectiles/  effects/  enemies/  acts/  synergies/
  scripts/
    data/        # Resource class definitions (*Data, Effect, StatMod)
    ship/        # Ship + components + controllers
    systems/     # RunManager, LootGenerator, SynergyResolver
    autoload/    # ContentDB, RunState, MetaSave, EventBus
    ui/
  scenes/
    ship/  arena/  projectiles/  ui/  debug/
  tests/
```

### 5.2 Static data vs. rolled instances
- **`*Data` resources** are authored content. They are never modified at runtime. The types are `HullData`, `WeaponData`, `FighterData`, `TechmodData`, `CrewData`, `ProjectileData`, `EnemyData`, `ActData`, and later `SynergyData`. Every resource has a unique string `id`.
- **`ItemInstance`** (a `RefCounted`) represents one specific drop. It holds `data_id`, `rarity`, and `rolls: Array[StatMod]`, and it serializes to a dictionary.
- **`StatMod`** has a `stat` name, an `op` (flat or percent), a `value`, and a `scope` (this item, all turrets, or the whole ship).

### 5.3 Ship scene (shared by player and enemies)
`Ship` is a `CharacterBody3D` with its position locked to Y = 0.

| Component | Responsibility |
|---|---|
| `MovementComponent` | thrust, speed-scaled turning, drag, Hard Burn |
| `HealthComponent` | shields, armor, hull; damage-type multipliers; emits `damaged` and `destroyed` |
| `StatsComponent` | combines hull base stats, item rolls, and (later) synergy modifiers into final stats; recomputes only on loadout change |
| `HardpointMount` | one per model marker; holds the mounted item's visual |
| `WeaponController` | one per weapon; handles cooldown, arc checks, and targeting mode; spawns projectiles |
| `AbilityController` | maps Q/E/R to actives from crew, bays, and techmods |
| `EffectRunner` | subscribes `Effect`s to ship signals |

The **controller** is swappable:
- `PlayerInput`: WASD, mouse, Shift, Q/E/R.
- `AIController`: driven by an AI profile resource.

Both controllers issue the same commands (`set_throttle`, `set_turn`, `aim_at`, `fire`, `use_ability`), so enemies are ordinary ships.

### 5.4 Effects pipeline
- An `Effect` is a `Resource` with hooks: `on_fire`, `on_hit`, `on_kill`, `on_tick`, and `aura`.
- Item behaviors and (later) synergy behaviors share this single pipeline.
- New content combines existing effects with new numbers. A **new `Effect` subclass is the only place new code is written for content.**

### 5.5 Autoloads
| Autoload | Role |
|---|---|
| `ContentDB` | scans `res://data/` at startup, indexes by `id`, validates (see §7) |
| `RunState` | current run: loadout, cargo, hull HP, Scrap, act/duel index, run seed |
| `MetaSave` | Materials, blueprints, vault, synergy codex |
| `EventBus` | combat and UI events (hits, kills, cooldowns), so juice and UI stay decoupled from gameplay |

### 5.6 Flow
`Hangar → RunManager` (builds the gauntlet from `ActData`) `→ Duel scene` (spawns both ships) `→ DuelResult → RewardScreen` (`LootGenerator` rolls three options) `→ Refit → next Duel …`

### 5.7 Saving
- Saves are JSON in `user://` via `FileAccess`, with a `save_version` field.
- Meta progress saves at the end of a run and in the hangar. The run auto-suspends between duels.
- Items are saved as `data_id` plus rolls. An unknown `data_id` (content that was removed) is skipped with a warning, never a crash.

### 5.8 Randomness
- Each run has one seeded `RandomNumberGenerator`, stored in `RunState` and saved with the run.
- All loot rolls, enemy loadouts, and reward options draw from it, so any run can be replayed from its seed.

---

## 6. Vertical Slice (P1): Raw Combat

**Goal:** prove that sailing and dueling are fun and that the data pipeline works. Everything is generic, with **no synergies and no unique named items**.

**Hull (1):** a starter frigate with 2 turrets (one Small 360° and one Large 120° forward arc), 1 fighter bay, 1 techmod, and 1 crew seat.

**Turrets (4)**

| Item | Mode | Type | Behavior |
|---|---|---|---|
| Pulse Laser | Auto | Energy | rapid short bolts |
| Autocannon | Auto | Kinetic | steady stream, slight spread |
| Railgun | Manual | Kinetic | slow charge, pierces |
| Missile Pod | Lock-on | Explosive | homing salvo |

**Fighter bays (2):**
- Interceptor Bay: fighters shoot down incoming missiles.
- Strike Bay: bombers dive at the enemy hull.

**Techmods (2):**
- Shield Capacitor: passive; adds shield capacity and regeneration.
- EMP Emitter: grants an active that briefly disables enemy auto-weapons.

**Crew (2):**
- Gunner: turret fire-rate station bonus, plus an Overcharge active.
- Engineer: techmod station bonus, plus an Emergency Repair active.

**Enemies:**
- 2 AI profiles: brawler and sniper.
- 1 mini-boss with one health-gated phase change.

**Loop:** 3 duels (brawler, sniper, mini-boss), with Reward (pick 1 of 3, rarities Common to Epic) and Refit after each. There is no Port, Forge, meta save, or synergies.

**Arena:** a circular bounded arena with 3–6 asteroids as cover.

**Art:** placeholder or kitbashed meshes with a toon outline shader.

**Debug sandbox scene:** spawn any hull, item, enemy, or rarity instantly; toggle god mode; adjust time scale.

**Slice done when:**
- [ ] Sailing feels good in the sandbox with no enemies (judged by the developer's playtest checklist).
- [ ] Each of the four targeting styles and three damage types is clearly distinguishable in play.
- [ ] Duels last 1–3 minutes.
- [ ] Every slice item, enemy, and hull exists purely as `.tres` data.
- [ ] All unit tests in §8 pass.

### Later phases
| Phase | Scope |
|---|---|
| **P2** | Synergy system (duos and sets, weighting, codex), full 3-act gauntlet, Port, boss phases, run suspend |
| **P3** | Meta: hangar, Materials, blueprints, vault, Forge |
| **P4** | Content scaling: unique named items (e.g. King Zorgon's arsenal), Legendary rarity, more hulls and enemies; art and juice polish |

---

## 7. Error Handling

- **Content validation:** `ContentDB` checks the following at startup and fails loudly in debug builds:
  - duplicate `id`s
  - references to missing IDs (enemy loadouts, acts, and later synergies)
  - hardpoints whose model marker is missing
  - items assigned to an incompatible slot type
- **Loadout validation:** the loadout is checked before every duel.
- **Effect isolation:** if an `Effect` errors, it is logged and skipped for that event; the fight continues.
- **Save robustness:** saves are versioned, unknown IDs are skipped with a warning, and a corrupt save falls back to a backup copy (`*.bak`) written before each save.

---

## 8. Testing

**Framework:** GUT, vendored in `addons/` (MIT-licensed, nothing installed system-wide).

**Unit tests (slice)**
- Stat aggregation: base stats, then rolls, then scope application.
- Damage layer order and the damage-type multipliers in §2.2.
- Turn-rate falloff with speed.
- Cooldown and arc checks in `WeaponController`.
- Loot generation is deterministic for a given seed, and rarity distribution stays within tolerance.
- `ItemInstance` save round-trip, including the unknown-ID case.
- `ContentDB` validation catches each error class listed in §7.

**Unit tests (P2):** synergy detection and reward weighting.

**Manual testing:** run a short feel checklist after each slice milestone covering handling, readability, juice, and duel length.

---

## 9. Out of Scope (for now)
- Multiplayer.
- Mobile and touch controls.
- Branching run maps. The run is stored as a list of encounters, so it could become a branching map later.
- Ascension or difficulty tiers.
- Procedurally generated hulls or free-form ship building.
