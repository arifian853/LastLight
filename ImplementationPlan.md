# Implementation Plan — LAST LIGHT

## 1. Project Overview

**Title:** LAST LIGHT  
**Engine:** Godot 4.7.2 stable  
**Language:** GDScript  
**Editor Integration:** Godot AI MCP 4.3.1  
**Genre:** 2D Top-Down Survival Roguelite / Bullet Heaven  
**Target Platform:** Windows Desktop  
**Development Target:** 7 Days  
**Primary Goal:** Deliver a complete, playable, exportable vertical slice with one full survival run from start to finish.

LAST LIGHT is a small atmospheric survival game set in a frozen world. The player controls the final keeper of a supernatural lantern while shadow creatures continuously approach from the darkness.

The player focuses primarily on movement and positioning. Attacks are automatic. Enemies drop Light Shards that provide experience. On level-up, the player selects one of three random upgrades. Enemy pressure increases over time until the player either survives until dawn or dies.

The project should prioritize:

- Simple but satisfying gameplay.
- Fast iteration.
- Strong atmosphere with minimal assets.
- Clear systems that are easy to extend later.
- Small enough scope to finish in one week.

## 1.1 Verified Starting Point

Initial baseline checked on **24 October 2026**, before Day 1 implementation:

- Project `LastLight` exists and opens in Godot 4.7.2 stable.
- Godot AI plugin and MCP server both report version 4.3.1.
- MCP is connected to the editor for this project's directory.
- `addons/godot_ai/plugin.cfg` is enabled in `project.godot`.
- The MCP runtime helper is registered as an Autoload.
- The editor reports `no_scene`; no gameplay scenes or scripts exist yet.
- No main scene is configured, so the game is not yet runnable.
- The project currently uses Forward Plus. Validate its cost for the planned 2D lighting before changing renderer settings.

The milestones below are planned work. A working MCP connection completes the editor setup prerequisite, not any gameplay milestone.

## 1.2 Implementation Checklist

Complete the milestones in order. Check an item only after its acceptance criteria pass.

- [x] Verify the Godot project and active MCP connection.
- [x] Day 1: input, player movement, camera, and winter arena.
- [x] Day 2: enemy variants, spawning, contact damage, and player death.
- [x] Day 3: automatic Light Orb attacks and enemy damage/death.
- [x] Day 4: Light Shards, XP, level-ups, and upgrade selection.
- [x] Day 5: Halo, Frost Pulse, upgrade pool, and difficulty progression.
- [x] Day 6: boss, menus, results, audio, and visual feedback.
- [x] Day 7: full-run playtests, balance, bug fixes, and Windows export.

**MVP complete:** share `dist/LastLight-0.1.2-Windows-x64.zip`, extract it, and launch `LastLight.exe`. Version 0.1.2 fixes clipped upgrade, pause, and result menus in the Windows export. See `docs/RELEASE.md` for reproducible build steps and QA evidence. Further work should follow player feedback rather than automatically beginning stretch goals.

## 1.3 Validation and MCP Workflow

For each milestone:

1. Confirm the active MCP session belongs to `last-light` before editor operations.
2. Build the smallest playable version of the current system using placeholder assets.
3. Save modified scenes; editor changes can remain in memory until explicitly saved.
4. Run the relevant scene and exercise the milestone's acceptance criteria.
5. Inspect both editor and game logs; resolve parse errors and runtime failures before continuing.
6. Record completed work and remaining issues in this checklist.

Use focused automated checks for state transitions, XP overflow, upgrade eligibility, and restart cleanup when those systems exist. Verify movement, visual feedback, audio, and full-run balance through playtesting. Before the final export, check Windows export templates and test the exported executable independently of the editor.

## 1.4 Day 1 Delivery — Completed 24 October 2026

The project now boots directly into `scenes/main/game.tscn` using **F5**. Move with **WASD** or the **arrow keys**.

Delivered:

- Reusable `scenes/player/player.tscn` rooted in `CharacterBody2D`, with typed movement code in `scripts/player/player.gd`.
- Normalized eight-direction movement at 240 pixels/second, ground collision, and a camera with smooth following and arena limits.
- A 4400 × 3200 winter arena, with a clear starting area, stone-circle landmark, frozen ponds, decorative trees, rocks, and snow banks.
- Original SVG placeholder art for the keeper and fir trees, plus a warm flickering `PointLight2D` lantern.
- Reusable `scenes/effects/snow_particles.tscn`, with 400 world-space snow particles emitted around the player.
- Minimal title, movement instructions, and a vignette. Trees are decorative; solid collision is limited to the four arena borders.
- The player lives at `Game/World/Environment/Player` so the player and tree sprites can share Y sorting.

Validation performed through the connected Godot AI MCP session:

| Check | Result |
| --- | --- |
| Parse validation of both gameplay scripts | No diagnostics |
| Launch configured main scene | Runtime helper live |
| Simulated W, A, S, D and all four arrow key events | All move in the expected direction |
| Four cardinal and four diagonal movement directions | All correct; speed 240 pixels/second |
| Release movement input | Zero idle drift |
| Camera following after one second at rest | Approximately 0.017 pixels from the player |
| Attempt movement beyond each of the four borders | All blocked; camera remains inside its limits |
| Snow emission and runtime scene inspection | 400 particles emitting; 205 decorative trees |
| Game screenshot | Arena, player, lantern lighting, snow, and instructions render correctly |

This delivery covers the first day's movement-and-arena milestone. Health, combat, enemies, progression, and menus retain their later milestones.

## 1.5 Day 2 Delivery — Completed 24 October 2026

Delivered:

