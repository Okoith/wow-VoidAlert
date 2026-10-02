# VoidAlert – Spezifikation v1.1

Stand: 02.10.2026 · WoW Retail 12.1.0 (Interface `120100`)

## 1. Ziel

VoidAlert spielt für Dämonenjäger in der Spezialisierung **Verschlinger (Devourer)** einen Sound, sobald

- **A) Leerenmetamorphose** (Void Metamorphosis) einsetzbar ist, also nach 50 verzehrten Seelenfragmenten
- **B) Kollabierender Stern** (Collapsing Star) einsetzbar ist, also in der Metamorphose mit 30 Seelenfragmenten
- **C) Seelenimmolation** (Soul Immolation) wieder bereit ist (seit 1.1.0, Erkennung in Abschnitt 9)

Nur Sound, keine Anzeige auf dem Bildschirm.

## 2. Erkennung (im Spiel getestet)

Für A und B ist die Grundlage das Aufleucht-Ereignis `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`. Die Spell-ID im Payload ist im Kampf **nicht geheim**.

| Alarm | Spell-ID im Ereignis | Hinweis |
|---|---|---|
| A) Leerenmetamorphose | **1217605** | per `C_Spell.GetSpellInfo("Leerenmetamorphose")` bestätigt |
| B) Kollabierender Stern | **1221150** | Variante innerhalb der Metamorphose, per `GetSpellInfo(1221150).name` bestätigt. Die Basis-ID 1221167 leuchtet **nie** auf. |

Testergebnisse aus `docs/reference/VoidAlert_Test.lua` (1 Kampf, ca. 100 s, 216 Messungen):

| Weg | Ergebnis | Verwenden? |
|---|---|---|
| `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` | Spell-ID lesbar, Metamorphose 3× korrekt erkannt | **ja, ausschließlich** |
| `C_Spell.IsSpellUsable` | lesbar, aber 11 Fehlalarme (Knopf wird in der Metamorphose ersetzt) | **nein** |
| `C_UnitAuras.GetAuraDataByIndex` | Fehler: „Auras cannot be accessed when secret while tainted“ | nein |
| `C_Spell.GetSpellCastCount` | geheim | nein |
| `UnitPower` (Zorn) | geheim | nein |

Regeln:
- Sound nur bei `GLOW_SHOW`, nicht bei `GLOW_HIDE`
- Pro Alarm eine Sperre von 2 s gegen Doppelauslösung
- `issecretvalue` auf die Spell-ID prüfen, bevor verglichen wird (defensiv, auch wenn sie im Test lesbar war)

## 3. Aktiv nur für den Verschlinger

- Aktiv, wenn der Charakter Leerenmetamorphose kennt (`C_SpellBook.IsSpellKnown(1217605)` o. ä., in der aktuellen API-Doku prüfen) **oder** die Spec-ID dem Verschlinger entspricht. Die Spec-ID zur Laufzeit per `GetSpecializationInfo` ermitteln und ins Debug-Log schreiben, nicht raten.
- Achtung: Beim Test war `GetSpecialization()` bei `ADDON_LOADED` noch 0. Die Prüfung daher bei `PLAYER_LOGIN`, `PLAYER_SPECIALIZATION_CHANGED` und `SPELLS_CHANGED` durchführen.
- Andere Klassen und Specs: Addon still, im Menü ein Hinweis „Nur für Dämonenjäger (Verschlinger)“.

## 4. Sounds

### 4.1 Soundquellen (alle erscheinen in einer gemeinsamen Auswahlliste)

1. **Mitgelieferte Sounds** im Addon-Ordner `sounds/`:
   - `meta_de.ogg`, `meta_en.ogg`, `star_de.ogg`, `star_en.ogg`, `immo_de.ogg`, `immo_en.ogg`
   - Pfad: `Interface\AddOns\VoidAlert\sounds\<datei>`
