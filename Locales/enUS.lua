local _, ns = ...

-- Basistabelle (enUS). Fehlende Schlüssel liefern den Schlüssel selbst,
-- damit nie ein Lua-Fehler durch einen fehlenden Text entsteht.
local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

L["LOADED"] = "Version %s loaded. Type /voidalert help for commands."
L["UNKNOWN_COMMAND"] = "Unknown command. Type /voidalert help for commands."
L["ON"] = "on"
L["OFF"] = "off"

L["ALERT_meta"] = "Void Metamorphosis"
L["ALERT_star"] = "Collapsing Star"

L["HELP_HEADER"] = "Commands:"
L["HELP_HELP"] = "/voidalert help - list the commands"
L["HELP_STATUS"] = "/voidalert status - show whether VoidAlert is active and the current settings"
L["HELP_TEST"] = "/voidalert test [meta|star] - play both alerts (or one)"
L["HELP_SOUNDS"] = "/voidalert sounds - list all available sounds with their numbers"
L["HELP_SOUND"] = "/voidalert sound meta|star <number>|default - choose a sound from the list"
L["HELP_TOGGLE"] = "/voidalert toggle meta|star - turn an alert on or off"
L["HELP_CHANNEL"] = "/voidalert channel master|sfx|dialog|music|ambience - sound channel"
L["HELP_COMBAT"] = "/voidalert combat on|off - only play alerts in combat"
L["HELP_DEBUG"] = "/voidalert debug on|off|clear|status - debug log"

L["STATUS_HEADER"] = "Version %s"
L["STATUS_ACTIVE"] = "active"
L["STATUS_INACTIVE"] = "inactive (Demon Hunter Devourer only)"
L["STATUS_STATE"] = "%s - specialization %s (%s), Void Metamorphosis known: %s"
L["STATUS_ALERT"] = "%s: %s, sound: %s"
L["STATUS_OPTIONS"] = "Channel: %s, only in combat: %s, debug mode: %s"

L["TEST_PLAYING"] = "Test: %s - %s"
L["SOUNDS_HEADER"] = "Available sounds:"
L["SOUNDS_CUSTOM_NOTE"] = "Custom sounds: put sound1.ogg to sound5.ogg in %s, then type /reload."
L["SOUND_UNKNOWN"] = "No sound with this number. Type /voidalert sounds for the list."
L["SOUND_SET"] = "%s: sound set to %s."
L["ALERT_TOGGLED"] = "%s: %s."
L["CHANNEL_SET"] = "Sound channel: %s."
L["COMBAT_SET"] = "Only in combat: %s."

-- Soundquellen (SPEC 4.1)
L["SOUND_META_EN"] = "VoidAlert: Metamorphosis (English)"
L["SOUND_META_DE"] = "VoidAlert: Metamorphosis (German)"
L["SOUND_STAR_EN"] = "VoidAlert: Collapsing Star (English)"
L["SOUND_STAR_DE"] = "VoidAlert: Collapsing Star (German)"
L["SOUND_CUSTOM"] = "Custom: sound%d.ogg"
L["SOUND_KIT"] = "WoW: %s"
L["SOUND_LSM"] = "LSM: %s"
L["KIT_RAID_WARNING"] = "Raid Warning"
L["KIT_READY_CHECK"] = "Ready Check"
L["KIT_ALARM_CLOCK_WARNING_2"] = "Alarm Clock 2"
L["KIT_ALARM_CLOCK_WARNING_3"] = "Alarm Clock 3"
L["KIT_RAID_BOSS_EMOTE_WARNING"] = "Raid Boss Emote"
L["KIT_PVP_THROUGH_QUEUE"] = "PvP Queue Ready"

L["CUSTOM_MISSING"] = "%s could not be played. Put the file in %s and type /reload. Also check that the sound channel is not muted."
L["SOUND_FAILED"] = "%s could not be played. Check that the sound channel is not muted."

L["DEBUG_ON"] = "Debug mode on. The log is saved on /reload or logout."
L["DEBUG_OFF"] = "Debug mode off."
L["DEBUG_CLEARED"] = "Debug log cleared."
L["DEBUG_STATUS"] = "Debug mode: %s, %d entries in the log."
