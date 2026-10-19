# Prüfstand · Einnahmen und wiederkehrende Fixkosten

Geplant: Versionsserie 0.2. GitHub-Build steht für diese Änderung noch aus.

## Tests
- Bisherige 5 Budgettests bleiben bestehen.
- 10 zusätzliche Swift-Tests für Monatsende, Vierteljahr, Schaltjahr, zukünftige Einnahmen, Doppelbuchungsschutz, Fixkosten ohne Doppelabzug, überfällige Termine, Datenmigration und Bearbeiten mit Historie.
- Python-Source-Generator: 3 Tests lokal bestanden.
- Neue Swift-Tests und Xcode-Gerätebuild laufen im GitHub-Workflow vor einer Veröffentlichung.
- Native Bildschirm-/Bedienprüfung auf echtem iPhone bleibt ausstehend.

## Datenübernahme
Schema 1 wird mit unveränderten Kontoständen, Reserven, Spartöpfen und Ausgaben in Schema 2 eingelesen. Neue Listen werden nur bei Schema 1 als leer ergänzt. Bei fehlenden Listen in Schema 2 wird ein Fehler ausgelöst. Speicherdatei und Bundle-ID werden beibehalten.