2. **Eigene Sounds** im separaten Ordner `Interface\AddOns\VoidAlert_Sounds\` (bleibt bei Updates erhalten):
   - feste Einträge `sound1.ogg` bis `sound5.ogg`
   - Im Menü mit Hinweistext, wo die Dateien hingehören und dass nach dem Hinzufügen ein `/reload` nötig ist
   - Fehlt eine Datei, liefert `PlaySoundFile` `false`: dann im Chat einmalig darauf hinweisen und ins Debug-Log schreiben
3. **LibSharedMedia-3.0:** alle registrierten Sounds (Typ `sound`). Die mitgelieferten Sounds zusätzlich bei LSM registrieren (Namen z. B. „VoidAlert: Metamorphosis (EN)“, „VoidAlert: Soul Immolation (DE)“), damit andere Addons sie nutzen können.
4. **Einige WoW-Sounds** über `SOUNDKIT` (z. B. `RAID_WARNING`, `ALARM_CLOCK_WARNING_3`, `READY_CHECK`), Werte vorher prüfen

Abspielen: `PlaySoundFile(pfad, kanal)` für Dateien, `PlaySound(soundkit, kanal)` für SOUNDKIT, alles in `pcall`.

### 4.2 Standard

- Deutscher Client (`GetLocale() == "deDE"`): `meta_de.ogg` / `star_de.ogg` / `immo_de.ogg`
- Sonst: `meta_en.ogg` / `star_en.ogg` / `immo_en.ogg`

## 5. Einstellungen (AceConfig, wie OwnDPS/DotRange)

- Pro Alarm: **an/aus**, **Sound** (Auswahlliste aus 4.1), Button **„Testen“**
- **Kanal:** Master (Standard), SFX, Dialog, Music, Ambience
- **Nur im Kampf** (Standard: an)
- **Debugmodus** an/aus
- Eintrag unter *Einstellungen → AddOns → VoidAlert*, `/voidalert` öffnet das Menü, `/voidalert test` spielt beide Alarme
- **Profile** pro Charakter mit „Kopieren von“ (AceDB + AceDBOptions)
- Sprachen: enUS (Standard), deDE

## 6. Debugmodus

Wie DotRange: Ringpuffer in `VoidAlertDebugLog`, max. 5000 Einträge, Secret Values nur als `"<SECRET>"`. Inhalt: Version, Build, Klasse, Spec-ID/Name, ob Leerenmetamorphose bekannt ist, jedes `GLOW_SHOW`/`GLOW_HIDE` mit Spell-ID, jeder ausgelöste Alarm mit Soundquelle und Rückgabe von `PlaySoundFile`.

## 7. Technik

- Kein Frame auf dem Bildschirm, kein Bearbeitungsmodus nötig
- Bibliotheken per `.pkgmeta`: LibStub, CallbackHandler-1.0, AceDB-3.0, AceDBOptions-3.0, AceGUI-3.0, AceConfig-3.0, LibSharedMedia-3.0 (Quellen wie OwnDPS)
- TOC: `## Interface: 120100`, `## Version: @project-version@`, `## SavedVariables: VoidAlertDB, VoidAlertDebugLog`
- `sounds/` gehört ins Paket, `docs/` nicht

## 8. Veröffentlichung

Wie OwnDPS/DotRange: MIT, CHANGELOG und README auf Englisch, Release-Workflow bei Tag `v*`, CurseForge-ID später.

## 9. Seelenimmolation (seit 1.1.0)

Alarm C „Seelenimmolation bereit“. Anders als A und B nicht nur über das Leuchten, sondern über Abklingzeit und Aufladungen. Ermittelt mit dem Testaddon `docs/reference/ImmoTest.lua` (Verschlinger, Spec-ID 1480, zwei Logs).

### 9.1 Getestete Fakten

| Was | Ergebnis |
|---|---|
| Seelenimmolation | Spell-ID **1241937**, `C_Spell.GetOverrideSpell` liefert dieselbe ID |
| `C_Spell.GetSpellCharges(1241937).maxCharges` | **im Kampf lesbar**: 1 ohne, 2 mit Talent Gemäßigte Seele (Tempered Soul) |
| `currentCharges`, `cooldownStartTime`, `cooldownDuration` | im Kampf **geheim**, außerhalb lesbar |
| `cooldownDuration` außerhalb des Kampfes | **60** bei 1 Aufladung, **30** bei 2 Aufladungen. Unabhängig von Tempo. |
| `C_Spell.GetSpellCooldown(1241937).isActive` / `isOnGCD` | im Kampf lesbar. `isActive == true` und `isOnGCD == false` bedeutet: **0 Aufladungen**. Bei 1 von 2 Aufladungen ist `isActive` false (nur während des GCD kurz true mit `isOnGCD == true`). |
| `UNIT_SPELLCAST_SUCCEEDED` für `player` | Spell-ID 1241937 im Kampf lesbar |
| Reset durch Spontane Immolation (Todesstoß) | `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` mit Spell-ID **1241937**, im Kampf lesbar, etwa zur selben Zeit wechselt `isActive` auf bereit |
| Gemäßigte Seele und Spontane Immolation | teilen sich einen Wahlknoten (Quelle: Method-Talentguide 12.1). Mit 2 Aufladungen gibt es also keinen Reset. |

