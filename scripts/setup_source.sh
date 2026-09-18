#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

rm -rf "$KERNEL_PLATFORM"; mkdir -p "$KERNEL_PLATFORM"
echo "==> Fetching fixed OnePlus kernel source commit"
git init -q "$COMMON_DIR"
git -C "$COMMON_DIR" remote add origin "$SOURCE_REPO"
git -C "$COMMON_DIR" fetch --depth=1 origin "$SOURCE_REF"
git -C "$COMMON_DIR" checkout --detach -q FETCH_HEAD

SOURCE_COMMIT=$(git -C "$COMMON_DIR" rev-parse HEAD)
[[ "$SOURCE_COMMIT" == "$SOURCE_REF" ]] || die "Source pin mismatch: expected $SOURCE_REF, got $SOURCE_COMMIT"
VERSION=$(awk -F= '/^VERSION[[:space:]]*=/{gsub(/[[:space:]]/,"",$2);print $2}' "$COMMON_DIR/Makefile")
PATCHLEVEL=$(awk -F= '/^PATCHLEVEL[[:space:]]*=/{gsub(/[[:space:]]/,"",$2);print $2}' "$COMMON_DIR/Makefile")
SUBLEVEL=$(awk -F= '/^SUBLEVEL[[:space:]]*=/{gsub(/[[:space:]]/,"",$2);print $2}' "$COMMON_DIR/Makefile")
KERNEL_VERSION="$VERSION.$PATCHLEVEL.$SUBLEVEL"
[[ "$KERNEL_VERSION" == "$EXPECTED_KERNEL_VERSION" ]] || die "Pinned source is $KERNEL_VERSION, expected $EXPECTED_KERNEL_VERSION"
{
 echo "SOURCE_COMMIT=$SOURCE_COMMIT"
 echo "SOURCE_BRANCH=$SOURCE_BRANCH_NOTE"
 echo "KERNEL_VERSION=$KERNEL_VERSION"
} >> "$GITHUB_ENV"
echo "Verified kernel: $KERNEL_VERSION"
echo "Source commit: $SOURCE_COMMIT"

mkdir -p "$KERNEL_PLATFORM/clang18"
curl -fL --retry 5 --retry-delay 3 "$CLANG_URL" -o "$WORK_DIR/clang.zip"
unzip -q "$WORK_DIR/clang.zip" -d "$KERNEL_PLATFORM/clang18"; rm -f "$WORK_DIR/clang.zip"
curl -fL --retry 5 --retry-delay 3 "$BUILD_TOOLS_URL" -o "$WORK_DIR/build-tools.zip"
unzip -q "$WORK_DIR/build-tools.zip" -d "$KERNEL_PLATFORM"; rm -f "$WORK_DIR/build-tools.zip"
CLANG_BIN="$KERNEL_PLATFORM/clang18/bin"; BUILD_TOOLS_BIN="$KERNEL_PLATFORM/build-tools/bin"
[[ -x "$CLANG_BIN/clang" ]] || die "clang not found after extraction"
{ echo "CLANG_BIN=$CLANG_BIN"; echo "BUILD_TOOLS_BIN=$BUILD_TOOLS_BIN"; } >> "$GITHUB_ENV"
"$CLANG_BIN/clang" --version | head -n1
