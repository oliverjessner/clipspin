#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import process from 'node:process';
import { uIOhook, UiohookKey } from 'uiohook-napi';

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
}

function getClipboard() {
    const result = spawnSync('pbpaste', {
        encoding: 'utf8',
    });

    if (result.error) {
        return '';
    }

    return result.stdout ?? '';
}

async function getInput() {
    const args = process.argv.slice(2);

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

const rawInput = await getInput();

if (!rawInput) {
    console.error('Usage: node index.js \'["A", "B", "C"]\'');
    console.error('   or: cat snippets.json | node index.js');
    console.error('   or: node index.js snippets.json');
    process.exit(1);
}

const items = parseItems(rawInput);

let index = 0;
let lastPasteAt = 0;
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

function restoreAndExit(code = 0) {
    try {
        setClipboard(originalClipboard);
        console.log('\nClipboard restored.');
    } catch {
        console.error('\nCould not restore clipboard.');
    }

    try {
        uIOhook.stop();
    } catch {}

    process.exit(code);
}

process.on('SIGINT', () => restoreAndExit(0));
process.on('SIGTERM', () => restoreAndExit(0));

primeClipboard();

console.log('paste-cycle active.');
console.log('Press Cmd + V anywhere to paste/cycle.');
console.log('Press Ctrl + C here to stop.\n');

uIOhook.on('keydown', event => {
    const isCommandV = event.metaKey === true && event.keycode === UiohookKey.V;

    if (!isCommandV) {
        return;
    }

    const now = Date.now();

    // Prevent repeat events if Cmd+V is held down.
    if (now - lastPasteAt < 250) {
        return;
    }

    lastPasteAt = now;

    // Important:
    // Let the current Cmd+V paste the already primed clipboard.
    // Then prepare the next item shortly after.
    setTimeout(() => {
        moveToNextItem();
    }, 120);
});

uIOhook.start();
