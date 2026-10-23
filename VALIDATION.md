# Prüfstand · Version 0.3.14

Build: https://github.com/redshoxx/Mein-Spielraum/actions/runs/40017147882
Release: https://github.com/redshoxx/Mein-Spielraum/releases/tag/v0.3.14

- 68 Swift-Tests bestanden, einschließlich 12 Assistent-Tests.
- 4 Python-Source-Tests und 2 Kontrast-Prüfungen bestanden.
- 3 Simulator-Bedienprüfungen mit 12 Screenshot-Ansichten bestanden.
- Xcode-Gerätebuild und IPA-Metadatenprüfung erfolgreich.
- IPA, SideStore-Source, Icon und Prüfsumme veröffentlicht.
- Native Bildschirm-/Bedienprüfung auf echtem iPhone bleibt ausstehend. Die Genauigkeit von Prognosen mit tatsächlichen Nutzerdaten ist nicht empirisch validiert und wird nicht garantiert.

## Geprüfte Schutz- und Lernfälle

- Automatischer Start ohne Plan mit konservativer Alltagsreserve, Puffer und 30-Tage-Fallback. Im manuellen Modus weiterhin kein Kauf-Richtwert ohne gültigen Plan/Gehaltstag.
- Künftiges Einkommen erhöht keine verfügbaren Mittel.
- Offene Fixkosten über Monatsgrenzen hinweg werden geschützt.
- Markierungen verändern die Bayesianische Einschätzung ohne Geld- oder Limitänderung; Entfernen entfernt das Trainingsbeispiel.
- Gelerntes Alltagsbudget passt sich im Automatikmodus auch ohne Markierungen an. Es unterschreitet nie optionale Mindestbeträge und erhöht nie das Wochenlimit.
- Kaufpause und erneute Budgetprüfung bei Wünschen.
- Notfall ohne Kaufpause, begrenzt auf tatsächliche Notfallreserve und Kontoguthaben; Rückgängig stellt Geld und Reserve wieder her.
- Reservieren zusätzlich geplanten Spargelds ohne doppelten Abzug.
- Datenformat 2 wird mit bestehenden Kontoständen und Einträgen in Format 3 übernommen; neue Assistent-Daten durchlaufen einen JSON-Roundtrip. Bestehende Tests decken weiterhin Format 1 ab.

Lokale Statistik-/Lernmodelle ohne externen Sprachmodell-Dienst, Standortüberwachung, Bankanbindung oder automatische Bankaktionen. Speicherdatei und Bundle-ID bleiben unverändert.

## Spartöpfe bearbeiten und löschen

Fünf zusätzliche Swift-Tests prüfen Name und Ziel bei unverändertem Guthaben/Topf-ID, ungültige Eingaben ohne Teiländerungen, Freigabe und Notfallzuordnung beim Löschen, Erhalt früherer Notfallausgaben einschließlich Rückgängig nach Topflöschung sowie leere Töpfe ohne Geldbewegung.

## Automatik ohne Pflichtplan

Sechs zusätzliche Swift-Tests prüfen den Start ohne Konfiguration, vorsichtigen Fallback mit Puffer, Fortschreibung eines überfälligen Einnahmetermins ohne Geldbuchung, Lernen aus unmarkierten Ausgaben ohne Zukunftseinträge, Schutz optionaler Mindestbeträge und Fixkosten, Ende einer Einkommensserie sowie alte Backups und explizite manuelle Einstellungen. Die Modellgüte hängt von vollständig erfassten Ausgaben ab; fehlende Kontoumsätze werden nicht erkannt.

## Benachrichtigungen und Kaufbremse

Sechs zusätzliche Swift-Tests prüfen Erinnerungsdaten mit lokalen Uhrzeiten, generische Texte ohne Finanzdetails, bezahlte/entfernte/abgeschlossene Posten, Zusammenfassung überfälliger Posten ohne Einkommen als Rechnung, 48-Stunden-Kaufpause ohne Wiederholung alter Wünsche, Abschalten, Zeithorizont, Begrenzung auf 58 Einzelhinweise und die Zeitumstellung in Wien. Der zusätzliche Python-Test lehnt IPAs ohne Kaufcheck-URL-Schema ab; der Paketgenerator prüft dieses Schema im tatsächlichen Gerätebuild.

