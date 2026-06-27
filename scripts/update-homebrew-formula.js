#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import process from 'node:process';

const tapName = 'oliverjessner/tap';
const formulaName = 'clipspin';
const rootDir = path.resolve(new URL('..', import.meta.url).pathname);
const pkg = JSON.parse(readFileSync(path.join(rootDir, 'package.json'), 'utf8'));

function run(command, args, options = {}) {
    return execFileSync(command, args, {
        encoding: 'utf8',
        stdio: options.stdio ?? ['ignore', 'pipe', 'pipe'],
        cwd: options.cwd,
    });
}

function runVisible(command, args, options = {}) {
    execFileSync(command, args, {
        stdio: 'inherit',
        cwd: options.cwd,
    });
}

function getTapDir() {
    if (process.env.HOMEBREW_TAP_DIR) {
        return path.resolve(process.env.HOMEBREW_TAP_DIR);
    }

    try {
        return run('brew', ['--repository', tapName]).trim();
    } catch {
        runVisible('brew', ['tap', tapName]);
        return run('brew', ['--repository', tapName]).trim();
    }
}

function ensureCleanGitRepo(repoDir) {
    const status = run('git', ['status', '--porcelain'], { cwd: repoDir }).trim();

    if (status) {
        console.error(`Refusing to update ${repoDir}: git working tree is not clean.`);
        console.error(status);
        process.exit(1);
    }

    runVisible('git', ['pull', '--ff-only'], { cwd: repoDir });
}

function getPublishedTarballUrl() {
    const packageRef = `${pkg.name}@${pkg.version}`;

    try {
        return run('npm', ['view', packageRef, 'dist.tarball']).trim();
    } catch {
        console.error(`Could not find ${packageRef} on npm.`);
        console.error('Run npm run publish:npm first, then retry npm run publish:brew.');
        process.exit(1);
    }
}

function getSha256(url) {
    const tarballPath = path.join(tmpdir(), `${pkg.name}-${pkg.version}.tgz`);

    runVisible('curl', ['-L', '-o', tarballPath, url]);

    return run('shasum', ['-a', '256', tarballPath]).trim().split(/\s+/)[0];
}

function updateFormula(formulaPath, url, sha256) {
    if (!existsSync(formulaPath)) {
        console.error(`Formula not found: ${formulaPath}`);
        process.exit(1);
    }

    const original = readFileSync(formulaPath, 'utf8');
    const updated = original
        .replace(/^\s*url ".*"$/m, `  url "${url}"`)
        .replace(/^\s*sha256 ".*"$/m, `  sha256 "${sha256}"`);

    if (updated === original) {
        console.log(`${formulaPath} is already up to date.`);
        return false;
    }

    writeFileSync(formulaPath, updated);
    return true;
}

function commitAndPush(tapDir) {
    const status = run('git', ['status', '--porcelain'], { cwd: tapDir }).trim();

    if (!status) {
        console.log('No Homebrew formula changes to commit.');
        return;
    }

    runVisible('brew', ['style', `Formula/${formulaName}.rb`], { cwd: tapDir });
    runVisible('brew', ['audit', '--formula', `${tapName}/${formulaName}`], { cwd: tapDir });

    runVisible('git', ['add', `Formula/${formulaName}.rb`], { cwd: tapDir });
    runVisible('git', ['commit', '-m', `${formulaName} ${pkg.version}`], { cwd: tapDir });
    runVisible('git', ['push', 'origin', 'main'], { cwd: tapDir });
}

const tapDir = getTapDir();
const formulaPath = path.join(tapDir, 'Formula', `${formulaName}.rb`);
ensureCleanGitRepo(tapDir);

const tarballUrl = getPublishedTarballUrl();
const sha256 = getSha256(tarballUrl);

updateFormula(formulaPath, tarballUrl, sha256);
commitAndPush(tapDir);
