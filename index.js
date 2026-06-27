#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import process from 'node:process';
import { uIOhook, UiohookKey } from 'uiohook-napi';

function parseArgs() {
    const args = process.argv.slice(2);
    const inputArgs = [];
    let debug = false;

    for (const arg of args) {
        if (arg === '--debug') {
            debug = true;
            continue;
        }

        inputArgs.push(arg);
    }

    return { debug, inputArgs };
}

function readStdin() {
    return new Promise(resolve => {
        let data = '';

        process.stdin.setEncoding('utf8');

        process.stdin.on('data', chunk => {
            data += chunk;
        });

        process.stdin.on('end', () => {
            resolve(data.trim());
        });

        if (process.stdin.isTTY) {
            resolve('');
        }
    });
}

function setClipboard(text) {
    const result = spawnSync('pbcopy', {
        input: text,
        encoding: 'utf8',
    });

    if (result.error) {
        throw result.error;
    }

    if (result.status !== 0) {
        throw new Error(result.stderr || 'pbcopy failed.');
    }
}

function getClipboard() {
    const result = spawnSync('pbpaste', {
        encoding: 'utf8',
    });

    if (result.error || result.status !== 0) {
        return '';
    }

    return result.stdout ?? '';
}

async function getInput(args) {
    if (args.length > 0) {
        const first = args[0];

        if (first.endsWith('.json')) {
            return readFileSync(first, 'utf8');
        }

        return args.join(' ');
    }

    return await readStdin();
}

function parseItems(raw) {
    let parsed;

    try {
        parsed = JSON.parse(raw);
    } catch {
        console.error('Invalid JSON. Expected: ["Text 1", "Text 2", "Text 3"]');
        process.exit(1);
    }

    if (!Array.isArray(parsed)) {
        console.error('Input must be a JSON array.');
        process.exit(1);
    }

    if (parsed.length === 0) {
        console.error('JSON array must not be empty.');
        process.exit(1);
    }

    if (!parsed.every(item => typeof item === 'string')) {
        console.error('Every array item must be a string.');
        process.exit(1);
    }

    return parsed;
}

const { debug, inputArgs } = parseArgs();
const rawInput = await getInput(inputArgs);

if (!rawInput) {
    console.error('Usage: clipspin \'["A", "B", "C"]\'');
    console.error('Debug: clipspin --debug \'["A", "B", "C"]\'');
    console.error('   or: cat snippets.json | clipspin');
    console.error('   or: clipspin snippets.json');
    process.exit(1);
}

const items = parseItems(rawInput);

let index = 0;
let lastPasteAt = 0;
let commandDown = false;
let pendingPaste = false;
let pasteFallbackTimer = null;
const originalClipboard = getClipboard();

function currentLabel() {
    return `${index + 1}/${items.length}`;
}

function primeClipboard() {
    setClipboard(items[index]);
    console.log(`Clipboard primed: ${currentLabel()}`);
}

function moveToNextItem() {
    index = (index + 1) % items.length;
    primeClipboard();
}

function advanceAfterPaste(delayMs) {
    pendingPaste = false;

    if (pasteFallbackTimer !== null) {
        clearTimeout(pasteFallbackTimer);
        pasteFallbackTimer = null;
    }

    setTimeout(() => {
        moveToNextItem();
    }, delayMs);
}

function restoreAndExit(code = 0) {
    try {
        setClipboard(originalClipboard);
        console.log('\nClipboard restored.');
    } catch {
        console.error('\nCould not restore clipboard.');
    }

    process.exit(code);
}

process.on('SIGINT', () => restoreAndExit(0));
process.on('SIGTERM', () => restoreAndExit(0));

primeClipboard();

console.log('paste-cycle active.');
console.log('Press Cmd + V anywhere to paste/cycle.');
console.log('Press Ctrl + C here to stop.\n');

function isCommandKey(event) {
    return event.keycode === UiohookKey.Meta || event.keycode === UiohookKey.MetaRight;
}

function isPasteKey(event) {
    return event.keycode === UiohookKey.V || event.keycode === 9;
}

function logKeyEvent(name, event) {
    if (!debug) {
        return;
    }

    console.log(
        `[debug] ${name}: keycode=${event.keycode} meta=${event.metaKey} commandDown=${commandDown} ctrl=${event.ctrlKey} alt=${event.altKey} shift=${event.shiftKey}`,
    );
}

uIOhook.on('keydown', event => {
    logKeyEvent('keydown', event);

    if (isCommandKey(event)) {
        commandDown = true;
    }

    const isCommandV = (event.metaKey === true || commandDown) && isPasteKey(event);

    if (!isCommandV) {
        return;
    }

    const now = Date.now();

    // Prevent repeat events if Cmd+V is held down.
    if (now - lastPasteAt < 250) {
        return;
    }

    if (pendingPaste) {
        return;
    }

    lastPasteAt = now;
    pendingPaste = true;

    if (debug) {
        console.log('[debug] Cmd+V detected.');
    }

    pasteFallbackTimer = setTimeout(() => {
        if (pendingPaste) {
            advanceAfterPaste(0);
        }
    }, 450);
});

uIOhook.on('keyup', event => {
    logKeyEvent('keyup', event);

    const shouldAdvance = pendingPaste;

    if (isCommandKey(event)) {
        commandDown = false;
    }

    if (shouldAdvance) {
        // Let the application finish handling Cmd+V before replacing the clipboard.
        advanceAfterPaste(80);
    }
});

try {
    uIOhook.start();
} catch (error) {
    console.error('Could not start keyboard hook.');
    console.error(error instanceof Error ? error.message : String(error));
    console.error('On macOS, allow your terminal app in Accessibility and Input Monitoring.');
    restoreAndExit(1);
}