- A reusable `CharacterBody2D` enemy scene and shared chase/contact script, with inherited Wraith, Crawler, and Watcher scenes and distinct SVG silhouettes.
- The planned initial enemy stats: Wraith HP 20 / speed 90 / damage 10; Crawler HP 12 / speed 150 / damage 7; Watcher HP 60 / speed 60 / damage 20. Enemy damage reception and death remain Day 3 work.
- `SpawnManager` creates one enemy every 2.4 seconds, cycles all three variants for this milestone, and caps the population at 45. Composition changes and difficulty scaling remain Day 5 work.
- Spawn locations use the actual transformed camera view, with a 100-pixel margin, and stay inside the arena. Invalid locations are rejected, including near corners; if the viewport covers the whole arena, spawning is skipped.
- Solid collisions between players and enemies, plus separate enemy contact areas and a player hurtbox. Collision layers: world 1, player 2, enemies 3, player hurtbox 4 (bitmasks 1, 2, 4, 8).
- Player health starts at 100. Each accepted hit triggers health signals, a hit flash, and 0.8 seconds of protection against further damage; continued contact can damage again afterward.
- A health bar and numeric HP display. At zero HP, player movement, enemy movement, and spawning stop; the lantern fades and a minimal death overlay offers **Try Again**. Retry reloads the scene with full HP and fresh enemies/spawn state.
- `game_manager.gd` coordinates `PLAYING` and `GAME_OVER` without globally pausing the scene tree. Snow and death feedback can continue after death.

Validation:

- All four gameplay scripts and the smoke test parse without diagnostics through MCP.
- `tests/day2_smoke.gd`: **173 checks, 0 failures** in a fresh headless Godot process. Checks cover automatic spawning, all variants, offscreen placement at the center and four arena corners, camera zoom, an oversized viewport, population limits, chase speed, contact versus distance, body collision, damage cooldown, lethal damage, frozen death state, HUD updates, and the actual retry/scene-reload path.
- MCP runtime inspection confirmed automatic spawning of all three variants and the zero-HP death state. Screenshots confirmed the health display and death overlay; a simulated mouse click on **Try Again** returned to a living player.
- The live editor and game logs report no gameplay errors. The sandboxed headless process emits a Windows root certificate-store warning at startup; it does not affect the checks or their successful exit status.

To repeat the smoke test from the project directory (replace `godot` with the local Godot executable if needed):

```powershell
godot --headless --path . --log-file .godot/day2-smoke.log --script tests/day2_smoke.gd
```

Use **F5** to play and **WASD / arrow keys** to evade enemies. There is no player attack until Day 3.

## 1.6 Day 3 Delivery — Completed 24 October 2026

Delivered:

- Reusable `scenes/weapons/light_orb.tscn`, attached under the player's `WeaponPivot`. The weapon automatically selects the nearest living enemy within 650 pixels and fires every 0.8 seconds. Target queries run on the firing interval.
- `scenes/weapons/light_projectile.tscn`: 15 damage, speed 500 pixels/second, and a 2.5-second lifetime. Projectiles travel toward the target's position at firing time, with no manual aiming or live target reference.
- Projectile collision against enemies and arena walls. Swept motion is split into steps of at most 12 pixels so even a very fast shot reliably stops at the first body. Shots disappear after one impact or when their lifetime expires.
- Enemy damage reception with a hit flash and warm impact particles. Death clamps HP to zero, removes the enemy from target selection immediately, emits a single `enemy_died(world_position, experience)` event, creates cold dispersal particles, and frees the enemy.
- Separate world containers for projectiles and self-cleaning effects. Enemy death frees population capacity; player death clears shots already in flight and prevents future firing. Retry restores the weapon and removes old effects/projectiles.
- New glowing SVG orb art. Spawned enemies, projectiles, and effects receive their position before entering the scene tree to avoid transient placement at the origin.

Validation:

- `tests/day3_smoke.gd`: **44 checks, 0 failures**. Covers nearest-target selection, range, invalid/dead/queued targets, exact projectile damage, all three enemy deaths through the real automatic weapon, expected shot counts, hit flash, burst cleanup, a 30,000-pixel/second shot crossing two enemies, wall collision, projectile expiry, removal of an in-flight target, released spawn capacity, player death, and retry cleanup.
- `tests/day2_smoke.gd`: **173 checks, 0 failures** after this change. Its contact/spawning checks temporarily disable the new weapon so those systems remain independently verifiable.
- MCP parser validation reports no diagnostics for changed gameplay scripts. A fresh play session is live; runtime inspection and a screenshot confirm automatic glowing shots alongside the existing winter arena and enemies. Editor/game logs contain no gameplay errors.
- Headless validation still emits the sandbox certificate-store startup warning documented in section 1.5; both test summaries pass.

Repeat the combat checks from the project directory:

```powershell
godot --headless --path . --log-file .godot/day3-smoke.log --script tests/day3_smoke.gd
```

Use **F5**, move with **WASD / arrow keys**, and let Light Orb attack automatically. Light Shard drops and XP progression remain Day 4 work.

## 1.7 Day 4 Delivery — Completed 24 October 2026

Delivered:

- Spawned enemies are registered through `SpawnManager.enemy_spawned`. Their existing death event creates exactly one Light Shard at the death position: one XP for Wraith/Crawler and three XP for Watcher.
- Reusable `scenes/pickups/light_shard.tscn`, with glowing SVG art, bobbing, and a dedicated pickup collision layer (bitmask 32). The player's 96-pixel `PickupArea` attracts nearby shards; they accelerate toward the player, award XP once on collection, and free themselves.
- Run-local `ExperienceManager`: start at level 1 with zero XP, using `required_xp = 4 + level * 2` (6, 8, 10, ...). Overflow carries across every threshold, including multiple levels from one award. The HUD displays level, XP, and the next threshold.
- `LEVEL_UP` state and real scene-tree pause. Gameplay, enemy movement, projectiles, pickups, and spawning stop while the upgrade menu continues processing. Player damage is rejected during selection.
- Reusable upgrade menu with three distinct randomly selected cards, mouse selection, keyboard **1 / 2 / 3**, and rank display. A selection applies once. Multiple earned levels queue separate choices, and gameplay resumes only after all are resolved.
- Five immutable `.tres` definitions under `resources/upgrades/`, with upgrade ranks stored separately per run:

| Upgrade | Effect per rank | Rank limit |
| --- | --- | --- |
| Pale Flame | Multiply Light Orb damage by 1.20 | Repeatable |
| Quickening | Divide cooldown by 1.15 (+15% attack rate) | Repeatable |
| Winter Stride | Multiply movement speed by 1.20 | 5 |
| Steadfast | Add 20 max HP and restore 20 HP | 5 |
| Moon's Reach | Multiply pickup radius by 1.15 and update its collision shape | Repeatable |

