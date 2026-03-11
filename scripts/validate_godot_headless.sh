#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_VERSION="${GODOT_VERSION:-4.6.1-stable}"
TOOLS_DIR="${ROOT_DIR}/.tools/godot"
ZIP_NAME="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
BIN_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${ZIP_NAME}"

mkdir -p "${TOOLS_DIR}"
cd "${TOOLS_DIR}"

if [[ ! -x "${BIN_NAME}" ]]; then
  echo "[validate] downloading ${URL}"
  wget -q "${URL}"
  unzip -q -o "${ZIP_NAME}"
  chmod +x "${BIN_NAME}"
fi

"${TOOLS_DIR}/${BIN_NAME}" --version
"${TOOLS_DIR}/${BIN_NAME}" --headless --path "${ROOT_DIR}" --import
"${TOOLS_DIR}/${BIN_NAME}" --headless --path "${ROOT_DIR}" res://src/Scripts/Tests/test_runner_scene.tscn --quit-after 20
"${TOOLS_DIR}/${BIN_NAME}" --headless --path "${ROOT_DIR}" --quit-after 10

echo "[validate] done"
