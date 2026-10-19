# Prüfstand · Version 0.3.8

Build: https://github.com/redshoxx/Mein-Spielraum/actions/runs/39273601609
Release: https://github.com/redshoxx/Mein-Spielraum/releases/tag/v0.3.8

- 46 Swift-Tests bestanden, einschließlich 12 Assistent-Tests.
- 3 Python-Source-Tests bestanden.
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