Three repeatable entries ensure that three unique choices remain available after capped upgrades are exhausted. Day 5 can expand this pool and tune the values.

- Death disables XP and dismisses selection; retry restores base stats, XP, ranks, pickups, and menu state. Replacing a scene during an upgrade also releases its pause so the next run can start normally.

Validation:

- `tests/day4_smoke.gd`: **93 checks, 0 failures**. Covers real enemy death/drop signals, shard values/positions, pickup attraction and one-time XP, thresholds, overflow, queued levels, unique choices, mouse-button signals and number-key input, duplicate selection events, paused movement/spawning/projectiles, damage protection during selection, effects of all five upgrades, capped eligibility, upgraded pickup reach, future projectile damage, death, restart, and scene replacement while paused.
- Regression checks: **173 Day 2 checks + 44 Day 3 checks, all passing**. Total across the three suites: **310 checks, 0 failures**.
- MCP parser validation reports no diagnostics for changed gameplay scripts and the new test. A fresh live session confirms XP progression and three offered upgrades while paused. Screenshots show the XP HUD and Light Shards; editor/game logs contain no gameplay errors.
- Headless test startup still reports the sandbox certificate-store warning noted in section 1.5; test summaries pass.

Repeat the progression checks from the project directory:

```powershell
godot --headless --path . --log-file .godot/day4-smoke.log --script tests/day4_smoke.gd
```

Use **F5**, collect the gold Light Shards, and choose upgrades by clicking a card or pressing **1 / 2 / 3**.

## 1.8 Day 5 Delivery — Completed 24 October 2026

All three weapons are equipped from the start of a fresh run:

| Weapon | Initial behavior |
| --- | --- |
| Light Orb | Existing nearest-target attacks; Twin Flame can add up to three extra parallel projectiles |
| Halo | Rotating gold ring, radius 60; deals 6 damage to each enemy inside the radius every 0.65 seconds |
| Frost Pulse | Radius 150; deals 12 damage every 4 seconds and slows surviving targets to 50% speed for 1.5 seconds |

Frost Pulse has an expanding icy ring that cleans itself up. Slow refreshes without multiplying and restores the original speed/tint when it expires. Area attacks share the existing enemy damage, death, shard, and XP flow. The scene-tree pause also freezes weapon cooldowns, slow durations, and the survival clock.

The upgrade catalog now contains **10 entries**. The five original upgrades remain, and Quickening now accelerates all three weapons. Added:

| Upgrade | Effect per rank | Rank limit |
| --- | --- | --- |
| Searing Halo | +20% Halo damage | 5 |
| Winter Crown | +20% Halo radius | 5 |
| Deep Freeze | +20% Frost Pulse damage | 5 |
| Frozen Horizon | +20% Frost Pulse radius | 5 |
| Twin Flame | +1 Light Orb projectile per volley | 3 |

`DifficultyManager` advances during active gameplay and stops on death. It updates spawn interval, population cap, new-enemy stat multipliers, and weighted enemy composition. Existing enemies keep their current stats and damage. The early mixed rotation from Day 2 is replaced by staged composition:

| Run time | Enemy weights: Wraith / Crawler / Watcher | Spawn interval | Population cap |
| --- | --- | --- | --- |
| 00:00 | 100% / 0% / 0% | 1.800 s | 36 |
| 02:00 | 70% / 30% / 0% | 1.504 s | 59 |
| 04:00 | 50% / 30% / 20% | 1.208 s | 82 |
| 06:00 | 40% / 35% / 25% | 0.912 s | 104 |
| 08:00 | 35% / 40% / 25% | 0.616 s | 127 |
| 10:00 | 35% / 40% / 25% | 0.320 s | 150 |

Scaling interpolates between these checkpoints and is bounded at minute 10. At that point new enemies have 2.4× HP, 1.25× speed, and 1.5× contact damage. The HUD shows survival time and the current pressure stage. Retry resets the clock, composition, all weapons, and upgrade ranks.

Validation:

- `tests/day5_smoke.gd`: **118 checks, 0 failures**. Checks Halo radius/tick rate, Frost radius/automatic cooldown/slow/expiry, feedback cleanup, all five new upgrades, Quickening across all weapons, four-projectile hits, shared kill/XP behavior, pause/death/retry, stage composition, scaled spawn stats, timer display, and bounded late-run pressure.
- Regression suites still pass: **173 Day 2 + 44 Day 3 + 93 Day 4 checks**. Total: **428 checks, 0 failures**. Older tests isolate their original systems from the new weapons and difficulty clock.
- `tests/day5_endurance.gd` completed **600 simulated seconds**, using ordinary movement, damage, pickups, and upgrade selection with fixed steering and seeded randomness. The bot remained alive at level 27 with 670 kills. Checkpoints were level 6 / 70 kills at minute 2, level 10 / 156 kills at minute 4, level 15 / 266 kills at minute 6, and level 20 / 417 kills at minute 8.
- The XP curve remains `4 + level * 2` after this run: early level-ups stay frequent and later levels require more collection. Human balancing and the full boss/run flow remain Day 6–7 validation.
- Native MCP inspection confirms three enabled weapons, ten upgrades, and increasing spawn pressure. A screenshot confirms Halo, the XP HUD, survival timer, and pressure stage. An integer-division warning in timer formatting was corrected and the timer checks pass again. A fresh runtime launches without reported gameplay errors.
- Headless processes retain the sandbox certificate-store startup warning documented in section 1.5; the smoke tests and endurance simulation complete successfully.

Repeat the checks from the project directory:

```powershell
godot --headless --path . --log-file .godot/day5-smoke.log --script tests/day5_smoke.gd
godot --headless --fixed-fps 60 --path . --log-file .godot/day5-endurance.log --script tests/day5_endurance.gd
```

Use **F5** to try all three automatic weapons. Boss spawning, dawn victory, and the complete menu-to-result flow remain Day 6 work.

## 1.9 Day 6 Delivery — Completed 24 October 2026