Aufladungen laden nacheinander. Gemessen im Kampf (Zeitstempel `GetTime()`):

```
Cast bei 2/2 Aufladungen 1271024.51  ->  Aufladung zurück 1271054.51  (30,00 s)
Cast bei 2/2 Aufladungen 1259500.09  ->  Aufladung zurück 1259530.09  (30,00 s)
außerhalb: Cast 1259077.98 (2->1), Cast 1259079.51 (1->0) -> 1259107.99 (1), 1259137.99 (2)
```

### 9.2 Erkennung (`Immo.lua`, Modul `ns.Immo`)

`maxCharges` wird bei jedem Update gelesen. Geheim oder fehlend: letzter bekannter Wert, sonst Modus 1.

**Modus 1 (`maxCharges == 1`):**
- `ready = (isActive == false) or (isOnGCD == true)`; Wechsel von nicht bereit auf bereit → Alarm (`cdReady`).
- `GLOW_SHOW` mit Spell-ID 1241937 → Alarm (`resetGlow`). `Alerts:OnGlowShow` reicht das Leuchten an `ns.Immo` weiter, nicht über `BY_SPELL`.
- Endet die Abklingzeit während eines GCD, meldet das Spiel schon `isOnGCD == true`. Der Alarm kommt dann bis zu 0,5 s früher (gewollt).

**Modus 2 (`maxCharges >= 2`), eigener Zähler:**
- Zustand: `charges`, `rechargeStart` (`GetTime()`-Zeit oder nil), `rechargeDuration` (Standard 30).
- **Abgleich**, sobald `currentCharges`, `cooldownStartTime` und `cooldownDuration` lesbar sind (außerhalb des Kampfes), bei `SPELL_UPDATE_CHARGES`, `SPELL_UPDATE_COOLDOWN`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `SPELLS_CHANGED`, `TRAIT_CONFIG_UPDATED`, Spezialisierungswechsel und Login: `charges = currentCharges`, `rechargeDuration = cooldownDuration` (wenn > 0), `rechargeStart = cooldownStartTime`, wenn `charges < max` und Start > 0, sonst nil. Der Abgleich spielt keinen Sound.
- **Eigener Cast** (Werte geheim, also im Kampf): bei `charges == max` `rechargeStart = jetzt`, dann `charges = max(charges - 1, 0)`. Fehlt danach ein Startzeitpunkt, obwohl `charges < max`, gilt ebenfalls `jetzt`. Außerhalb des Kampfes wird beim Cast abgeglichen statt gezählt.
- **Timer** (`C_Timer.NewTimer`) auf `rechargeStart + rechargeDuration`, bei Änderung neu geplant. Abgelaufen: `charges + 1`, Alarm (`chargeTimer`); ist `charges < max`, `rechargeStart += rechargeDuration` und neu planen, sonst nil.
- **Korrektur über `isActive`:** `isActive == true` und `isOnGCD == false` → echte 0 Aufladungen, Zähler auf 0. Wechsel von `isActive` true auf false bei `charges == 0` → `charges = 1`, Alarm (`correct`) und `rechargeStart = jetzt`, wenn `charges < max`. Hat der Timer kurz vorher gespielt, verhindert die Sperre den zweiten Alarm.

**Gemeinsam:** Sperre 2 s für den Alarm `immo` über alle Auslöser. Alarm nur, wenn VoidAlert aktiv ist (Abschnitt 3), der Alarm an ist und „Nur im Kampf“ passt. Der Zustand wird außerhalb des Kampfes trotzdem mitgeführt. Nichts davon landet in den SavedVariables.

### 9.3 Debug-Einträge

`immoSync` (Modus, max, charges, rechargeStart, rechargeDuration, Quelle; nur bei Änderung), `immoCast`, `immoTimer`, `immoState` (isActive, isOnGCD; nur bei Änderung), `immoCorrect`, `immoGlow`, `alarmSkipped`. Secret Values nur als `"<SECRET>"`.
