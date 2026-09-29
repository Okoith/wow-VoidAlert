# VoidAlert

<p align="center"><img src="docs/voidAlert.png" alt="VoidAlert logo" width="256"></p>

World of Warcraft addon (Retail 12.1, Midnight) for **Devourer Demon Hunters**. It plays a sound as soon as

- **Void Metamorphosis** becomes usable (after consuming 50 soul fragments), and
- **Collapsing Star** becomes usable (during Void Metamorphosis, with 30 soul fragments).

Sound only, nothing is shown on the screen.

## Features

- **Two alerts** with their own sound, each can be turned on or off
- **Bundled voice alerts** in English and German; the default follows your client language (German client: German voice, otherwise English)
- **Your own sounds:** up to five files in a separate folder that survives addon updates
- **LibSharedMedia:** every sound registered by other addons can be used, and VoidAlert's own sounds are registered there for other addons
- **WoW sounds:** a few built-in game sounds such as Raid Warning or Ready Check
- **Sound channel:** Master (default), SFX, Dialog, Music or Ambience
- **Only in combat** (on by default)
- **Only active for Devourer Demon Hunters;** silent for all other classes and specializations
- **Languages:** English and German

## Installation

Install VoidAlert from [CurseForge](https://curseforge.com/project/1717922) (for example with the CurseForge app), or download the zip from the [Releases](../../releases) page and extract it to `World of Warcraft\_retail_\Interface\AddOns\`.

The zip contains all required libraries. A plain copy of the repository does **not** work, because the libraries are only added by the packager.

## Usage

### Settings

Type `/voidalert` or open *Settings > AddOns > VoidAlert*. Changes apply immediately.

- **Status line** at the top: shows the detected specialization, or a note that VoidAlert is inactive on this character (not a Devourer Demon Hunter).
- **Void Metamorphosis** and **Collapsing Star:** turn the alert on or off, choose its sound, *Test* button.
- **General:** sound channel (Master, Sound effects, Dialog, Music, Ambience), only in combat, *Test both* button.
- **Custom sounds:** where to put your own files (see below).
- **Debug:** debug mode and *Clear log*.
- **Profiles** (own entry under VoidAlert): settings are stored per character; switch, copy from another character or reset.

The sound list contains, in this order: the bundled VoidAlert sounds, your own sounds, WoW sounds and all sounds registered with LibSharedMedia by other addons. If a chosen sound is no longer available (for example because the addon that provided it was removed), it is shown as *(missing)* and the default sound is played instead; your choice is kept.

### Commands

| Command | Effect |
|---|---|
| `/voidalert` | Open the settings |
| `/voidalert help` | List the commands |
| `/voidalert status` | Show whether VoidAlert is active and the current settings |
| `/voidalert test [meta\|star]` | Play both alerts one after the other (or only one) |
| `/voidalert sounds` | List all available sounds with their numbers |
| `/voidalert sound meta\|star <number>` | Choose a sound from the list; `default` restores the default |
| `/voidalert toggle meta\|star` | Turn an alert on or off |
| `/voidalert channel master\|sfx\|dialog\|music\|ambience` | Sound channel |
| `/voidalert combat on\|off` | Only play alerts in combat |
| `/voidalert debug on\|off\|clear\|status` | Debug log (`VoidAlertDebugLog` in SavedVariables, off by default) |

Changes made with commands are shown in the open settings window right away.

### Your own sounds

1. Create the folder `World of Warcraft\_retail_\Interface\AddOns\VoidAlert_Sounds\`.
2. Put your files there as `sound1.ogg` to `sound5.ogg` (the names are fixed).
3. **Restart WoW completely.** `/reload` does not detect new files.
4. Choose them in the settings (*Custom: sound1.ogg* …) or with `/voidalert sounds` and `/voidalert sound meta <number>`.

The folder is separate from the `VoidAlert` folder, so updates do not touch your files. If a chosen file is missing, VoidAlert tells you once in the chat.

## How it works

VoidAlert listens to the spell activation glow of the game (`SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`), the same glow you see on your action button:

| Alert | Spell ID in the event |
|---|---|
| Void Metamorphosis | 1217605 |
| Collapsing Star | 1221150 (the variant during Void Metamorphosis) |

A sound is played only when the glow appears, not when it disappears. Each alert is blocked for 2 seconds after it played, so it never plays twice in a row.

The detection was worked out in game with a test addon (`docs/reference/VoidAlert_Test.lua`): of all tested ways, only the glow event was readable and reliable in combat.

VoidAlert is active when your character knows Void Metamorphosis or is in the Devourer specialization. This is checked again when you change your specialization or talents.

## Development

Libraries are fetched by the [BigWigs packager](https://github.com/BigWigsMods/packager) from `.pkgmeta` and are not part of the repository: LibStub, CallbackHandler-1.0, AceDB-3.0, AceDBOptions-3.0, AceGUI-3.0, AceConfig-3.0, LibSharedMedia-3.0.

### Releases

Pushing a tag `v*` (for example `v1.0.0`, test builds `v1.0.0-alpha.N` or `v1.0.0-beta.N`) starts `.github/workflows/release.yml`. It builds a zip with all libraries and the bundled sounds, publishes it as a GitHub release and uploads it to [CurseForge](https://curseforge.com/project/1717922).

**CurseForge upload:** the packager uploads to CurseForge when both a token and a project ID are present:

- the project ID is set in `VoidAlert.toc` (`## X-Curse-Project-ID: 1717922`),
- the API token is stored as the Actions secret **`CF_API_TOKEN`** (*Settings > Secrets and variables > Actions*) and passed to the packager by the workflow. A new token can be created at <https://authors.curseforge.com/#/settings/api-tokens>.

## License

MIT, see [LICENSE](LICENSE).