The project now boots into `scenes/main/main_menu.tscn` with **F5**. Choose **Start Run**, move with **WASD / arrow keys**, select upgrades with **1 / 2 / 3** or the mouse, and use **Escape** to pause/resume.

Delivered:

- **The Pale One:** an inherited enemy with original SVG art, 2000 HP, movement speed 45, contact damage 25, and a 25-XP reward. It spawns once at minute 8, fully outside the camera, with space reserved independently of the ordinary enemy population cap.
- **Boss combat:** a visible 0.8-second windup precedes twelve evenly spaced radial projectiles; after each volley the boss waits four seconds before winding up again. Hostile bullets travel at 160 pixels/second, deal 12 damage, expire after six seconds, collide with the player/arena, and respect player invulnerability. Killing the boss removes its projectiles and health display; it never respawns.
- **Boss presentation:** arrival banner, health bar, warning ring, purple projectiles, impact/death feedback, and an arrival sound.
- **Dawn victory:** surviving to minute 10 finishes the run, warms the arena lighting, stops combat/spawning/progression, clears projectiles, and displays **DAWN HAS RETURNED**. Boss defeat is optional. Death displays **THE LIGHT HAS FADED**. Terminal results are committed once and reject subsequent damage/progression.
- **Results:** shared `scenes/main/result_screen.tscn` displays survival time, shadows banished, and final level, with **Play Again** and **Main Menu** buttons. The existing result-overlay node path is retained for gameplay/test compatibility.
- **Main menu:** winter illustration, snow, controls, Start Run/Quit, master volume, and the previous run's summary. Scene changes use a short fade; game entry fades in as well.
- **Pause menu:** Escape or Resume returns to gameplay, Main Menu abandons the current run, and the volume slider remains usable while paused. Escape cannot dismiss a mandatory level-up choice. Scene changes always release owned pause state.
- **RunState Autoload:** stores the last result and master volume across scene changes within the session; gameplay and upgrade ranks remain local to each run.
- **Original audio:** thirteen generated WAV assets: a looping twenty-second ambient bed plus twelve cues for projectile, hit, enemy death, pickup, level-up, player damage, boss arrival, boss shot, pulse, UI selection, victory, and death. A bounded eight-voice pool throttles repeated cues. Menus and gameplay share volume/mute settings. Playback resources are stopped and released on scene exit; Quit allows the mixing thread to finish before shutdown. Regenerate assets with `python tools/generate_audio.py`.
- **Feedback and polish:** a small camera shake and brief screen flash on player damage, boss attack telegraphing, themed menu buttons, kill counter, dawn lighting, and the existing snow/weapon effects.

Validation:

- `tests/day6_smoke.gd`: **67 checks, 0 failures**. Covers main-menu start/double activation, volume/mute persistence, audio assets/loop/voice limits, Escape and button pause/resume, boss timing/single spawn/stats/offscreen placement/telegraph/radial spacing, hostile bullet collision/invulnerability/expiry, boss death, upgrade/pause interaction, victory and death summaries, immutable terminal outcomes, replay, menu navigation, and victory with a living boss.
- Regression suites pass: **173 Day 2 + 44 Day 3 + 93 Day 4 + 118 Day 5 checks**. Combined total: **495 checks, 0 failures**.
- The fixed-frame endurance run completed **600 seconds** with the real boss and result flow. Outcome: **victory**, level **27**, **655 kills**, approximately **33.5 / 120 HP**, boss spawned and still alive at dawn. No invulnerability, stat cheats, or time jumps were used for this run.
- Native MCP parser checks report no diagnostics for changed core, boss, audio, and menu scripts. Screenshots verify the main menu, in-game boss presentation, and victory screen. The preview was stopped after visual QA so the next F5 starts a fresh session.
- Headless tests explicitly stop audio before shutdown to let the audio mixing thread release playback references. Final runs report no gameplay failures or resource-leak diagnostics; the sandbox certificate-store startup warning from section 1.5 remains environmental.

Repeat the flow checks and full-run simulation:

```powershell
godot --headless --path . --log-file .godot/day6-smoke.log --script tests/day6_smoke.gd
godot --headless --fixed-fps 60 --path . --log-file .godot/day6-endurance.log --script tests/day5_endurance.gd
```

The complete menu → run → boss → dawn/death → results → replay/menu loop is implemented. Windows export and testing the exported build remain Day 7 work.

## 1.10 Day 7 Delivery — Completed 24 October 2026

**Shareable release:** `dist/LastLight-0.1.1-Windows-x64.zip` — about **38 MB**.

- `LastLight.exe` is an x64 Windows release with embedded game data, a lantern icon, and version 0.1.1 metadata. It can run without Godot, an installer, or a separate PCK.
- The ZIP contains the executable, `BACA_DULU.txt`, engine/third-party notices, and a SHA-256 file. The main menu exposes embedded credits/licenses as well.
- Release rendering uses Compatibility/OpenGL 3.3 for the 2D game. The development project's renderer and MCP plugin remain configured for editor work; a clean staging project excludes development helpers, tests, and tools from the distribution.
- The matching official Godot 4.7.2 Windows template is cached locally. Reproducible fetch/build/QA scripts, a portable editor cache, and ignored staging/output folders support later rebuilds.
- Final QA found and fixed missing upgrade resources in the initial staging copy and allowed orderly audio cleanup on normal window close. Native screenshots verify menu and gameplay from the actual release executable.
- **495 gameplay regression checks and 20 release-package checks pass.** The regression runner loads the embedded export data with the matching editor engine, while the actual release binary is separately exercised through Windows/OpenGL and native Start/close input.
- Two complete ten-minute runs on the exported data both reach victory: seed 7319 reaches level 27 / 655 kills / 33.5 HP with the boss alive; seed 9254 reaches level 28 / 677 kills / 72 HP after defeating the boss. Existing spawn, damage, and XP curves are retained on this evidence; future balancing can use feedback from friends.
- ZIP CRC and SHA-256 verification confirm that the packaged executable is identical to the tested release. No script failures or resource-leak diagnostics remain in final checks; the sandbox-only certificate-store startup message is documented in the release notes.

