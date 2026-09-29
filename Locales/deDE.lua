if GetLocale() ~= "deDE" then return end

local _, ns = ...
local L = ns.L

L["LOADED"] = "Version %s geladen. Befehle mit /voidalert help."
L["UNKNOWN_COMMAND"] = "Unbekannter Befehl. Befehle mit /voidalert help."
L["ON"] = "an"
L["OFF"] = "aus"

L["ALERT_meta"] = "Leerenmetamorphose"
L["ALERT_star"] = "Kollabierender Stern"

L["HELP_HEADER"] = "Befehle:"
L["HELP_HELP"] = "/voidalert help - Befehle auflisten"
L["HELP_STATUS"] = "/voidalert status - zeigt, ob VoidAlert aktiv ist, und die Einstellungen"
L["HELP_TEST"] = "/voidalert test [meta|star] - beide Alarme (oder einen) abspielen"
L["HELP_SOUNDS"] = "/voidalert sounds - alle verfügbaren Sounds mit Nummer auflisten"
L["HELP_SOUND"] = "/voidalert sound meta|star <Nummer>|default - Sound aus der Liste wählen"
L["HELP_TOGGLE"] = "/voidalert toggle meta|star - Alarm an- oder ausschalten"
L["HELP_CHANNEL"] = "/voidalert channel master|sfx|dialog|music|ambience - Soundkanal"
L["HELP_COMBAT"] = "/voidalert combat on|off - Alarme nur im Kampf abspielen"
L["HELP_DEBUG"] = "/voidalert debug on|off|clear|status - Debug-Log"

L["STATUS_HEADER"] = "Version %s"
L["STATUS_ACTIVE"] = "aktiv"
L["STATUS_INACTIVE"] = "inaktiv (nur für Dämonenjäger Verschlinger)"
L["STATUS_STATE"] = "%s - Spezialisierung %s (%s), Leerenmetamorphose bekannt: %s"
L["STATUS_ALERT"] = "%s: %s, Sound: %s"
L["STATUS_OPTIONS"] = "Kanal: %s, nur im Kampf: %s, Debugmodus: %s"

L["TEST_PLAYING"] = "Test: %s - %s"
L["SOUNDS_HEADER"] = "Verfügbare Sounds:"
L["SOUNDS_CUSTOM_NOTE"] = "Eigene Sounds: sound1.ogg bis sound5.ogg nach %s legen, danach /reload."
L["SOUND_UNKNOWN"] = "Kein Sound mit dieser Nummer. Liste mit /voidalert sounds."
L["SOUND_SET"] = "%s: Sound %s gewählt."
L["ALERT_TOGGLED"] = "%s: %s."
L["CHANNEL_SET"] = "Soundkanal: %s."
L["COMBAT_SET"] = "Nur im Kampf: %s."

L["SOUND_META_EN"] = "VoidAlert: Metamorphose (Englisch)"
L["SOUND_META_DE"] = "VoidAlert: Metamorphose (Deutsch)"
L["SOUND_STAR_EN"] = "VoidAlert: Kollabierender Stern (Englisch)"
L["SOUND_STAR_DE"] = "VoidAlert: Kollabierender Stern (Deutsch)"
L["SOUND_CUSTOM"] = "Eigener Sound: sound%d.ogg"
L["SOUND_KIT"] = "WoW: %s"
L["SOUND_LSM"] = "LSM: %s"
L["KIT_RAID_WARNING"] = "Schlachtzugswarnung"
L["KIT_READY_CHECK"] = "Bereitschaftscheck"
L["KIT_ALARM_CLOCK_WARNING_2"] = "Wecker 2"
L["KIT_ALARM_CLOCK_WARNING_3"] = "Wecker 3"
L["KIT_RAID_BOSS_EMOTE_WARNING"] = "Boss-Emote"
L["KIT_PVP_THROUGH_QUEUE"] = "PvP-Warteschlange bereit"

L["CUSTOM_MISSING"] = "%s konnte nicht abgespielt werden. Datei nach %s legen und /reload eingeben. Außerdem prüfen, ob der Soundkanal stummgeschaltet ist."
L["SOUND_FAILED"] = "%s konnte nicht abgespielt werden. Prüfen, ob der Soundkanal stummgeschaltet ist."

L["DEBUG_ON"] = "Debugmodus an. Das Log wird bei /reload oder Logout gespeichert."
L["DEBUG_OFF"] = "Debugmodus aus."
L["DEBUG_CLEARED"] = "Debug-Log geleert."
L["DEBUG_STATUS"] = "Debugmodus: %s, %d Einträge im Log."
