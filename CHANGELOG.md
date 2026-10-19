# Changelog

## v12.036

- Removed the unused damage-meter source and disabled combat-reader features.
- Removed inactive tracing and unused combat helpers.
- Retired unused spam settings from new profiles and exports while preserving
  existing saved values and compatibility with older profile imports.

## v12.035

- Increased incoming damage grouping to 200 ms on Retail and Forever.
- Matched incoming healer names within 200 ms in either event order while
  retaining the 120 ms heal grouping window.
- Deferred incoming heal spell attribution until the end of the frame.
- Hid skill names by default while retaining damage amounts and icons.

## v12.034

- Added WoW Retail 12.1.5 compatibility and CurseForge game-version metadata.

## v12.033

- Re-released the v12.032 changes with an incremented addon version.

## v12.032

- Added per-profile custom aura rows with visibility, color, font, message,
  scroll-area, sound, and sticky settings.
- Added explicit faded text for buff removals and restored missing notification
  event defaults.
- Fixed hidden color swatches failing when closing settings dialogs.
- Preserved healing colors and the Hide Skills option in the new combat path.

## v12.031

- Added display support for protected combat amounts without inspecting them in Lua.
- Deferred incoming heal attribution until the display callback.
- Added health-based incoming overheal estimates and a combat-text heal fallback.
- Added pet spell/melee attribution and unnamed solo DoT tick output.
- Guarded restricted damage-meter spell data before calculating deltas.
- Embedded the options in Blizzard Settings with a subcategory per tab.
- Kept MSBT incoming group filtering in the left General settings column and
  added a separate Blizzard incoming toggle below its group combat-text option.
- Preserved Blizzard outgoing combat text when incoming text is disabled and
  deferred combat-text setting changes until combat ends.

## v12.030

- Added profile import and export with validation, a Copy button, and dialogs
  styled to match the options menu.
- Fixed exports containing retired profile settings.
- Restyled all options popups, including Add Sound, Master Fonts, color editors,
  event settings, and scroll-area dialogs, with clearer spacing and layering.
- Fixed stale combat timers, expired throttle windows, and completed animation
  references; preserved cooldown tracking across combat transitions.
- Fixed loot notifications for uncached items and vehicle damage-meter polling
  when no pet is present.
- Removed unreachable options, unused resources, and dormant runtime code while
  preserving active addon behavior.

## v12.029

- Prevented profile changes from calling Blizzard's combat-text message refresh
  on modern-API clients, avoiding the reported secret-number taint error.
- Preserved combat-text message refresh on legacy clients.

## v12.028

- Added WoW Forever 1.60.1 support through a dedicated Camelot interface file.
- Added explicit Forever client detection for its Classic-content and modern-API
  combination.
- Fixed Forever options loading when only the modern localized class-list API is
  available.
- Enabled immediate ranged outgoing damage through Forever's modern damage-meter
  API while retaining the guarded fallback for clients without it.
- Added CurseForge 1.60.1 release metadata and automated Forever compatibility
  coverage.

## v12.027

- Restored item cooldown-ready notifications for used trinkets and potions.
- Restored the bundled cooldown sound and its event settings.
- Kept Low Health and Low Mana notifications disabled and did not bundle
  their unused sounds.

## v12.026

- Restored custom event sounds, including General's Enable Sounds and Add Sound
  controls, per-event sound selection, custom file paths, and playback previews.
- Restored saved custom sound registrations and event assignments, plus sounds
  registered through LibSharedMedia or MSBT's public sound API.
- Event sounds respect disabled events, scroll areas, group suppression, and the
  global sound setting. Cooldown and bundled alert sounds remain removed.
- Switched release ZIP creation to BigWigs' packager with `.pkgmeta` exclusions
  for development files and unused Trigger Settings icons.
- Added checks of the completed ZIP before upload to reject unexpected files
  and missing TOC/XML dependencies while preserving runtime assets and notices.

## v12.025

- Fixed batched combat events incorrectly using critical-hit styling when only some hits were critical.
- Split normal and critical hits into their configured scroll areas.
- Reorganized the addon into focused core, API, service, display, combat,
  tracking, and configuration components.
- Added guarded adapters for Blizzard restricted values and modern combat APIs.
- Preserved stacked outgoing hits, incoming filtering, profile behavior, and
  scrolling-area output through the componentized event pipeline.
- Removed unsupported cooldown tracking, event sounds, bundled sound assets,
  and their obsolete options and localization entries.
- Removed unreachable options tabs and commented-out legacy code.
- Added Lua 5.1 parsing and automated component regression coverage.

## v12.024

- Removed unreliable attacker and healer names from incoming damage and healing.
- Applied incoming name suppression to immediate, combined, and fallback combat output.

## v12.023

- Excluded non-runtime files from release bundles: `tests/`, `scripts/`, `README.md`, `CHANGELOG.md`, and `API.html`.
- Added a regression test to keep release packaging focused on runtime addon files only.

## v12.022

- Fixed CurseForge release metadata to publish explicit WoW Retail `12.1.0` game-version names.
- Bumped the addon version to `12.022`.

## v12.021

- Fixed `UnitAttackSpeed("player")` secret-number handling in auto-attack fallback timing.
- Prevented restricted-content arithmetic errors caused by secret swing-speed values.
- Hardened `MSBTMain.lua` against Blizzard secret booleans in target/focus heal attribution and target validation paths.
- Fixed secret-string comparison issues in monster emote matching and safe string-key generation.
- Hardened damage-meter outgoing polling against secret GUID / secret key failures.
- Reworked damage-meter dedupe/cache keys to avoid indexing Lua tables with secret GUID-derived values.
- Hardened `MSBTParser.lua` pet-map refresh logic against secret booleans, secret GUID comparisons, and secret GUID table-key writes.
