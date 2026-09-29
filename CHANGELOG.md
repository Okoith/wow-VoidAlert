# Changelog

## 1.0.0-alpha.1

First test build.

- **Alerts:** plays a sound when Void Metamorphosis (spell 1217605) or Collapsing Star (spell 1221150) starts to glow. Only when the glow appears, with a 2-second block per alert.
- **Devourer only:** active when your character knows Void Metamorphosis or is in the Devourer specialization; silent for all other classes and specializations. Checked again on login, specialization change and spell changes.
- **Sounds:** bundled English and German voice alerts (default follows the client language), up to five own sounds in `Interface\AddOns\VoidAlert_Sounds\`, all LibSharedMedia sounds and a few WoW sounds. The bundled sounds are registered with LibSharedMedia.
- **Settings** per character: alert on/off, sound, sound channel (Master by default), only in combat (on by default).
- **Chat commands** `/voidalert` (the settings menu follows in the next version).
- **Debug mode** (off by default) that writes a log to the SavedVariables.
- **Languages:** English and German.