Build details, checksums, platform target, and test commands are in **`docs/RELEASE.md`**. The game is ready for Windows playtesting by friends; no stretch-goal features were added.

## 1.11 Exported Menu Layout Fix — 24 October 2026

- Player screenshots revealed upgrade and pause menus centered on the upper-left corner in the exported executable. The result screen had the same fault.
- Reproduced against the embedded data in version 0.1.1: all 75 initial layout checks failed, with zero-sized overlay roots. Source-scene checks passed, explaining why editor playtests missed it.
- Set the three overlay roots to anchor layout mode explicitly. The exported controls now retain full-screen sizing, centered content, and a full-screen dim background.
- Version 0.1.2 passes 93 layout checks across six window-size cases, including 1918×991, 4:3, 16:9, ultrawide, and resizing while pause/upgrade menus are open. The existing 495 gameplay checks and 20 package checks also pass.
- Inspected rendered upgrade and pause screenshots from the packed data through OpenGL, and opened pause through native Escape input in the maximized production executable, then restored the window while paused. Share the replacement `dist/LastLight-0.1.2-Windows-x64.zip`.

---

# 2. Core Design Pillars

## 2.1 Movement Over Complexity

The player should only need to actively control movement.

Core input:

- `WASD`
- Arrow keys as optional secondary input.
- Mouse only for menus/UI.

Combat should be mostly automatic.

The player should make decisions through:

- Positioning.
- Avoiding enemies.
- Collecting experience.
- Choosing upgrades.
- Deciding how aggressively to approach enemies.

---

## 2.2 Strong Atmosphere With Simple Assets

Production value should come from:

- Lighting.
- Snow particles.
- Fog.
- Screen effects.
- Sound effects.
- Music.
- Small visual feedback effects.

Do not depend on large amounts of custom artwork.

Target visual identity:

- Dark winter landscape.
- Charcoal background.
- Cold blue-gray environment.
- Off-white snow.
- Pale gold player light.
- Mostly silhouette-based enemies.

---

## 2.3 Short, Complete Runs

Target run duration:

**8–10 minutes**

A complete gameplay session should be:

```text
Main Menu
	↓
Start Run
	↓
Survive
	↓
Kill Enemies
	↓
Collect Light Shards
	↓
Level Up
	↓
Choose Upgrade
	↓
Enemy Pressure Increases
	↓
Boss / Final Wave
	↓
Dawn or Death
	↓
Result Screen
```

---

# 3. MVP Scope

The MVP must contain only the following core content.

## Player

- 1 playable character.
- 8-direction movement.
- Health.
- Collision.
- Damage feedback.
- Death state.
- Automatic weapon system.

## Enemies

Three enemy types:

1. **Wraith**
   - Basic enemy.
   - Moves directly toward the player.
   - Low HP.
   - Moderate speed.

2. **Crawler**
   - Fast enemy.
   - Low HP.
   - Low contact damage.

3. **Watcher**
   - Slow enemy.
   - Higher HP.
   - Higher contact damage.

## Boss

One boss:

**The Pale One**

Characteristics:

- Appears near the end of the run.
- Large HP pool.
- Slow movement.
- Periodic radial projectile attack.
- Defeating it significantly improves the chance of surviving until dawn.

## Weapons

Three player weapons:

1. **Light Orb**
   - Automatically targets the nearest enemy.
   - Fires projectiles periodically.

2. **Halo**
   - Rotating damage area around the player.

3. **Frost Pulse**
   - Periodic circular pulse.
   - Damages nearby enemies.
   - Briefly slows enemies.

## Upgrades

Minimum 8 upgrade types.

Examples:

- +20% Light Orb damage.
- +15% attack speed.
- +20% player movement speed.
- +20 max HP.
- +15% pickup radius.
- +15% projectile speed.
- +20% Halo radius.
- +20% Frost Pulse radius.
- +1 Light Orb projectile.
- Small passive health regeneration.

Not all upgrades need multiple complex branching paths.

---

# 4. Explicit Non-Goals

Do **not** add the following during the first week:

- Open world.
- Inventory.
- Equipment screen.
- Crafting.
- Dialogue system.
- Quest system.
- Procedural map generation.
- Character classes.
- Multiplayer.
- Online leaderboard.
- Account system.
- Skill tree.
- Large narrative campaign.
- Save-game progression system.
- Multiple maps.
- Multiple bosses.
- Complex status-effect framework.
- Advanced pathfinding.
- Large animation systems.
- Full roguelite meta progression.

If a feature does not directly improve the core 8–10 minute run, defer it.

---

# 5. Project Structure

Recommended filesystem:

```text
res://
│
├── scenes/
│   ├── main/
│   │   ├── main_menu.tscn
│   │   ├── game.tscn
│   │   └── result_screen.tscn
│   │
│   ├── player/
│   │   └── player.tscn
│   │
│   ├── enemies/
│   │   ├── enemy_base.tscn
│   │   ├── wraith.tscn
│   │   ├── crawler.tscn
│   │   ├── watcher.tscn
│   │   └── pale_one.tscn
│   │
│   ├── weapons/
│   │   ├── light_orb.tscn
│   │   ├── light_projectile.tscn
│   │   ├── halo.tscn
│   │   └── frost_pulse.tscn
│   │
│   ├── pickups/
│   │   └── light_shard.tscn
│   │
│   ├── effects/
│   │   ├── hit_effect.tscn
│   │   ├── death_effect.tscn
│   │   └── snow_particles.tscn
│   │
│   └── ui/
│       ├── hud.tscn
│       ├── upgrade_menu.tscn
│       └── pause_menu.tscn
│
├── scripts/
│   ├── game/
│   │   ├── game_manager.gd
│   │   ├── spawn_manager.gd
│   │   └── difficulty_manager.gd
│   │
│   ├── player/
│   │   └── player.gd
│   │
│   ├── enemies/
│   │   ├── enemy_base.gd
│   │   └── boss.gd
│   │
│   ├── weapons/
│   │   ├── weapon_base.gd
│   │   ├── light_orb.gd
│   │   ├── projectile.gd
│   │   ├── halo.gd
│   │   └── frost_pulse.gd
│   │
│   ├── progression/
│   │   ├── experience_manager.gd
│   │   ├── upgrade_manager.gd
│   │   └── upgrade_data.gd
│   │
│   └── ui/
│       ├── hud.gd
│       ├── upgrade_menu.gd
│       └── result_screen.gd
│
├── resources/
│   └── upgrades/
│
├── assets/
│   ├── sprites/
│   ├── audio/
│   ├── fonts/
│   └── shaders/
│
└── autoload/
	└── run_state.gd
```

