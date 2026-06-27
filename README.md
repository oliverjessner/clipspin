# ClipSpin

ClipSpin ist ein temporärer macOS-Clipboard-Cycler. Du gibst eine JSON-Liste mit Texten an; bei jedem `Cmd+V` wird der aktuelle Text eingefügt und direkt danach der nächste vorbereitet.

## Installation

```bash
npm install
```

ClipSpin nutzt einen globalen Keyboard-Hook. Falls `Cmd+V` nicht erkannt wird, erlaube deiner Terminal-App unter **Systemeinstellungen -> Datenschutz & Sicherheit -> Bedienungshilfen** den Zugriff. Je nach System kann auch **Eingabeüberwachung** nötig sein.

## Verwendung

Inline:

```bash
node index.js '["Erster Text", "Zweiter Text", "Dritter Text"]'
```

Oder über npm:

```bash
npm start -- '["Erster Text", "Zweiter Text", "Dritter Text"]'
```

Aus einer Datei:

```bash
node index.js snippets.json
```

Per Pipe:

```bash
cat snippets.json | node index.js
```

`snippets.json` muss ein JSON-Array aus Strings enthalten:

```json
["Erster Text", "Zweiter Text", "Dritter Text"]
```

Nach dem Start liegt der erste Eintrag in der Zwischenablage. Mit jedem `Cmd+V` wird der nächste Eintrag vorbereitet; nach dem letzten beginnt ClipSpin wieder von vorne.

Stoppen kannst du ClipSpin mit `Ctrl+C` im Terminal. Die vorherige Zwischenablage wird danach wiederhergestellt.

Wenn `Cmd+V` nicht erkannt wird, starte ClipSpin im Debug-Modus:

```bash
npm start -- --debug '["Erster Text", "Zweiter Text"]'
```

Beim Drücken von Tasten sollten dann `[debug]`-Zeilen erscheinen. Wenn keine erscheinen, fehlen macOS-Berechtigungen für die Terminal-App.

Optional kannst du lokal den Befehl `clipspin` verlinken:

```bash
npm link
clipspin '["Erster Text", "Zweiter Text"]'
```
