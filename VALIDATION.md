# Prüfstand · Version 0.3.7

Build: https://github.com/redshoxx/Mein-Spielraum/actions/runs/39272890833
Release: https://github.com/redshoxx/Mein-Spielraum/releases/tag/v0.3.7

- 40 Swift-Tests bestanden, einschließlich 12 Assistent-Tests.
- 3 Python-Source-Tests bestanden.
- Xcode-Gerätebuild und IPA-Metadatenprüfung erfolgreich.
- IPA, SideStore-Source, Icon und Prüfsumme veröffentlicht.
- Native Bildschirm-/Bedienprüfung auf echtem iPhone bleibt ausstehend. Die Genauigkeit von Prognosen mit tatsächlichen Nutzerdaten ist nicht empirisch validiert und wird nicht garantiert.

## Geprüfte Schutz- und Lernfälle

- Ohne Plan oder bei abgelaufenem Gehaltstag kein Kauf-Richtwert.
- Künftiges Einkommen erhöht keine verfügbaren Mittel.
- Offene Fixkosten über Monatsgrenzen hinweg werden geschützt.
- Markierungen verändern die Bayesianische Einschätzung ohne Geld- oder Limitänderung; Entfernen entfernt das Trainingsbeispiel.
- Gelerntes Alltagsbudget kann den Schutz erhöhen, nicht den vorgegebenen Mindestbedarf unterschreiten oder das Wochenlimit anheben.
- Kaufpause und erneute Budgetprüfung bei Wünschen.
- Notfall ohne Kaufpause, begrenzt auf tatsächliche Notfallreserve und Kontoguthaben; Rückgängig stellt Geld und Reserve wieder her.
- Reservieren zusätzlich geplanten Spargelds ohne doppelten Abzug.
- Datenformat 2 wird mit bestehenden Kontoständen und Einträgen in Format 3 übernommen; neue Assistent-Daten durchlaufen einen JSON-Roundtrip. Bestehende Tests decken weiterhin Format 1 ab.

Lokale Statistik-/Lernmodelle ohne externen Sprachmodell-Dienst, Standortüberwachung, Bankanbindung oder automatische Bankaktionen. Speicherdatei und Bundle-ID bleiben unverändert.

## Spartöpfe bearbeiten und löschen

Fünf zusätzliche Swift-Tests prüfen Name und Ziel bei unverändertem Guthaben/Topf-ID, ungültige Eingaben ohne Teiländerungen, Freigabe und Notfallzuordnung beim Löschen, Erhalt früherer Notfallausgaben einschließlich Rückgängig nach Topflöschung sowie leere Töpfe ohne Geldbewegung.