Keep folder structure simple. Do not create additional architectural layers unless necessary.

---

# 6. Scene Architecture

## Game Scene

Recommended root:

```text
Game
├── World
│   ├── Background
│   ├── Environment
│   ├── EnemyContainer
│   ├── ProjectileContainer
│   ├── PickupContainer
│   └── EffectContainer
│
├── Player
│
├── Managers
│   ├── SpawnManager
│   ├── DifficultyManager
│   └── ExperienceManager
│
├── CanvasLayer
│   └── HUD
│
└── Audio
```

The `Game` scene should coordinate systems but avoid containing every gameplay implementation directly.

---

# 7. Player System

Recommended node:

```text
Player (CharacterBody2D)
├── Sprite2D
├── CollisionShape2D
├── Hurtbox (Area2D)
│   └── CollisionShape2D
├── PickupArea (Area2D)
│   └── CollisionShape2D
├── WeaponPivot
├── Camera2D
└── PointLight2D
```

Core properties:

```text
max_health
current_health
movement_speed
pickup_radius
damage_multiplier
attack_speed_multiplier
```

Responsibilities:

- Read movement input.
- Move using `CharacterBody2D`.
- Receive damage.
- Trigger death.
- Expose upgradeable stats.
- Provide player position to targeting systems.

The player script should **not** directly manage:

- Enemy spawning.
- Level-up UI.
- Global timer.
- Wave difficulty.
- Result screen.

---

# 8. Enemy System

Use a reusable base enemy implementation.

Base data:

```text
max_health
current_health
movement_speed
contact_damage
experience_value
```

Basic behavior:

```text
find player
	↓
move toward player
	↓
touch player
	↓
deal contact damage
```

Do not implement navigation meshes.

The arena should remain open enough that simple direct movement works.

Enemy variants should mostly differ through:

- Stats.
- Sprite.
- Scale.
- Movement speed.
- Optional special behavior.

---

# 9. Combat System

## Light Orb

Behavior:

```text
Timer expires
	↓
Find nearest valid enemy
	↓
Spawn projectile
	↓
Projectile travels toward target
	↓
Collision
	↓
Deal damage
	↓
Destroy projectile
```

Targeting should use the nearest active enemy inside a configurable range.

Avoid expensive global searches every frame.

Target selection should happen only when firing.

---

## Halo

Halo stays around the player.

It may use:

- `Area2D`
- Rotating child sprites/projectiles
- Periodic overlap damage

Prefer the simplest reliable implementation.

---

## Frost Pulse

Timer-driven AoE attack:

```text
Cooldown ends
	↓
Create pulse
	↓
Detect enemies in radius
	↓
Deal damage
	↓
Apply brief slow
```

The pulse should have strong visual feedback.

---

# 10. Health and Damage

Damage pipeline:

```text
Attack
	↓
Hitbox detects Hurtbox
	↓
take_damage(amount)
	↓
HP decreases
	↓
hit feedback
	↓
HP <= 0?
	↓
die()
```

Player and enemies may share a similar health pattern, but do not over-engineer a universal damage framework during the MVP.

Required feedback:

- Small hit flash.
- Short particle effect.
- Floating damage text is optional.
- Brief screen shake for stronger attacks/boss damage.

---

# 11. Experience System

Enemies drop **Light Shards** when defeated.

Shard behavior:

1. Spawn at enemy death position.
2. Remain stationary or float gently.
3. Detect player pickup radius.
4. Move toward player when inside magnet radius.
5. Add experience when collected.
6. Destroy itself.

Player progression:

```text
XP
 ↓
Level Threshold
 ↓
Level Up
 ↓
Pause Gameplay
 ↓
Show 3 Upgrades
 ↓
Player Selects One
 ↓
Apply Upgrade
 ↓
Resume Gameplay
```

Suggested XP curve:

```text
required_xp = base_xp + level * growth
```

Keep the curve simple and easy to rebalance.

---

# 12. Upgrade System

Represent upgrades as data rather than hardcoding the UI.

Recommended fields:

```text
id
display_name
description
icon
max_level
current_level
weight
upgrade_type
value
```

Example:

```text
ID: light_orb_damage
Name: Pale Flame
Description: Light Orb deals 20% more damage.
Max Level: 5
Type: DAMAGE_MULTIPLIER
Value: 0.20
```

Upgrade selection:

1. Get all upgrades that have not reached max level.
2. Randomly select 3 unique entries.
3. Display choices.
4. Apply selected upgrade.
5. Increment upgrade level.

Avoid complex rarity systems in MVP.

---

# 13. Difficulty Progression

The run should continuously increase pressure.

Difficulty variables:

- Enemy spawn interval.
- Enemy maximum count.
- Enemy HP multiplier.
- Enemy speed multiplier.
- Enemy damage multiplier.
- Enemy composition.

Suggested timeline:

```text
00:00–02:00
Mostly Wraiths

02:00–04:00
Wraith + Crawler

04:00–06:00
All normal enemy types

06:00–08:00
Higher spawn density

08:00+
The Pale One appears
```

Dawn target:

**10:00**

Winning condition:

```text
Survive until dawn.
```

Boss does not strictly need to die for victory unless balancing shows that it improves the experience.

---

# 14. Spawn System

Spawn enemies outside the visible player area.

Recommended method:

1. Select random angle.
2. Calculate position around player at spawn radius.
3. Spawn enemy.
4. Ensure position is outside the camera viewport.
5. Add enemy to EnemyContainer.

Example conceptual formula:

```text
spawn_position =
player_position +
Vector2.RIGHT.rotated(random_angle) * spawn_radius
```

