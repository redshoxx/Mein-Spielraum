# Mein Spielraum · iPhone / SideStore

Native SwiftUI-App für iPhone 12 und andere iPhones mit iOS 17 oder neuer. Dunkles Design mit mintgrünen Akzenten. Keine Anmeldung, keine Bankanbindung, keine Serverübertragung deiner Haushaltsdaten.

**Stand:** Version 0.3.7 wurde am 19.10.2026 erfolgreich auf GitHub gebaut und veröffentlicht. 40 Swift-Tests und 3 Python-Tests bestanden. Ein Test auf einem echten iPhone steht noch aus.

**Jetzt installieren:** [IPA herunterladen](https://github.com/redshoxx/Mein-Spielraum/releases/latest/download/Mein-Spielraum.ipa) · [SideStore-Source](https://github.com/redshoxx/Mein-Spielraum/releases/latest/download/source.json) · [Erfolgreicher Build](https://github.com/redshoxx/Mein-Spielraum/actions/runs/39271037563)

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

Die aktuellen Assets wurden im Release v0.3.7 veröffentlicht. Der Workflow verwendet dynamisch den tatsächlichen Repository-Namen; bei einem Fork die Installationslinks entsprechend anpassen.

## Neue Versionen

Jeder Push auf `main` erstellt eine neue Version `0.3.<GitHub-Laufnummer>`. Für eine neue Versionsserie `VERSION` ändern, z.B. auf `0.4`. Der erfolgreiche Release aktualisiert die Source unter derselben URL. Die Versionsnummer wird aus demselben Wert in die IPA und in die Source geschrieben; ihre Übereinstimmung wird geprüft.

SideStore erkennt neue Versionen über die Source und bietet sie zum Aktualisieren an. Eine unbeaufsichtigte automatische Installation wird nicht zugesagt. Signierung erneuern/„Refresh“ und neue App-Version installieren sind unterschiedliche Vorgänge. Vor Updates ein Backup exportieren. App über die bestehende Installation aktualisieren, nicht deinstallieren. Bundle-ID `at.redshoxx.meinspielraum` und verwendetes Signierkonto beibehalten.

## Nächste Fixkosten auf der Übersicht

Auf der Startübersicht stehen die nächsten offenen Fixkosten nach Fälligkeit sortiert: Name, Betrag, genaues Datum und „Heute fällig“, „Morgen fällig“, „In X Tagen“ oder „X Tage überfällig“. Je Posten wird die nächste offene Zahlung angezeigt. Zunächst vier Einträge, weitere über **Alle anzeigen**. Nach einer Buchung erscheint der Folgetermin; abgeschlossene Posten entfallen. Offene Schlusszahlungen bleiben sichtbar. Bearbeiten und Buchen bleiben im Haushalt über das Zahnrad.

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
- Spartöpfe: Über den Stift Name und Sparziel bearbeiten. „Spartopf löschen“ erfordert eine Bestätigung und gibt die Reservierung frei, ohne den Kontostand zu ändern. Bei einem gelöschten Notfalltopf im Assistenten einen neuen auswählen. Frühere Ausgaben bleiben erhalten.
- Alle Beträge werden in ganzen Cent gerechnet. Geld für einen Spartopf reservieren verändert den Kontostand nicht.
- Einträge werden nach jeder erfolgreichen Änderung atomar in einer geschützten Datei im App-Speicher gespeichert. Die vorhandene Datei bleibt bei Ladefehlern unverändert. Dateiname und Bundle-ID bleiben beim Update gleich.
- Unter **Haushalt → Backup erstellen** als JSON exportieren. Wiederherstellung verlangt eine Bestätigung und prüft das Datenformat. Backups enthalten private Haushaltsdaten; bewahre sie privat auf. Beim Löschen der App gehen lokale Daten verloren. Neue Backups mit Datenformat 3 sind nicht für alte App-Versionen bestimmt.

## Lernender Budget-Assistent

Auf der **Übersicht → Lernender Budget-Assistent** öffnen und über das Regler-Symbol einrichten. Notwendigen Alltag pro Woche, Sicherheitspuffer, noch zusätzlich zu reservierendes Spargeld, nächsten Gehaltstag und einen vorhandenen Notfall-Spartopf selbst wählen. Danach Ausgaben im Assistenten unter **Lernen** markieren: notwendig, Wunsch oder Notfall. Ein Händler kann beim Erfassen optional angegeben werden. Markierungen sind korrigierbar und entfernbar.

### Was tatsächlich lernt

- Ein lokaler Bayesianischer Klassifikator berechnet aus deinen Markierungen eine Einordnung für Händler (ab 3 Beispielen) oder Kategorien (ab 5 Beispielen). Beta(1,1)-Prior: Wahrscheinlichkeit notwendig = (notwendige Beispiele + 1) / (bewertete Beispiele + 2). Notfälle und unmarkierte Einträge sind keine Trainingsbeispiele.
- Für notwendige Alltagsausgaben wird aus bis zu 8 abgeschlossenen Kalenderwochen ein vorsichtiger Wochenansatz (80%-Quantil) berechnet, frühestens ab 3 vollständigen Kalenderwochen und 8 markierten notwendigen Ausgaben. Der selbst eingetragene Mindestbedarf wird nie unterschritten. Fehlende oder falsch markierte Ausgaben können die Schätzung verfälschen.
- Der Assistent verändert das bestehende Wochenlimit und deine Planwerte nicht automatisch. Mehr Konsum rechtfertigt kein höheres Limit.
- Es handelt sich um lokal berechnete Lernmodelle und Budgetregeln, ohne externen Sprachmodell-/Chatdienst, Bankverbindung oder Standortüberwachung. Alle Daten bleiben im App-Speicher, bis du sie selbst als Backup teilst.

### Schutz und Empfehlungen

Der Richtwert für freie Wünsche zieht vom tatsächlichen Kontostand ab: bestehende Spartöpfe, offene Fixkosten (mindestens bis Monatsende und bis zum Gehaltstag), prognostizierten notwendigen Alltag, Sicherheitspuffer und noch zusätzlich geplantes Spargeld. Zusätzlich gilt das unveränderte verbleibende Wochenlimit abzüglich eines Alltagsbedarfs für die verbleibenden Wochentage. Zukünftiges Gehalt wird nicht zum Guthaben gerechnet. Die Hauptübersicht zeigt nach Einrichtung diesen Richtwert an.

Bei veraltetem Gehaltstag oder einer Planungslücke gibt es keine Kauf-Freigabe in der Wunschliste. Ein Kauf bleibt eine eigene Entscheidung; die App sperrt keine Bankkarte und kann tatsächliche Schulden nicht verhindern. Normale Ausgaben bleiben erfassbar, damit die Historie den echten Ausgaben entspricht.

**Kaufcheck:** Preis und optionalen Händler eingeben. Die Auswirkung auf deinen Plan wird angezeigt. Wünsche werden 48 Stunden zurückgestellt und vor dem Erfassen als Kauf erneut geprüft. Auf Wunsch verzichten entfernt ihn aus der Liste.

**Notfall:** Im Assistenten sofort aus dem ausgewählten Notfalltopf erfassen, ohne Kaufpause und höchstens bis zum tatsächlichen Topf-/Kontoguthaben. Kontostand und Notfallreserve sinken gemeinsam; die notwendige Reserve für andere Posten wird dadurch nicht doppelt verbraucht. Rückgängig stellt den Topf wieder her. Es erfolgt keine Banküberweisung.

**Sparen:** Ein vorsichtiger Zusatzvorschlag reserviert zuerst volle verbleibende Wochenbudgets. Es wird kein Geld automatisch bewegt. Wenn Geld in einen Spartopf reserviert wird, reduziert das den noch zusätzlich geplanten Sparbetrag, damit derselbe Betrag nicht doppelt abgezogen wird. Normale Entnahmen aus Spartöpfen werden als Hinweis auf Nachfüll-Gewohnheiten sichtbar; Notfälle sind davon ausgenommen.

Der Plan wird bei jedem Gehaltszyklus von dir neu bestätigt. Vor Updates Backup exportieren, bestehende Installation behalten. Datenformate 1 und 2 werden auf Format 3 übernommen; neue Backups mit Assistent-Daten sind für alte App-Versionen nicht geeignet.

## Entwicklung und Prüfungen

Auf macOS mit Xcode und Homebrew:

    swift test
    python3 scripts/test_source.py
    brew install xcodegen
    xcodegen generate
    open MeinSpielraum.xcodeproj

Für den Simulator den generierten Scheme `MeinSpielraum` wählen. Für einen signierten Direktstart auf einem eigenen iPhone in Xcode ein eigenes Team konfigurieren; für den GitHub-/SideStore-Weg ist das nicht nötig.

Vorbereitet sind Tests für Cent-Eingaben, Reservieren ohne Doppelabzug, Freigeben, Ausgabe rückgängig machen, JSON-Roundtrip und Wochenwechsel. 40 Swift-Tests, drei Python-Tests, der Xcode-Gerätebuild und die IPA-Metadatenprüfung liefen für Version 0.3.7 erfolgreich durch. Die Installation auf einem echten iPhone ist noch nicht geprüft.

## Verwendete Dokumentation

- SideStore-Quellen: https://docs.sidestore.io/docs/advanced/app-sources
- Source-Format: https://sidestore.io/sidestore-source-types/interfaces/Source.html
- App-/Versionsformat: https://sidestore.io/sidestore-source-types/interfaces/App.html
- GitHub-Runner: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- XcodeGen: https://github.com/yonaskolb/XcodeGen

App-Icon: individuell generiert; als 1024×1024-RGB-PNG in den Asset-Katalog eingebunden.
