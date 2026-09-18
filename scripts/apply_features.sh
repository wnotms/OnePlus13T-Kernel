#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

ROOT_SOLUTION="${ROOT_SOLUTION:-none}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
ENABLE_DROIDSPACES="${ENABLE_DROIDSPACES:-false}"
ENABLE_NTSYNC="${ENABLE_NTSYNC:-false}"
ENABLE_SCX="${ENABLE_SCX:-false}"
ENABLE_BBG="${ENABLE_BBG:-false}"
ENABLE_ADIOS="${ENABLE_ADIOS:-false}"
: > "$FEATURE_CONFIG"; mkdir -p "$WORK_DIR/patches"

remote_patch(){ local url="$1" name="$2" dst="$WORK_DIR/patches/$2"; download_patch "$url" "$dst"; apply_patch_file "$dst" "$name" || die "Cannot apply requested patch: $name"; }

case "$ROOT_SOLUTION" in
 none) ;;
 kernelsu_next) (cd "$KERNEL_PLATFORM"; curl -fLSs --retry 5 "$KSUN_SETUP_URL" | bash); add_config "CONFIG_KSU=y" ;;
 resukisu) (cd "$KERNEL_PLATFORM"; curl -fLSs --retry 5 "$RESUKISU_SETUP_URL" | bash -s main); add_config "CONFIG_KSU=y" ;;
 *) die "Unsupported ROOT_SOLUTION: $ROOT_SOLUTION" ;;
esac

if [[ "$ENABLE_SUSFS" == "true" ]]; then
 [[ "$ROOT_SOLUTION" == "resukisu" ]] || die "SUSFS requires ReSukiSU in this builder"
 git clone --depth=1 --branch "$SUSFS_REF" "$SUSFS_REPO" "$WORK_DIR/susfs4oki"
 cp -f "$WORK_DIR/susfs4oki/kernel_patches/fs/"* "$COMMON_DIR/fs/"
 cp -f "$WORK_DIR/susfs4oki/kernel_patches/include/linux/"* "$COMMON_DIR/include/linux/"
 apply_patch_file "$WORK_DIR/susfs4oki/kernel_patches/50_add_susfs_in_gki-android15-6.6.patch" "SUSFS" || die "SUSFS patch failed"
 add_config "CONFIG_KSU_SUSFS=y"
fi

if [[ "$ENABLE_DROIDSPACES" == "true" ]]; then
 echo "==> Integrating Droidspaces"
 git clone --depth=1 --branch "$DROIDSPACES_REF" "$DROIDSPACES_REPO" "$WORK_DIR/Droidspaces-OSS"
 DS_PATCH="$WORK_DIR/Droidspaces-OSS/Documentation/resources/kernel-patches/GKI/below-kernel-6.12/001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch"
 apply_patch_file "$DS_PATCH" "Droidspaces SYSVIPC kABI" || die "Droidspaces SYSVIPC patch failed"
 remote_patch "$SM8750_PATCH_BASE/droidspaces_patch/fix_oplus_bsp_midas.patch" "fix_oplus_bsp_midas.patch"
 for cfg in CONFIG_PID_NS=y CONFIG_SYSVIPC=y CONFIG_POSIX_MQUEUE=y CONFIG_IPC_NS=y CONFIG_DEVTMPFS=y CONFIG_NAMESPACES=y CONFIG_BINFMT_MISC=y CONFIG_BINFMT_SCRIPT=y CONFIG_BINFMT_ELF=y CONFIG_USER_NS=y CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y CONFIG_NETFILTER_XT_TARGET_LOG=y CONFIG_NETFILTER_XT_MATCH_RECENT=y CONFIG_BT_HCIVHCI=m; do add_config "$cfg"; done
fi

if [[ "$ENABLE_NTSYNC" == "true" ]]; then
 remote_patch "$SM8750_PATCH_BASE/droidspaces_patch/ntsync_base.patch" "ntsync_base.patch"
 remote_patch "$SM8750_PATCH_BASE/droidspaces_patch/ntsync_compat_android15-6.6.patch" "ntsync_compat_android15-6.6.patch"
 add_config "CONFIG_NTSYNC=y"
fi

if [[ "$ENABLE_SCX" == "true" ]]; then
 echo "==> 验证 cctv18 6.6.89 风驰/HMBIRD 源码"
 [[ -f "$COMMON_DIR/kernel/sched/hmbird/hmbird.c" ]] || die "HMBIRD implementation missing"
 [[ -f "$COMMON_DIR/include/linux/sched/hmbird.h" ]] || die "HMBIRD public header missing"
 grep -qx 'CONFIG_HMBIRD_SCHED=y' "$COMMON_DIR/arch/arm64/configs/gki_defconfig" || die "CONFIG_HMBIRD_SCHED is not enabled in gki_defconfig"
 add_config "CONFIG_HMBIRD_SCHED=y"
 echo "FENGCHI_STATUS=enabled_cctv18_6.6.89" >> "$GITHUB_ENV"
 notice "使用 cctv18 SM8750 6.6.89 已移植风驰源码；不再应用不兼容的 Numbersf 整体补丁"
fi

if [[ "$ENABLE_BBG" == "true" ]]; then
 (cd "$COMMON_DIR"; curl -fLSs --retry 5 "$BBG_SETUP_URL" | bash)
fi
if [[ "$ENABLE_ADIOS" == "true" ]]; then
 remote_patch "$ADIOS_PATCH_URL" "adios_ioscheduler_6.6.patch"
 add_config "CONFIG_MQ_IOSCHED_ADIOS=y"; add_config "CONFIG_MQ_IOSCHED_DEFAULT_ADIOS=y"
fi

if [[ "${PURE_KERNEL:-false}" == "true" ]]; then
 [[ ! -s "$FEATURE_CONFIG" ]] || die "Pure mode generated feature config"
 [[ -z "$(git -C "$COMMON_DIR" status --porcelain)" ]] || die "Pure mode modified source tree"
fi
cat "$FEATURE_CONFIG" || true