Do not implement map-wide spawn points unless necessary.

---

# 15. Boss — The Pale One

Spawn time:

Approximately minute 8.

Behavior:

- Slowly chases player.
- High HP.
- Contact damage.
- Every few seconds fires radial projectiles.
- Optional short charge animation before attack.

Attack:

```text
	   ↑
	↖  |  ↗

← ---- B ---- →

	↙  |  ↘
	   ↓
```

Keep the boss mechanically simple.

The challenge should mainly come from:

- Existing enemy pressure.
- Boss durability.
- Radial projectile pattern.

---

# 16. Game State

Main states:

```text
MAIN_MENU
PLAYING
LEVEL_UP
PAUSED
VICTORY
GAME_OVER
```

Avoid scattering pause logic across multiple scripts.

`GameManager` should coordinate major state transitions.

---

# 17. UI Requirements

## HUD

Display:

- Health bar.
- XP bar.
- Current level.
- Survival timer.
- Optional kill count.

Suggested layout:

```text
┌─────────────────────────────────┐
│ HP ███████                      │
│ XP █████                        │
│                                 │
│                         07:32   │
│                                 │
│                                 │
│                                 │
│          GAMEPLAY               │
│                                 │
│                                 │
│ Lv. 8                           │
└─────────────────────────────────┘
```

---

## Upgrade Menu

When player levels up:

- Pause gameplay.
- Darken background.
- Display exactly 3 choices.
- Allow mouse selection.
- Optional keyboard shortcuts `1`, `2`, `3`.

Each card contains:

```text
Upgrade Name
Current → Next Level
Short Description
```

---

## Result Screen

Victory:

```text
DAWN HAS RETURNED
```

Death:

```text
THE LIGHT HAS FADED
```

Display:

- Time survived.
- Enemies defeated.
- Final level.
- Optional damage dealt.

Buttons:

- Play Again.
- Main Menu.

---

# 18. Audio

Minimum audio requirements:

- Background ambient music.
- Player projectile sound.
- Enemy hit sound.
- Enemy death sound.
- XP pickup sound.
- Level-up sound.
- Player damage sound.
- Boss appearance cue.

Music does not need dynamic layers for MVP.

---

# 19. Visual Effects

Minimum polish:

- Snow particles.
- Player light.
- Enemy death particles.
- Projectile glow.
- Hit flash.
- Frost Pulse ring.
- Small camera shake.
- Fade transitions.

Optional:

- Vignette.
- Subtle fog shader.
- Chromatic distortion on player damage.
- Low-health light flicker.

Avoid expensive shader experimentation until gameplay is complete.

---

# 20. Input Map

Configure:

```text
move_up
move_down
move_left
move_right
pause
```

Suggested mapping:

```text
move_up    → W / Up
move_down  → S / Down
move_left  → A / Left
move_right → D / Right
pause      → Escape
```

---

# 21. Autoload

Use an Autoload only when data must survive scene transitions.

Recommended:

```text
RunState
```

Store:

```text
last_run_time
last_run_kills
last_run_level
last_run_result
```

Do not place ordinary gameplay logic inside the Autoload.

---

# 22. Development Milestones

## Day 1 — Movement and Arena

**Status: complete.** See section 1.4 for implementation details and validation evidence.

### Tasks

- [x] Create Godot project.
- [x] Configure input actions.
- [x] Create `game.tscn`.
- [x] Implement player movement.
- [x] Add camera.
- [x] Create simple winter arena.
- [x] Add temporary sprites/placeholders.
- [x] Add snow particles.

### Acceptance Criteria

- [x] Game launches.
- [x] Player can move smoothly using WASD.
- [x] Camera follows player.
- [x] Arena renders correctly.
- [x] No script errors.

---

## Day 2 — Enemy System

**Status: complete.** See section 1.5 for implementation details and validation evidence.

### Tasks

- [x] Create base enemy.
- [x] Implement enemy chase.
- [x] Implement player/enemy collision.
- [x] Implement player health.
- [x] Add Wraith.
- [x] Add Crawler.
- [x] Add Watcher.
- [x] Create SpawnManager.

### Acceptance Criteria

- [x] Enemies spawn outside camera.
- [x] Enemies move toward player.
- [x] Contact reduces player health.
- [x] Player can die.
- [x] Three enemy variants spawn successfully.

---

## Day 3 — Combat

**Status: complete.** See section 1.6 for implementation details and validation evidence.

### Tasks

- [x] Build Light Orb.
- [x] Add automatic targeting.
- [x] Add projectile collision.
- [x] Add enemy health.
- [x] Implement enemy death.
- [x] Add basic hit/death feedback.

### Acceptance Criteria

- [x] Player automatically attacks.
- [x] Projectiles target enemies.
- [x] Enemies take damage.
- [x] Enemies die correctly.
- [x] No manual aiming is required.

---

## Day 4 — Experience and Level Up

**Status: complete.** See section 1.7 for implementation details and validation evidence.

### Tasks

- [x] Add Light Shard pickup.
- [x] Implement XP.
- [x] Implement player level.
- [x] Create upgrade menu.
- [x] Pause game during upgrade selection.
- [x] Implement first 5 upgrades.

### Acceptance Criteria

- [x] Dead enemies drop XP.
- [x] Player collects XP.
- [x] Player levels up.
- [x] Three upgrade choices appear.
- [x] Selected upgrades modify gameplay.

---

## Day 5 — Weapons and Progression

**Status: complete.** See section 1.8 for implementation details and validation evidence.

### Tasks

- [x] Add Halo.
- [x] Add Frost Pulse.
- [x] Expand upgrade list to 8–10.
- [x] Add difficulty scaling.
- [x] Add enemy composition changes.
- [x] Tune XP progression.

### Acceptance Criteria

- [x] Three weapon systems work.
- [x] Level-ups meaningfully increase player power.
- [x] Difficulty noticeably increases during the run.
- [x] Run remains playable from minute 0 onward.

---

## Day 6 — Boss and Polish

**Status: complete.** See section 1.9 for implementation details and validation evidence.

### Tasks

