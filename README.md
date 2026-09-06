# Mik's Scrolling Battle Text

Mik's Scrolling Battle Text is a World of Warcraft addon that replaces Blizzard's default floating combat text with configurable scrolling areas around your character.

## Status

- Current version: `12.026`
- Supported interface values: `120100`, `11504`, `40400`, `110002`
- Addon type: combat text replacement and combat event presentation

## What It Does

MSBT shows combat information in separate on-screen scroll areas instead of relying on Blizzard's default floating text.

Core capabilities:

- outgoing damage and outgoing heals
- incoming damage and incoming heals
- notifications such as loot, XP, reputation, and procs
- configurable crit styling, fonts, colors, and animations
- sticky crit support
- short-number formatting
- hit stacking and merge behavior
- cooldown completion alerts for supported sources
- custom fonts, sounds, and animation styles
- profile-based settings

## Main Option Areas

The addon options are split into focused sections:

- `General`: master enable state, Blizzard combat text behavior, short numbers, hit stacking, icons, animation speed, fonts, and shared media controls
- `Scroll Areas`: placement and behavior for the scrolling regions
- `Events`: per-event toggles, colors, crit handling, and filtering
- `Cooldowns`: cooldown alert configuration
- `Loot`: item and currency display behavior
- `Spam Control`: throttling and merge rules
- `Profile`: profile management
- `Language`: localization selection
- `Restore Blizzard SCT`: restores Blizzard scrolling combat text settings and disables MSBT-specific overrides

## Installation

1. Download or clone this repository.
2. Place the `MikScrollingBattleText` folder into your WoW `Interface/AddOns` directory.
3. Restart the game or reload the UI.
4. Open the addon settings with `/msbt`.

## Commands

- `/msbt`
- `/msbt menu`
- `/msbt show`
- `/msbt hide`
- `/msbt reset`

Exact command availability depends on the current addon modules and client build.

## Custom Sounds

1. Place an `.ogg` or `.mp3` file under WoW's `Interface/AddOns` directory. A
   separate personal media folder keeps it outside MSBT's update directory, for
   example `Interface\AddOns\MySounds\bell.ogg`.
2. Fully restart WoW after adding sound files.
3. Open `/msbt`, then select `General`. Check `Enable Sounds` and use `Add Sound`
   to register a name and the file's path relative to your WoW folder.
4. In `Events`, open an event's settings, select the sound, use `Play` to preview
   it, then save. The custom-file button also accepts a path without registration.

Choose `None` to clear an event's sound. Existing saved assignments and sounds
registered through LibSharedMedia are also available. Event playback follows
the event, scroll-area, group, and addon enable settings; preview is available
even when `Enable Sounds` is unchecked.

Legacy filenames such as `bell.ogg` resolve under
`Interface\AddOns\MikScrollingBattleText\Sounds\`; provide your own files there
if using that form. MSBT no longer bundles sound files or provides cooldown,
low-health, or low-mana sound alerts.

Other addons can call `MikSBT.RegisterSound(name, pathOrFileID)` after MSBT loads
and enumerate registrations with `MikSBT.IterateSounds()`. Programmatic
registrations must be repeated each session; registrations made through
`Add Sound` are saved automatically.

## Files You May Care About

- [MikScrollingBattleText.toc](MikScrollingBattleText.toc): addon metadata and load order
- [MSBTMain.lua](MSBTMain.lua): runtime display pipeline and event handling
- [MSBTParser.lua](MSBTParser.lua): combat and message parsing
- [MSBTProfiles.lua](MSBTProfiles.lua): saved settings and profile behavior
- [MSBTOptions](MSBTOptions): options UI
- [Localization](Localization): base addon localization
- [MSBTOptions/Localization](MSBTOptions/Localization): options localization
- [API.html](API.html): public addon API reference
- [CHANGELOG.md](CHANGELOG.md): current release notes

## Release Workflow

This repository includes a GitHub Actions workflow for packaging and publishing releases to CurseForge.

BigWigs' packager builds the ZIP using `.pkgmeta`. Its exclusions keep tests,
build tools, docs, editor/agent settings, backups, local custom sounds, and unused
Trigger Settings icons out of releases without deleting repository files.

The completed ZIP is checked before upload for missing TOC/XML dependencies,
unexpected files, and intact runtime assets. Update `.pkgmeta` when excluding
additional development files, and update the archive tests when adding runtime
media. BigWigs runs in package-only mode; the existing CurseForge upload step
still controls publishing and game-version metadata.

Release flow:

1. Update the version in `MikScrollingBattleText.toc`.
2. Update `CHANGELOG.md` for that release.
3. Push the release commit.
4. Create and push a matching git tag such as `v12.021`.
5. GitHub Actions validates the tag against the TOC version.
6. If validation passes, the workflow builds the addon zip and uploads it to CurseForge.

Manual dry run:

1. Open the `CurseForge Release` workflow in GitHub Actions.
2. Run it with `upload_to_curseforge` unchecked.
3. Review the artifact and workflow summary.
4. Run it again with upload enabled when ready.

## Notes

- Recent addon work has focused on safer handling of Blizzard restricted values, UI cleanup, localization cleanup, and General tab quality-of-life options.
- Some legacy documentation still exists in `API.html` because it documents the public addon API separately from this repository overview.
