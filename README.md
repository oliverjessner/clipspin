# ClipSpin

- cycle your paste queue with every CMD+V.

Du startest Clipspin im Terminal mit einer JSON-Liste aus Texten. Solange der Command läuft, reagiert ClipSpin auf `Cmd+V`: Beim ersten Einfügen wird der erste Text aus der Liste verwendet, beim nächsten `Cmd+V` der zweite, danach der dritte und so weiter. Am Ende der Liste springt ClipSpin wieder zurück zum Anfang.

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

Stoppen kannst du ClipSpin mit `Ctrl+C` im Terminal. Die vorherige Zwischenablage wird danach wiederhergestellt.

Wenn `Cmd+V` nicht erkannt wird, starte ClipSpin im Debug-Modus:

```bash
clipspin --debug '["Erster Text", "Zweiter Text"]'
```

Beim Drücken von Tasten sollten dann `[debug]`-Zeilen erscheinen. Wenn keine erscheinen, fehlen macOS-Berechtigungen für die Terminal-App.
