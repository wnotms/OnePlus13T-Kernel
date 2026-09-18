#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_FILE="$ROOT_DIR/configs/device.env"
[[ -f "$CONFIG_FILE" ]] || { echo "::error::Missing $CONFIG_FILE" >&2; exit 1; }
source "$CONFIG_FILE"

WORK_DIR="${WORK_DIR:-$ROOT_DIR/work}"
KERNEL_PLATFORM="$WORK_DIR/kernel_platform"
COMMON_DIR="$KERNEL_PLATFORM/common"
OUT_DIR="$COMMON_DIR/out"
FEATURE_CONFIG="$WORK_DIR/feature.config"
ARTIFACT_DIR="$WORK_DIR/artifacts"
mkdir -p "$WORK_DIR" "$ARTIFACT_DIR"

die(){ echo "::error::$*" >&2; exit 1; }
notice(){ echo "::notice::$*"; }
add_config(){ local line="$1"; touch "$FEATURE_CONFIG"; grep -qxF "$line" "$FEATURE_CONFIG" 2>/dev/null || echo "$line" >> "$FEATURE_CONFIG"; }
apply_patch_file(){
  local patch_file="$1" label="${2:-$(basename "$1")}"
  [[ -f "$patch_file" ]] || die "Patch not found: $patch_file"
  if patch -d "$COMMON_DIR" -p1 --dry-run < "$patch_file" >/dev/null 2>&1; then
    patch -d "$COMMON_DIR" -p1 < "$patch_file"; notice "$label applied"; return 0
  fi
  if patch -d "$COMMON_DIR" -R -p1 --dry-run < "$patch_file" >/dev/null 2>&1; then
    notice "$label already present; skipped"; return 0
  fi
  return 1
}
download_patch(){ curl -fL --retry 5 --retry-delay 2 "$1" -o "$2"; }
