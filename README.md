# Mein Spielraum · iPhone / SideStore

Native SwiftUI-App für iPhone 12 und andere iPhones mit iOS 17 oder neuer. Dunkles Design mit mintgrünen Akzenten. Keine Anmeldung, keine Bankanbindung, keine Serverübertragung deiner Haushaltsdaten.

**Stand:** Version 0.1.1 wurde am 19.10.2026 erfolgreich auf GitHub gebaut und veröffentlicht. Fünf Swift-Rechenkern-Tests und drei Python-Source-Tests bestanden. Ein Test auf einem echten iPhone steht noch aus.

**Jetzt installieren:** [IPA herunterladen](https://github.com/redshoxx/Mein-Spielraum/releases/latest/download/Mein-Spielraum.ipa) · [SideStore-Source](https://github.com/redshoxx/Mein-Spielraum/releases/latest/download/source.json) · [Erfolgreicher Build](https://github.com/redshoxx/Mein-Spielraum/actions/runs/39246691716)

## Einmalige GitHub-Einrichtung

1. Öffentliches Repository `redshoxx/Mein-Spielraum` anlegen: https://github.com/new?name=Mein-Spielraum&visibility=public
2. Die Inhalte dieses Projektordners direkt in den Repository-Stamm hochladen oder per Git pushen. `project.yml`, `Package.swift`, `.github`, `Core`, `ios`, `Tests` und `scripts` müssen auf der obersten Ebene liegen. Nicht die ZIP als einzelne Datei hochladen.
3. Hauptzweig `main` verwenden. GitHub Actions muss für das Repository zugelassen sein.
4. Der Workflow **iPhone Build & SideStore** startet beim Push auf `main`. Er testet den Rechenkern, baut die iPhone-App auf einem macOS-Runner, erstellt die IPA und veröffentlicht einen Release samt Source. Keine Apple-Zugangsdaten oder Signierzertifikate im Repository erforderlich; SideStore signiert bei der Installation.
5. Unter **Actions** muss der Ablauf grün sein. Bei einem roten Lauf die Logs prüfen. Erst dann ist die IPA tatsächlich gebaut.

## Installation auf dem iPhone

Nach dem ersten erfolgreichen Release:

- Releases: `https://github.com/redshoxx/Mein-Spielraum/releases/latest`
- IPA: `https://github.com/redshoxx/Mein-Spielraum/releases/latest/download/Mein-Spielraum.ipa`
- SideStore-Source: `https://github.com/redshoxx/Mein-Spielraum/releases/latest/download/source.json`

In SideStore im Bereich **Sources/Quellen** die Source-URL hinzufügen, dann „Mein Spielraum“ installieren. Alternativ die IPA in Safari laden und in SideStore importieren. SideStore muss bereits korrekt auf dem iPhone eingerichtet sein; seine Signierungs-, Geräte- und Netzwerkanforderungen gelten weiterhin.

Die Assets wurden im Release v0.1.1 veröffentlicht. Der Workflow verwendet dynamisch den tatsächlichen Repository-Namen; bei einem Fork die Installationslinks entsprechend anpassen.

## Neue Versionen

Jeder Push auf `main` erstellt eine neue Version `0.1.<GitHub-Laufnummer>`. Für eine neue Versionsserie `VERSION` ändern, z.B. auf `0.2`. Der erfolgreiche Release aktualisiert die Source unter derselben URL. Die Versionsnummer wird aus demselben Wert in die IPA und in die Source geschrieben; ihre Übereinstimmung wird geprüft.

SideStore erkennt neue Versionen über die Source und bietet sie zum Aktualisieren an. Eine unbeaufsichtigte automatische Installation wird nicht zugesagt. Signierung erneuern/„Refresh“ und neue App-Version installieren sind unterschiedliche Vorgänge. Vor Updates ein Backup exportieren. App über die bestehende Installation aktualisieren, nicht deinstallieren. Bundle-ID `at.redshoxx.meinspielraum` und verwendetes Signierkonto beibehalten.

## Budget und Speicherung

- **Kontostand − kommende Fixkosten − Summe der Spartöpfe = frei verfügbar.** Spargeld ist Teil des eingetragenen Kontostands. Reservieren verändert den Kontostand nicht.
- Wochenbudget: eingestelltes Limit abzüglich tatsächlicher Ausgaben der aktuellen ISO-Woche, höchstens das frei verfügbare Geld. Neue Woche setzt nur den Wochenverbrauch zurück; Kontostand und Historie bleiben erhalten.
- Fixkosten sind eine aktuelle Reserve, keine automatischen wiederkehrenden Buchungen. Nach einer Abbuchung Kontostand und verbleibende Reserve abgleichen. Einnahmen über den aktuellen Kontostand ergänzen.
- Geldbeträge werden in ganzen Cent gerechnet.
- Einträge werden nach jeder erfolgreichen Änderung atomar in einer geschützten Datei im App-Speicher gespeichert. Bei Ladefehlern wird die bestehende Datei nicht überschrieben.
- Unter **Haushalt → Backup erstellen** als JSON exportieren. Wiederherstellung verlangt eine Bestätigung und prüft das Datenformat. Backups enthalten deine Haushaltsdaten und sind nicht separat verschlüsselt; bewahre sie privat auf. Beim Löschen der App gehen lokale Daten verloren.
- Start mit eigenen Zahlen oder mit Beispieldaten. Beispiel: Kontostand 2.180 €, Fixkosten 370 €, Spartöpfe 1.230 €, verfügbar 580 €. Diese Rechnung korrigiert die uneinheitliche Sparreserve des ersten Designbilds.

## Entwicklung und Prüfungen

Auf macOS mit Xcode und Homebrew:

    swift test
    python3 scripts/test_source.py
    brew install xcodegen
    xcodegen generate
    open MeinSpielraum.xcodeproj

Für den Simulator den generierten Scheme `MeinSpielraum` wählen. Für einen signierten Direktstart auf einem eigenen iPhone in Xcode ein eigenes Team konfigurieren; für den GitHub-/SideStore-Weg ist das nicht nötig.

Vorbereitet sind Tests für Cent-Eingaben, Reservieren ohne Doppelabzug, Freigeben, Ausgabe rückgängig machen, JSON-Roundtrip und Wochenwechsel. Fünf Swift-Tests, drei Python-Tests, der Xcode-Gerätebuild und die IPA-Metadatenprüfung liefen im ersten GitHub-Actions-Workflow erfolgreich durch. Die Installation auf einem echten iPhone ist noch nicht geprüft.

## Verwendete Dokumentation

- SideStore-Quellen: https://docs.sidestore.io/docs/advanced/app-sources
- Source-Format: https://sidestore.io/sidestore-source-types/interfaces/Source.html
- App-/Versionsformat: https://sidestore.io/sidestore-source-types/interfaces/App.html
- GitHub-Runner: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- XcodeGen: https://github.com/yonaskolb/XcodeGen

App-Icon: individuell generiert; als 1024×1024-RGB-PNG in den Asset-Katalog eingebunden.