Nicht auf echtem iPhone geprüft: visuelles Layout, Systemdialog für Mitteilungen, Zustellung/Tap-Routing, Kurzbefehle-Automation, Deep-Link aus Amazon und Interaktionen mit Fokus/Bildschirmzeit. Keine Behauptung einer Warenkorb-Erkennung oder App-/Zahlungssperre. Die Kaufbremse ist freiwillig; die 15 Sekunden verzögern nur den Kaufcheck in ihrer Ansicht. Keine Bildschirmzeit-Entitlements oder Amazon-Anbindung hinzugefügt.

## Stabilität, Speichern und Performance

16 zusätzliche Swift-Tests: sieben Dateispeicher-Tests (Neustart, zwei vorherige Stände, beschädigte/fehlende/übergroße Hauptdatei, kaputte erste Sicherung, explizite Wiederherstellung mit Erhalt der alten Datei, ungültige Schreibvorgänge und blockiertes Ziel, externes Backup sowie unveränderter Stand ohne Sicherungsverlust), fünf Tests für Ausgabenkorrekturen einschließlich Notfallreserve/Undo/gelöschtem Topf und ungültigen Datumswerten, vier Berechnungstests (Vergleich schneller Terminberechnung mit Schleifenreferenz bei Monatsenden/Schaltjahren/Endtermin, künftiges Gehalt, 5.600 Ausgaben und Euro-Nachkommastellen).

Laden und Backup-Prüfung sowie Speichern aus den primären Bearbeitungsformularen laufen außerhalb des Main Actors. Finanzieller UI-Zustand wird erst nach erfolgreichem Schreiben veröffentlicht; Fehler lassen den bisherigen Zustand bestehen. Kleinere direkte Buchungsaktionen bleiben synchron. Zwei lokale Vorgängerkopien und vollständiger iOS-Dateischutz für neue Speicherungen/Exporte sind implementiert. Keine Behauptung einer separaten App-Verschlüsselung oder eines Offsite-Backups.

Nicht auf echtem Gerät geprüft: tatsächliche Start-/Bearbeitungszeiten, Verhalten bei iPhone-Sperre und geschützten Dateien, Systemabbruch während eines Schreibvorgangs, Wiederherstellungsdialoge und neue Ausgabenformulare. Es gibt keinen gemessenen prozentualen Geschwindigkeitsgewinn. Eine native Bildschirm- und Bedienprüfung im Simulator ist erfolgt; die Prüfung auf einem physischen iPhone bleibt ausstehend.

## Vollständige Überarbeitung der Lesbarkeit

Neue gemeinsame Palette mit hellen Flächen und dunkelblauer Schrift; die neuen beiden Farbtests prüfen 15 Kombinationen einschließlich sekundärer Texte und Statusfarben sowie den weißen Text auf der primären Schaltfläche. Alle verwendeten Schrift-/Flächenpaare erreichen im Rechentest mindestens 4,5:1, der primäre Button mindestens 7:1. Native Systemkomponenten und deaktivierte Zustände sind davon nicht pauschal zertifiziert.

Drei Simulator-Bedienprüfungen decken Übersicht, Haushalt, Einnahmen, Budgetformular, Spartöpfe/Bearbeiten, Ausgabeformular, Kaufcheck, Assistent und Benachrichtigungen sowie Navigation mit großer Schrift ab. Screenshots werden als UI-Screenshots.zip im Release bereitgestellt. Die Debug-Vorschau verwendet isolierte Beispieldaten in einem temporären Ordner; der Release-Build enthält keinen aktiven Testmodus.

Kein Test auf einem physischen iPhone; VoiceOver und alle Größen-/Sprachkombinationen sind nicht vollständig geprüft. Finanzmodell, gespeicherte Dateiformate, Sicherungskopien und Berechnungen wurden für dieses Redesign nicht verändert.

Visuelle Nachprüfung: Die erste Simulator-Bildserie zeigte abgeschnittene Erklärungen und zu breite Navigationslabels bei großer Schrift. Version 0.3.14 erzwingt vertikalen Textumbruch, verwendet kürzere sichtbare Navigationsnamen bei Accessibility-Schriftgrößen und ersetzt die kleine Segmentauswahl im Assistenten durch größere Textschaltflächen.

Die finale Bildschirmserie von 0.3.14 wurde visuell nachgeprüft: Übersicht und Haushalt mit großer Schrift sowie Übersicht und Assistent mit normaler Schrift. Die zuvor abgeschnittenen Beschriftungen und der überbreite untere Navigationsbereich sind in diesen Ansichten behoben. Alle 3 Simulator-Bedienprüfungen und der Gerätebuild dieses Releases sind erfolgreich.
