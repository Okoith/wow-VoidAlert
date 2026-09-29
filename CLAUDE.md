# CLAUDE.md – Arbeitsanweisung für VoidAlert

Du baust das WoW-Addon **VoidAlert** (Retail 12.1.0, Interface `120100`). Die fachliche Beschreibung steht in `SPEC.md`. Lies sie vollständig, bevor du Code schreibst.

## Rollen

- **Dominique:** testet im Spiel, mergt Pull Requests, erstellt Releases (Tags).
- **Koordinator** (Claude in Cowork): prüft Code, Builds und Debug-Logs, schreibt Folgeaufgaben.
- **Du:** setzt um, ein Pull Request pro Meilenstein. **Keine Tags pushen.**

## Referenzprojekte

Vom selben Autor, fertig und im Spiel getestet. Übernimm die bewährten Lösungen:

- https://github.com/Okoith/wow-DotRange (am nächsten dran: Core, Options, Debug, Locales, Spec-Erkennung)
- https://github.com/Okoith/wow-ownDPS (LibSharedMedia-Auswahl im Menü, `.pkgmeta`, Workflow)

`docs/reference/VoidAlert_Test.lua` ist das Testaddon, mit dem die Erkennung ermittelt wurde (siehe SPEC Abschnitt 2).

## Harte Regeln

1. **Nur** `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` zur Erkennung. Kein `IsSpellUsable`, keine Auren, keine Ressourcen (im Test unzuverlässig oder gesperrt).
2. Werte, die geheim sein können, vor Vergleichen mit `issecretvalue` prüfen.
3. Alle Aufrufe von Spiel-APIs und `PlaySoundFile`/`PlaySound` in `pcall`.
4. Keine geheimen Werte in SavedVariables.
5. Die vorhandenen Dateien in `sounds/` nicht umbenennen, verschieben oder neu kodieren.
6. Nichts raten: Unklare APIs defensiv absichern und im Debugmodus loggen.

## Meilensteine

1. **Kern:** Erkennung beider Alarme, Sounds (mitgelieferte, eigener Ordner, LSM, SOUNDKIT), Standard je nach Client-Sprache, Aktivierung nur für den Verschlinger, Debugmodus, Locales, `.pkgmeta`, Release-Workflow, README, CHANGELOG. Version `1.0.0-alpha.1`.
2. **Menü:** AceConfig mit allen Optionen aus SPEC Abschnitt 5, Test-Buttons, Profile. Danach Release-Kandidat `1.0.0-beta.1`.

Nach jedem Meilenstein: Pull Request mit kurzer Testanleitung für Dominique.
