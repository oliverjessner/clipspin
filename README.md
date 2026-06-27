# ClipSpin

ClipSpin ist ein temporärer macOS-Clipboard-Cycler. Du gibst eine JSON-Liste mit Texten an; bei jedem `Cmd+V` wird der aktuelle Text eingefügt und direkt danach der nächste vorbereitet.

## Installation

```bash
brew install oliverjessner/tap/clipspin
```

ClipSpin nutzt einen globalen Keyboard-Hook. Falls `Cmd+V` nicht erkannt wird, erlaube deiner Terminal-App unter **Systemeinstellungen -> Datenschutz & Sicherheit -> Bedienungshilfen** den Zugriff. Je nach System kann auch **Eingabeüberwachung** nötig sein.

## Verwendung

Inline:

```bash
clipspin '["Erster Text", "Zweiter Text", "Dritter Text"]'
```

Aus einer Datei:

```bash
clipspin snippets.json
```

Per Pipe:

```bash
cat snippets.json | clipspin
```

`snippets.json` muss ein JSON-Array aus Strings enthalten:

```json
["Erster Text", "Zweiter Text", "Dritter Text"]
```

Nach dem Start liegt der erste Eintrag in der Zwischenablage. Mit jedem `Cmd+V` wird der nächste Eintrag vorbereitet; nach dem letzten beginnt ClipSpin wieder von vorne.

Stoppen kannst du ClipSpin mit `Ctrl+C` im Terminal. Die vorherige Zwischenablage wird danach wiederhergestellt.

Wenn `Cmd+V` nicht erkannt wird, starte ClipSpin im Debug-Modus:

```bash
clipspin --debug '["Erster Text", "Zweiter Text"]'
```

Beim Drücken von Tasten sollten dann `[debug]`-Zeilen erscheinen. Wenn keine erscheinen, fehlen macOS-Berechtigungen für die Terminal-App.

## Veröffentlichen

Vor dem Publish die Version in `package.json` erhöhen. Danach:

```bash
npm run publish:npm
npm run publish:brew
```

Oder beides nacheinander:

```bash
npm run publish:all
```

`publish:brew` erwartet, dass die npm-Version bereits veröffentlicht ist. Der Befehl aktualisiert `oliverjessner/tap/clipspin`, setzt die npm-Tarball-URL samt SHA256, führt Homebrew-Checks aus, committet die Formula und pusht den Tap.
