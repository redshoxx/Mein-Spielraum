# Prüfstand · Version 0.2.2

GitHub-Actions-Lauf: https://github.com/redshoxx/Mein-Spielraum/actions/runs/39264624579
Quellcommit: e1c8c34bc7edd66a83a71f2b3b251c152393a538
Release: https://github.com/redshoxx/Mein-Spielraum/releases/tag/v0.2.2
Datum: 19.10.2026

- 15 Swift-Rechenkern-Tests bestanden: bisherige 5 Budgettests und 10 Tests für Monatsende, Vierteljahr, Schaltjahr, zukünftige Einnahmen, Doppelbuchungsschutz, Fixkosten ohne Doppelabzug, überfällige Termine, Datenmigration und Bearbeiten mit Historie.
- Python Source-Generator: 3 Tests bestanden.
- Xcode-Gerätebuild erfolgreich; IPA-Metadaten geprüft.
- IPA (1.997.376 Bytes), SideStore-Source, Icon und Prüfsumme veröffentlicht.
- Native Bildschirm-/Bedienprüfung auf echtem iPhone bleibt ausstehend.

## Datenübernahme
Schema 1 wird mit unveränderten Kontoständen, Reserven, Spartöpfen und Ausgaben in Schema 2 eingelesen. Neue Listen werden nur bei Schema 1 als leer ergänzt. Bei fehlenden Listen in Schema 2 wird ein Fehler ausgelöst. Speicherdatei und Bundle-ID werden beibehalten.
