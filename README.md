# Mein Spielraum · iPhone / SideStore

Native SwiftUI-App für iPhone 12 und andere iPhones mit iOS 17 oder neuer. Dunkles Design mit mintgrünen Akzenten. Keine Anmeldung, keine Bankanbindung, keine Serverübertragung deiner Haushaltsdaten.

**Stand:** Version 0.2.2 wurde am 19.10.2026 erfolgreich auf GitHub gebaut und veröffentlicht. 15 Swift-Tests und 3 Python-Tests bestanden. Ein Test auf einem echten iPhone steht noch aus.

**Jetzt installieren:** [IPA herunterladen](https://github.com/redshoxx/Mein-Spielraum/releases/latest/download/Mein-Spielraum.ipa) · [SideStore-Source](https://github.com/redshoxx/Mein-Spielraum/releases/latest/download/source.json) · [Erfolgreicher Build](https://github.com/redshoxx/Mein-Spielraum/actions/runs/39264624579)

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

Die aktuellen Assets wurden im Release v0.2.2 veröffentlicht. Der Workflow verwendet dynamisch den tatsächlichen Repository-Namen; bei einem Fork die Installationslinks entsprechend anpassen.

## Neue Versionen

Jeder Push auf `main` erstellt eine neue Version `0.2.<GitHub-Laufnummer>`. Für eine neue Versionsserie `VERSION` ändern, z.B. auf `0.3`. Der erfolgreiche Release aktualisiert die Source unter derselben URL. Die Versionsnummer wird aus demselben Wert in die IPA und in die Source geschrieben; ihre Übereinstimmung wird geprüft.

SideStore erkennt neue Versionen über die Source und bietet sie zum Aktualisieren an. Eine unbeaufsichtigte automatische Installation wird nicht zugesagt. Signierung erneuern/„Refresh“ und neue App-Version installieren sind unterschiedliche Vorgänge. Vor Updates ein Backup exportieren. App über die bestehende Installation aktualisieren, nicht deinstallieren. Bundle-ID `at.redshoxx.meinspielraum` und verwendetes Signierkonto beibehalten.

## Einnahmen, Fixkosten und Budget

Über das **Zahnrad oben rechts in der Übersicht** öffnest du den eigenen Bereich **Haushalt**. Dort kannst du mehrere monatliche Einnahmen sowie monatliche, vierteljährliche oder jährliche Fixkosten erfassen. Jeder Posten hat einen Namen, einen Betrag je Zahlung und eine nächste Fälligkeit. Fixkosten können zusätzlich ein optionales Datum **Letzte Zahlung spätestens** erhalten. Reguläre Termine bis einschließlich dieses Datums zählen; danach werden keine neuen Fälligkeiten oder Reserven berechnet. Eine schon fällige, aber unbezahlte letzte Zahlung bleibt offen. Ohne Enddatum läuft der Posten unbegrenzt weiter. Über das Menü am Posten bearbeiten oder entfernen. Haushalt ist kein unterer Tab mehr; über den Zurück-Pfeil geht es wieder zur Übersicht.

- Die **monatliche Planung** zeigt Einnahmen, auf Monatsbeträge umgerechnete Fixkosten und den geplanten Rest. Vierteljährliche Beträge werden durch 3, jährliche durch 12 geteilt, bei Bruchteilen eines Cents aufgerundet. Variable Ausgaben und die zusätzliche pauschale Reserve sind hier nicht enthalten.
- **Frei verfügbar = tatsächlicher Kontostand − offene Fixkosten bis Monatsende inklusive überfälliger Termine − zusätzliche Fixkostenreserve − Spartöpfe.**
- Zukünftige Einnahmen sind Planwerte. Sobald eine Zahlung fällig und eingegangen ist, **Als erhalten buchen** wählen. Fällige Fixkosten mit **Als bezahlt buchen** erfassen. Das aktualisiert Kontostand und Folgetermin einmal. Bereits im manuell eingetragenen Kontostand enthaltene Zahlungen nicht nochmals buchen.
- Fixkostenbuchungen reduzieren gleichzeitig die offene Reserve und den Kontostand; sie werden nicht zusätzlich dem variablen Wochenbudget zugerechnet. Nicht nochmals als normale Ausgabe erfassen.
- Folgetermine werden vom ursprünglichen Datum aus berechnet: 31. Jänner → 28./29. Februar → 31. März; vierteljährlich in 3-Monats-Schritten, jährlich in 12-Monats-Schritten. Jeder noch offene Termin wird einzeln bestätigt.
- Die letzte Buchung je unverändertem Posten kann im Buchungsverlauf rückgängig gemacht werden. Änderungen an einem Posten gelten ab dem gewählten nächsten Termin und erhalten frühere Buchungen. Nach Bearbeiten/Entfernen lassen sich alte Buchungen dieses Postens nicht über die Terminliste rückgängig machen; der Kontostand ist weiterhin unter Budget bearbeiten korrigierbar.
- Vorhandene Daten aus 0.1.1 und alte JSON-Backups werden übernommen. Die bisherige Fixkostenreserve bleibt als **zusätzliche Reserve** erhalten. Wenn neue Einzelposten schon darin enthalten waren, den Pauschalbetrag entsprechend reduzieren, um doppelte Reservierung zu vermeiden.
- Wochenbudget: eingestelltes Limit minus variable Ausgaben der aktuellen ISO-Woche, höchstens das frei verfügbare Geld. Neue Woche setzt nur den Wochenverbrauch zurück; Kontostand und Historie bleiben erhalten.
- Alle Beträge werden in ganzen Cent gerechnet. Geld für einen Spartopf reservieren verändert den Kontostand nicht.
- Einträge werden nach jeder erfolgreichen Änderung atomar in einer geschützten Datei im App-Speicher gespeichert. Die vorhandene Datei bleibt bei Ladefehlern unverändert. Dateiname und Bundle-ID bleiben beim Update gleich.
- Unter **Haushalt → Backup erstellen** als JSON exportieren. Wiederherstellung verlangt eine Bestätigung und prüft das Datenformat. Backups enthalten private Haushaltsdaten; bewahre sie privat auf. Beim Löschen der App gehen lokale Daten verloren. Neue Backups mit Datenformat 2 sind nicht für alte App-Versionen bestimmt.

## Entwicklung und Prüfungen

Auf macOS mit Xcode und Homebrew:

    swift test
    python3 scripts/test_source.py
    brew install xcodegen
    xcodegen generate
    open MeinSpielraum.xcodeproj

Für den Simulator den generierten Scheme `MeinSpielraum` wählen. Für einen signierten Direktstart auf einem eigenen iPhone in Xcode ein eigenes Team konfigurieren; für den GitHub-/SideStore-Weg ist das nicht nötig.

Vorbereitet sind Tests für Cent-Eingaben, Reservieren ohne Doppelabzug, Freigeben, Ausgabe rückgängig machen, JSON-Roundtrip und Wochenwechsel. 15 Swift-Tests, drei Python-Tests, der Xcode-Gerätebuild und die IPA-Metadatenprüfung liefen für Version 0.2.2 erfolgreich durch. Die Installation auf einem echten iPhone ist noch nicht geprüft.

## Verwendete Dokumentation

- SideStore-Quellen: https://docs.sidestore.io/docs/advanced/app-sources
- Source-Format: https://sidestore.io/sidestore-source-types/interfaces/Source.html
- App-/Versionsformat: https://sidestore.io/sidestore-source-types/interfaces/App.html
- GitHub-Runner: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- XcodeGen: https://github.com/yonaskolb/XcodeGen

App-Icon: individuell generiert; als 1024×1024-RGB-PNG in den Asset-Katalog eingebunden.
