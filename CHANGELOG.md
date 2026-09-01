# Changelog

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
