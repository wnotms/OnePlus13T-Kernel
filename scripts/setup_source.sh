#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

rm -rf "$KERNEL_PLATFORM"; mkdir -p "$KERNEL_PLATFORM"

ACTIVE_SOURCE_REPO="$SOURCE_REPO"
ACTIVE_SOURCE_REF="$SOURCE_REF"
ACTIVE_SOURCE_BRANCH="$SOURCE_BRANCH_NOTE"
if [[ "${ENABLE_SCX:-false}" == "true" ]]; then
 ACTIVE_SOURCE_REPO="$FENGCHI_SOURCE_REPO"
 ACTIVE_SOURCE_REF="$FENGCHI_SOURCE_REF"
 ACTIVE_SOURCE_BRANCH="$FENGCHI_SOURCE_BRANCH_NOTE"
 echo "==> 风驰已启用：使用 cctv18 SM8750 6.6.89 HMBIRD/风驰移植源码"
else
 echo "==> 获取固定的一加 13T 6.6.89 官方 common 源码"
fi

git init -q "$COMMON_DIR"
git -C "$COMMON_DIR" remote add origin "$ACTIVE_SOURCE_REPO"
git -C "$COMMON_DIR" fetch --depth=1 origin "$ACTIVE_SOURCE_REF"
git -C "$COMMON_DIR" checkout --detach -q FETCH_HEAD

SOURCE_COMMIT=$(git -C "$COMMON_DIR" rev-parse HEAD)
if [[ "${ENABLE_SCX:-false}" != "true" ]]; then
 [[ "$SOURCE_COMMIT" == "$SOURCE_REF" ]] || die "Source pin mismatch: expected $SOURCE_REF, got $SOURCE_COMMIT"
else
 [[ -f "$COMMON_DIR/kernel/sched/hmbird/hmbird.c" ]] || die "风驰源码缺少 kernel/sched/hmbird/hmbird.c"
 [[ -f "$COMMON_DIR/include/linux/sched/hmbird.h" ]] || die "风驰源码缺少 include/linux/sched/hmbird.h"
 grep -qx 'CONFIG_HMBIRD_SCHED=y' "$COMMON_DIR/arch/arm64/configs/gki_defconfig" || die "风驰源码未默认启用 CONFIG_HMBIRD_SCHED"
fi
VERSION=$(awk -F= '/^VERSION[[:space:]]*=/{gsub(/[[:space:]]/,"",$2);print $2}' "$COMMON_DIR/Makefile")
PATCHLEVEL=$(awk -F= '/^PATCHLEVEL[[:space:]]*=/{gsub(/[[:space:]]/,"",$2);print $2}' "$COMMON_DIR/Makefile")
SUBLEVEL=$(awk -F= '/^SUBLEVEL[[:space:]]*=/{gsub(/[[:space:]]/,"",$2);print $2}' "$COMMON_DIR/Makefile")
KERNEL_VERSION="$VERSION.$PATCHLEVEL.$SUBLEVEL"
[[ "$KERNEL_VERSION" == "$EXPECTED_KERNEL_VERSION" ]] || die "Pinned source is $KERNEL_VERSION, expected $EXPECTED_KERNEL_VERSION"
{
 echo "SOURCE_COMMIT=$SOURCE_COMMIT"
 echo "SOURCE_BRANCH=$ACTIVE_SOURCE_BRANCH"
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
