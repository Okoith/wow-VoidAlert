# Changelog

## 1.0.0-beta.2

- **Profiles page removed.** VoidAlert is made for one character with one specialization. Settings are still stored per character automatically, and your current settings are kept.
- **New option "Chat messages"** under *General* (off by default): shows the "loaded" message on login and a message when testing. Replies to `/voidalert` commands and error hints are always shown.
- The library AceDBOptions-3.0 is no longer included.

## 1.0.0-beta.1

Release candidate.

- **Settings menu** under *Settings > AddOns > VoidAlert* or with `/voidalert`: per alert on/off, sound and *Test* button; sound channel, only in combat and *Test both*; note on custom sounds; debug mode and *Clear log*. A note at the top shows whether VoidAlert is active on this character.
- **Profiles** as their own entry under VoidAlert: settings per character, copy from another character, reset.
- A chosen sound that is no longer available is shown as *(missing)* in the menu and is not overwritten; the default sound is played instead.
- Changes made with chat commands are shown in the open settings window right away. `/voidalert` without arguments now opens the settings, `/voidalert help` lists the commands.
- CurseForge project ID added, automatic uploads to CurseForge.
- Custom sounds: new files need a complete restart of WoW, `/reload` does not detect them. The hints in the menu and chat say so.

## 1.0.0-alpha.1

First test build.

- **Alerts:** plays a sound when Void Metamorphosis (spell 1217605) or Collapsing Star (spell 1221150) starts to glow. Only when the glow appears, with a 2-second block per alert.
- **Devourer only:** active when your character knows Void Metamorphosis or is in the Devourer specialization; silent for all other classes and specializations. Checked again on login, specialization change and spell changes.
- **Sounds:** bundled English and German voice alerts (default follows the client language), up to five own sounds in `Interface\AddOns\VoidAlert_Sounds\`, all LibSharedMedia sounds and a few WoW sounds. The bundled sounds are registered with LibSharedMedia.
- **Settings** per character: alert on/off, sound, sound channel (Master by default), only in combat (on by default).
- **Chat commands** `/voidalert` (the settings menu follows in the next version).
- **Debug mode** (off by default) that writes a log to the SavedVariables.
- **Languages:** English and German.
