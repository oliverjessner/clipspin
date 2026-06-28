#!/usr/bin/env bash
set -euo pipefail

APP_NAME="clipspin"
FORMULA_NAME="clipspin"
FORMULA_CLASS="Clipspin"

GITHUB_USER="oliverjessner"
SOURCE_REPO="${GITHUB_USER}/${APP_NAME}"
TAP_NAME="${GITHUB_USER}/tap"
TAP_REPO_URL="https://github.com/${GITHUB_USER}/homebrew-tap.git"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_DIR="$(cd "${APP_DIR}/.." && pwd)"

TAP_DIR="${TAP_DIR:-${WORKSPACE_DIR}/homebrew-tap}"

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/publish.sh <version>"
  echo "Example: ./scripts/publish.sh 0.1.7"
  exit 1
fi

TAG="v${VERSION}"
TARBALL_URL="https://github.com/${SOURCE_REPO}/archive/refs/tags/${TAG}.tar.gz"

echo "Publishing ${APP_NAME} ${TAG} to ${GITHUB_USER}/homebrew-tap"
echo ""

cd "${APP_DIR}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: Run this script from inside the ${APP_NAME} git repository."
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: Working tree is not clean. Commit or stash changes first."
  exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "App repo: ${APP_DIR}"
echo "Tap repo: ${TAP_DIR}"
echo "Current branch: ${CURRENT_BRANCH}"
echo ""

echo "Validating release build..."

if [[ -f "main.swift" ]]; then
  VERSION_REGEX="${VERSION//./\\.}"

  if ! grep -Eq "let[[:space:]]+version([[:space:]]*:[[:space:]]*String)?[[:space:]]*=[[:space:]]*\"${VERSION_REGEX}\"" main.swift; then
    echo "Error: main.swift version does not match ${VERSION}."
    echo "Expected a line like:"
    echo "  let version = \"${VERSION}\""
    exit 1
  fi

  swiftc main.swift -o "${TMP_DIR}/${APP_NAME}-build-check"
elif [[ -f "Package.swift" ]]; then
  swift build --configuration release --disable-sandbox
else
  echo "Error: No main.swift or Package.swift found."
  exit 1
fi

echo ""
echo "Creating git tag if needed..."

if git rev-parse "${TAG}" >/dev/null 2>&1; then
  echo "Tag ${TAG} already exists locally."
else
  git tag -a "${TAG}" -m "${APP_NAME} ${TAG}"
fi

echo "Pushing branch and tag..."
git push origin "${CURRENT_BRANCH}"
git push origin "${TAG}" || true

TARBALL_PATH="${TMP_DIR}/${APP_NAME}-${TAG}.tar.gz"

echo ""
echo "Downloading release tarball..."
curl -L "${TARBALL_URL}" -o "${TARBALL_PATH}"

echo "Calculating SHA256..."
SHA256="$(shasum -a 256 "${TARBALL_PATH}" | awk '{print $1}')"

echo "SHA256: ${SHA256}"
echo ""

if [[ ! -d "${TAP_DIR}/.git" ]]; then
  echo "Tap repo not found at ${TAP_DIR}"
  echo "Cloning tap repo..."
  mkdir -p "$(dirname "${TAP_DIR}")"
  git clone "${TAP_REPO_URL}" "${TAP_DIR}"
else
  echo "Updating tap repo at ${TAP_DIR}..."
  git -C "${TAP_DIR}" remote set-url origin "${TAP_REPO_URL}"
  git -C "${TAP_DIR}" pull --rebase
fi

if [[ -n "$(git -C "${TAP_DIR}" status --porcelain)" ]]; then
  echo "Error: Tap repo has uncommitted changes."
  echo "Commit, stash, or clean changes in:"
  echo "  ${TAP_DIR}"
  exit 1
fi

FORMULA_DIR="${TAP_DIR}/Formula"
FORMULA_PATH="${FORMULA_DIR}/${FORMULA_NAME}.rb"

mkdir -p "${FORMULA_DIR}"

echo ""
echo "Writing formula: ${FORMULA_PATH}"

cat > "${FORMULA_PATH}" <<EOF
class ${FORMULA_CLASS} < Formula
  desc "Temporary second paste queue for macOS"
  homepage "https://github.com/${SOURCE_REPO}"
  url "${TARBALL_URL}"
  sha256 "${SHA256}"
  license "MIT"

  depends_on xcode: :build

  def install
    if File.exist?("Package.swift")
      system "swift", "build", "--configuration", "release", "--disable-sandbox"
      bin.install ".build/release/${APP_NAME}"
    else
      system "swiftc", "main.swift", "-o", "${APP_NAME}"
      bin.install "${APP_NAME}"
    end
  end

  test do
    assert_match "Usage", shell_output("#{bin}/${APP_NAME} 2>&1", 1)
  end
end
EOF

echo ""
echo "Formula content:"
echo ""
cat "${FORMULA_PATH}"
echo ""

echo "Committing formula update..."
git -C "${TAP_DIR}" add "${FORMULA_PATH}"

if git -C "${TAP_DIR}" diff --cached --quiet; then
  echo "No formula changes to commit."
else
  git -C "${TAP_DIR}" commit -m "${FORMULA_NAME} ${VERSION}"
  git -C "${TAP_DIR}" push
fi

echo ""
echo "Registering/updating Homebrew tap..."
brew tap "${TAP_NAME}" "${TAP_REPO_URL}" >/dev/null 2>&1 || true
brew update >/dev/null 2>&1 || true

echo ""
echo "Running brew audit..."
brew audit --strict --online "${TAP_NAME}/${FORMULA_NAME}" || true

echo ""
echo "Running brew install test from tap..."
brew uninstall "${FORMULA_NAME}" >/dev/null 2>&1 || true
brew install --build-from-source "${TAP_NAME}/${FORMULA_NAME}"

echo ""
echo "Testing installed binary..."
"${FORMULA_NAME}" 2>/dev/null || true

echo ""
echo "Done."
echo ""
echo "Users can now install with:"
echo "  brew install ${TAP_NAME}/${FORMULA_NAME}"
