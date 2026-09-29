# VoidAlert – Spezifikation v1.0

Stand: 29.09.2026 · WoW Retail 12.1.0 (Interface `120100`)

## 1. Ziel

VoidAlert spielt für Dämonenjäger in der Spezialisierung **Verschlinger (Devourer)** einen Sound, sobald

- **A) Leerenmetamorphose** (Void Metamorphosis) einsetzbar ist, also nach 50 verzehrten Seelenfragmenten
- **B) Kollabierender Stern** (Collapsing Star) einsetzbar ist, also in der Metamorphose mit 30 Seelenfragmenten

Nur Sound, keine Anzeige auf dem Bildschirm.

## 2. Erkennung (im Spiel getestet)

Grundlage ist das Aufleucht-Ereignis `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`. Die Spell-ID im Payload ist im Kampf **nicht geheim**.

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
   - `meta_de.ogg`, `meta_en.ogg`, `star_de.ogg`, `star_en.ogg`
   - Pfad: `Interface\AddOns\VoidAlert\sounds\<datei>`
2. **Eigene Sounds** im separaten Ordner `Interface\AddOns\VoidAlert_Sounds\` (bleibt bei Updates erhalten):
   - feste Einträge `sound1.ogg` bis `sound5.ogg`
   - Im Menü mit Hinweistext, wo die Dateien hingehören und dass nach dem Hinzufügen ein `/reload` nötig ist
   - Fehlt eine Datei, liefert `PlaySoundFile` `false`: dann im Chat einmalig darauf hinweisen und ins Debug-Log schreiben
3. **LibSharedMedia-3.0:** alle registrierten Sounds (Typ `sound`). Die vier mitgelieferten Sounds zusätzlich bei LSM registrieren (Namen z. B. „VoidAlert: Metamorphosis (EN)“), damit andere Addons sie nutzen können.
4. **Einige WoW-Sounds** über `SOUNDKIT` (z. B. `RAID_WARNING`, `ALARM_CLOCK_WARNING_3`, `READY_CHECK`), Werte vorher prüfen

Abspielen: `PlaySoundFile(pfad, kanal)` für Dateien, `PlaySound(soundkit, kanal)` für SOUNDKIT, alles in `pcall`.

### 4.2 Standard

- Deutscher Client (`GetLocale() == "deDE"`): `meta_de.ogg` / `star_de.ogg`
- Sonst: `meta_en.ogg` / `star_en.ogg`

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
