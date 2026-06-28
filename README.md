# ClipSpin

- A temporary second paste queue for macOS.

ClipSpin lets you start a temporary text queue from the terminal. While ClipSpin is running, press `Option+V` to insert the next text from the queue. After each insert, ClipSpin advances to the next item. When the end of the list is reached, it starts again from the beginning.

ClipSpin does **not** use or overwrite your normal macOS clipboard. Your regular `Cmd+V` clipboard stays untouched.

## Installation

```bash
brew install oliverjessner/tap/clipspin
```

ClipSpin uses a native macOS event tap to detect and intercept `Option+V`. On first use, macOS may require accessibility permissions.

If `Option+V` is not detected, allow ClipSpin or your terminal app under:

**System Settings -> Privacy & Security -> Accessibility**

Depending on your macOS version, **Input Monitoring** may also be required.

## Usage

Inline:

```bash
clipspin '["First text", "Second text", "Third text"]'
```

From a file:

```bash
clipspin snippets.json
```

`snippets.json` must contain a JSON array of strings:

```json
["First text", "Second text", "Third text"]
```

## How it works

Start ClipSpin with a JSON array of strings:

```bash
clipspin '["First text", "Second text", "Third text"]'
```

Then click into any text field and press:

```text
Option+V
```

The first press inserts:

```text
First text
```

The next press inserts:

```text
Second text
```

The next press inserts:

```text
Third text
```

After the last item, ClipSpin jumps back to the first item.

## Stopping ClipSpin

Stop ClipSpin with `Ctrl+C` in the terminal.

Because ClipSpin does not modify your normal clipboard, there is no clipboard content to restore after stopping.

## Permissions

ClipSpin needs macOS permissions because it listens for a global keyboard shortcut and blocks the default `Option+V` behavior.

Without these permissions, macOS may still insert the default `Option+V` character, such as:

```text
√
```

To fix this, allow ClipSpin or your terminal app under:

```text
System Settings -> Privacy & Security -> Accessibility
```

If it still does not work, also check:

```text
System Settings -> Privacy & Security -> Input Monitoring
```

After changing permissions, restart the terminal and start ClipSpin again.

## Notes

ClipSpin is currently macOS-only.

It is designed for temporary paste queues, for example when you need to insert a fixed list of snippets one after another without constantly switching back to your clipboard manager.

### Publish

```
# replace 0.1.8 with the next version
./scripts/publish.sh 0.1.8
```
