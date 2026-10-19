# Prüfstand

- Python Source-Generator: 3 Tests bestanden.
- Workflow-YAML, XcodeGen-Spezifikation, JSON-Assets: lokal statisch geprüft.
- Swift-Tests: vorbereitet, hier mangels Swift-Compiler nicht ausgeführt.
- Xcode-Gerätebuild: mangels macOS nicht ausgeführt; erster GitHub-Actions-Lauf ausstehend.
- IPA-/SideStore-Installation und native Bildschirmprüfung: ausstehend.
- Es gibt noch keinen veröffentlichten Build und noch keine erreichbare Source-URL.

Die Python-Tests verwenden absichtlich Test-IPA-Dateien ohne lauffähige iOS-Binärdatei, um Metadatenprüfung und Fehlerfälle zu testen. Sie sind keine iOS-Buildprüfung. Der echte Workflow erstellt und paketiert die Binärdatei erst nach erfolgreichem xcodebuild.

Der Browser-Zugriff auf die frühere Web-Vorschau wurde durch die URL-Sicherheitsrichtlinie blockiert. Es wird keine visuelle Freigabe aus dieser Vorschau auf die native App übertragen.
