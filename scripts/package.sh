#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
IMAGE="$ARTIFACT_DIR/Image"; [[ -f "$IMAGE" ]] || die "Missing built Image"
AK3_DIR="$WORK_DIR/AnyKernel3"; rm -rf "$AK3_DIR"
git clone --filter=blob:none --no-checkout "$ANYKERNEL_REPO" "$AK3_DIR"
git -C "$AK3_DIR" checkout "$ANYKERNEL_REF"; rm -rf "$AK3_DIR/.git"; cp -f "$IMAGE" "$AK3_DIR/Image"
FEATURE_TAG="pure"; [[ "${PURE_KERNEL:-true}" != "true" ]] && FEATURE_TAG="custom"
ZIP_NAME="OnePlus13T_${KERNEL_VERSION:-6.6.89}_$FEATURE_TAG.zip"
(cd "$AK3_DIR" && zip -qr9 "$ARTIFACT_DIR/$ZIP_NAME" . -x '*.git*' '*.zip')
sha256sum "$ARTIFACT_DIR/$ZIP_NAME" > "$ARTIFACT_DIR/$ZIP_NAME.sha256"
echo "Created: $ARTIFACT_DIR/$ZIP_NAME"
