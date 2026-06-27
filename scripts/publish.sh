#!/usr/bin/env bash
set -euo pipefail

APP_NAME="clipspin"
FORMULA_NAME="clipspin"
FORMULA_CLASS="Clipspin"

GITHUB_USER="oliverjessner"
SOURCE_REPO="${GITHUB_USER}/${APP_NAME}"
TAP_REPO_URL="git@github.com:${GITHUB_USER}/homebrew-tap.git"

TAP_DIR="${TAP_DIR:-$HOME/dev/homebrew-tap}"

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: ./publish-homebrew.sh <version>"
  echo "Example: ./publish-homebrew.sh 0.1.0"
  exit 1
fi

TAG="v${VERSION}"
TARBALL_URL="https://github.com/${SOURCE_REPO}/archive/refs/tags/${TAG}.tar.gz"

echo "Publishing ${APP_NAME} ${TAG} to ${GITHUB_USER}/homebrew-tap"
echo ""

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: Run this script from inside the ${APP_NAME} git repository."
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: Working tree is not clean. Commit or stash changes first."
  exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"

echo "Current branch: ${CURRENT_BRANCH}"
echo "Creating git tag if needed..."

if git rev-parse "${TAG}" >/dev/null 2>&1; then
  echo "Tag ${TAG} already exists locally."
else
  git tag -a "${TAG}" -m "${APP_NAME} ${TAG}"
fi

echo "Pushing branch and tag..."
git push origin "${CURRENT_BRANCH}"
git push origin "${TAG}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TARBALL_PATH="${TMP_DIR}/${APP_NAME}-${TAG}.tar.gz"

echo "Downloading release tarball..."
curl -L "${TARBALL_URL}" -o "${TARBALL_PATH}"

echo "Calculating SHA256..."
SHA256="$(shasum -a 256 "${TARBALL_PATH}" | awk '{print $1}')"

echo "SHA256: ${SHA256}"
echo ""

if [[ ! -d "${TAP_DIR}/.git" ]]; then
  echo "Cloning tap repo into ${TAP_DIR}..."
  mkdir -p "$(dirname "${TAP_DIR}")"
  git clone "${TAP_REPO_URL}" "${TAP_DIR}"
else
  echo "Updating tap repo..."
  git -C "${TAP_DIR}" pull --rebase
fi

FORMULA_DIR="${TAP_DIR}/Formula"
FORMULA_PATH="${FORMULA_DIR}/${FORMULA_NAME}.rb"

mkdir -p "${FORMULA_DIR}"

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

echo "Formula content:"
echo ""
cat "${FORMULA_PATH}"
echo ""

echo "Running brew audit..."
brew audit --strict --online "${FORMULA_PATH}" || true

echo "Running brew install test from local formula..."
brew uninstall "${APP_NAME}" >/dev/null 2>&1 || true
brew install --build-from-source "${FORMULA_PATH}"

echo "Testing installed binary..."
"${APP_NAME}" 2>/dev/null || true

echo "Committing formula update..."
git -C "${TAP_DIR}" add "${FORMULA_PATH}"

if git -C "${TAP_DIR}" diff --cached --quiet; then
  echo "No formula changes to commit."
else
  git -C "${TAP_DIR}" commit -m "${FORMULA_NAME} ${VERSION}"
  git -C "${TAP_DIR}" push
fi

echo ""
echo "Done."
echo ""
echo "Users can now install with:"
echo "  brew install ${GITHUB_USER}/tap/${FORMULA_NAME}"