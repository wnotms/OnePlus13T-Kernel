#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
CLANG_BIN="${CLANG_BIN:-$KERNEL_PLATFORM/clang18/bin}"
BUILD_TOOLS_BIN="${BUILD_TOOLS_BIN:-$KERNEL_PLATFORM/build-tools/bin}"
export PATH="/usr/lib/ccache:$CLANG_BIN:$BUILD_TOOLS_BIN:$PATH"
export ARCH=arm64 SUBARCH=arm64 LLVM=1 LLVM_IAS=1
export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache_oneplus13t}" CCACHE_MAXSIZE=8G CCACHE_COMPILERCHECK=none CCACHE_NOHASHDIR=true CCACHE_BASEDIR="$ROOT_DIR"
mkdir -p "$CCACHE_DIR"; ccache -M "$CCACHE_MAXSIZE" >/dev/null || true
cd "$COMMON_DIR"; rm -rf "$OUT_DIR"; mkdir -p "$OUT_DIR"
EXTRA_KCFLAGS=()
if [[ "${ENABLE_O2_KCFLAGS:-false}" == "true" ]]; then EXTRA_KCFLAGS+=("KCFLAGS=-O2"); fi
make -j"$(nproc)" O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 CC="ccache clang" LD=ld.lld HOSTLD=ld.lld "${EXTRA_KCFLAGS[@]}" gki_defconfig
if [[ -s "$FEATURE_CONFIG" ]]; then
 while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  key="${line%%=*}"; value="${line#*=}"; symbol="${key#CONFIG_}"
  case "$value" in y) scripts/config --file "$OUT_DIR/.config" -e "$symbol";; m) scripts/config --file "$OUT_DIR/.config" -m "$symbol";; n) scripts/config --file "$OUT_DIR/.config" -d "$symbol";; *) scripts/config --file "$OUT_DIR/.config" --set-val "$symbol" "$value";; esac
 done < "$FEATURE_CONFIG"
 make -j"$(nproc)" O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 CC="ccache clang" LD=ld.lld HOSTLD=ld.lld "${EXTRA_KCFLAGS[@]}" olddefconfig
 while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  grep -qxF "$line" "$OUT_DIR/.config" || die "Requested config was not preserved: $line"
 done < "$FEATURE_CONFIG"
fi
cp -f "$OUT_DIR/.config" "$ARTIFACT_DIR/kernel.config"
set -o pipefail
make -j"$(nproc)" O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 CC="ccache clang" LD=ld.lld HOSTLD=ld.lld "${EXTRA_KCFLAGS[@]}" Image 2>&1 | tee "$WORK_DIR/build.log"
IMAGE="$OUT_DIR/arch/arm64/boot/Image"; [[ -f "$IMAGE" ]] || die "Kernel Image was not produced"
cp -f "$IMAGE" "$ARTIFACT_DIR/Image"; sha256sum "$IMAGE" | tee "$ARTIFACT_DIR/Image.sha256"
KERNEL_UNAME=$(strings "$IMAGE" | grep -E 'Linux version .*#' | tail -n1 || true); printf '%s\n' "$KERNEL_UNAME" > "$ARTIFACT_DIR/kernel-uname.txt"
{
 echo "source_commit=${SOURCE_COMMIT:-unknown}"; echo "kernel_version=${KERNEL_VERSION:-unknown}"
 echo "compiler=$($CLANG_BIN/clang --version | head -n1)"; echo "root_solution=${ROOT_SOLUTION:-none}"
 echo "droidspaces=${ENABLE_DROIDSPACES:-false}"; echo "susfs=${ENABLE_SUSFS:-false}"
 echo "o2=${ENABLE_O2:-false}"; echo "lz4_zstd=${ENABLE_LZ4_ZSTD:-false}"
 echo "bbr=${ENABLE_BBR:-false}"; echo "better_net=${ENABLE_BETTER_NET:-false}"; echo "rekernel=${ENABLE_REKERNEL:-false}"
 echo "image_sha256=$(sha256sum "$IMAGE" | awk '{print $1}')"
} > "$ARTIFACT_DIR/build-info.txt"
ccache -s || true