- [x] Add The Pale One.
- [x] Implement radial boss attack.
- [x] Add UI polish.
- [x] Add audio.
- [x] Add visual effects.
- [x] Add main menu.
- [x] Add result screen.
- [x] Add pause menu.

### Acceptance Criteria

- [x] Boss appears.
- [x] Boss attack works.
- [x] Player can win or lose.
- [x] Full menu-to-result flow works.
- [x] Audio and VFX provide basic feedback.

---

## Day 7 — Balance, QA, Export

**Status: complete.** See section 1.10 and `docs/RELEASE.md` for the tested release.

### Tasks

- [x] Play multiple complete runs.
- [x] Fix gameplay bugs.
- [x] Balance enemy spawn rate.
- [x] Balance player damage.
- [x] Balance XP progression.
- [x] Verify victory condition.
- [x] Verify death condition.
- [x] Clean console warnings.
- [x] Export Windows `.exe`.

### Acceptance Criteria

The following flow works without manual intervention:

```text
Launch Game
 ↓
Main Menu
 ↓
Start
 ↓
Play Full Run
 ↓
Level Up Multiple Times
 ↓
Boss Appears
 ↓
Victory or Death
 ↓
Result Screen
 ↓
Play Again
```

No blocking bugs.

---

# 23. MVP Definition of Done

The project is considered complete when:

- [x] The game launches from an exported Windows build.
- [x] The player can move.
- [x] Enemies continuously spawn.
- [x] Enemies can damage the player.
- [x] The player attacks automatically.
- [x] Enemies can die.
- [x] Enemies drop XP.
- [x] The player can level up.
- [x] Level-up presents three upgrade choices.
- [x] At least 8 upgrades work.
- [x] Three weapons work.
- [x] Three regular enemy types exist.
- [x] One boss exists.
- [x] Difficulty increases over time.
- [x] Player can die.
- [x] Player can survive until dawn.
- [x] Victory screen works.
- [x] Game over screen works.
- [x] Restart works.
- [x] No critical console errors remain.

---

# 24. Agent / Vibe Coding Rules

When using an AI coding agent:

1. **Do not expand scope without explicit instruction.**
2. Implement one system at a time.
3. Prefer native Godot nodes and APIs.
4. Prefer simple GDScript over abstraction-heavy architecture.
5. Avoid introducing plugins unless essential.
6. Avoid custom frameworks.
7. Do not create unnecessary manager classes.
8. Use typed GDScript where practical.
9. Keep scripts short and focused.
10. Do not rewrite working systems unless required.
11. Run/test the project after each meaningful feature.
12. Fix parser/runtime errors before continuing.
13. Preserve existing scene relationships unless a change is necessary.
14. Never implement deferred features from the Non-Goals section.
15. Use placeholder assets freely until gameplay is complete.

When uncertain between:

```text
clever architecture
```

and:

```text
simple working implementation
```

choose the simple working implementation.

---

# 25. Code Quality Rules

Use typed properties where useful:

```gdscript
@export var movement_speed: float = 240.0
var current_health: float
```

Prefer signals for meaningful cross-system events:

```text
player_died
enemy_died
experience_collected
level_up
upgrade_selected
run_finished
```

Avoid unnecessary signal chains.

Use groups for common queries:

```text
player
enemies
projectiles
pickups
```

Do not perform expensive full-tree searches every frame.

---

# 26. Git Workflow

Recommended branches:

```text
main
dev
```

For a one-week solo project, feature branches are optional.

Suggested commits:

```text
feat: add player movement
feat: implement enemy spawning
feat: add automatic light orb attack
feat: implement experience and leveling
feat: add upgrade selection
feat: add halo and frost pulse
feat: add pale one boss
feat: add menus and run results
fix: rebalance enemy spawn progression
chore: prepare windows export
```

Commit after every stable milestone.

---

# 27. Asset Strategy

During Days 1–5:

Use:

- Primitive shapes.
- Simple sprites.
- Placeholder SFX.
- Temporary fonts.

During Day 6:

Replace only the most visible placeholders.

Priority order:

1. Player.
2. Enemy silhouettes.
3. Projectiles.
4. UI icons.
5. Background.
6. Audio.

Do not postpone gameplay systems because final art is missing.

---

# 28. Balancing Targets

Initial targets only.

Player:

```text
HP: 100
Move Speed: 240
```

Wraith:

```text
HP: 20
Speed: 90
Damage: 10
XP: 1
```

Crawler:

```text
HP: 12
Speed: 150
Damage: 7
XP: 1
```

Watcher:

```text
HP: 60
Speed: 60
Damage: 20
XP: 3
```

Light Orb:

```text
Damage: 15
Cooldown: 0.8 sec
Projectile Speed: 500
```

Boss:

```text
HP: 1500–2500
Speed: 45
Contact Damage: 25
Radial Attack Cooldown: 4 sec
```

These values are placeholders and should be tuned through playtesting.

---

# 29. Stretch Goals

Only begin these after the MVP Definition of Done is fully satisfied.

Possible extensions:

- Weapon evolutions.
- Permanent meta progression.
- Multiple playable characters.
- Additional bosses.
- Additional arenas.
- Difficulty modifiers.
- Endless mode.
- Run history.
- Unlock system.
- Steam integration.
- Controller support.
- Mobile build.
- Web build.

---

# 30. Future Evolution Concept

If the prototype proves fun, LAST LIGHT can evolve into a larger roguelite.

Possible future loop:

```text
Run
 ↓
Collect Essence
 ↓
Return to Sanctuary
 ↓
Unlock Relics
 ↓
Unlock Characters
 ↓
Start Harder Run
```

Potential weapon evolution examples:

```text
Pale Flame + Moon's Reach
		↓
Eclipse Orb
```

```text
Halo + Frost Heart
		↓
Winter Crown
```

```text
Frost Pulse + Frozen Blood
		↓
Everwinter
```

These systems are intentionally excluded from the one-week MVP.

---

# 31. Final Project Rule

The success metric is **not** the amount of features implemented.

The success metric is:

> A complete, atmospheric, replayable 8–10 minute game that can be launched, played, won or lost, and exported within one week.

Finish the core loop first.

Polish second.

Expansion last.
