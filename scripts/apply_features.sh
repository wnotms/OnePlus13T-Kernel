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
ENABLE_O2="${ENABLE_O2:-false}"
ENABLE_LZ4_ZSTD="${ENABLE_LZ4_ZSTD:-false}"
ENABLE_BBR="${ENABLE_BBR:-false}"
ENABLE_BETTER_NET="${ENABLE_BETTER_NET:-false}"
ENABLE_REKERNEL="${ENABLE_REKERNEL:-false}"
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


# ===== 可选性能/功能优化 =====
# 与当前 6.6.89 SM8750 社区构建保持同源；所有选项默认关闭。
if [[ "$ENABLE_O2" == "true" ]]; then
 add_config "CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y"
 echo "ENABLE_O2_KCFLAGS=true" >> "$GITHUB_ENV"
fi

if [[ "$ENABLE_LZ4_ZSTD" == "true" ]]; then
 echo "==> 应用 LZ4 1.10 + ZSTD 1.5.7 优化"
 download_patch "$OPT_PATCH_BASE/zram_patch/001-lz4.patch" "$WORK_DIR/patches/001-lz4.patch"
 download_patch "$OPT_PATCH_BASE/zram_patch/002-zstd.patch" "$WORK_DIR/patches/002-zstd.patch"
 curl -fL --retry 5 "$OPT_PATCH_BASE/zram_patch/lz4armv8.S" -o "$WORK_DIR/patches/lz4armv8.S"
 cp -f "$WORK_DIR/patches/lz4armv8.S" "$COMMON_DIR/lib/lz4armv8.S"
 # 与补丁来源项目保持相同的应用方式：
 # 001-lz4.patch 使用 git apply；002-zstd.patch 允许最多 3 级上下文 fuzz。
 # 之前统一走 patch --dry-run 的严格模式会导致 LZ4 补丁在同一 6.6.89 基线上误判失败。
 if git -C "$COMMON_DIR" apply --check -p1 "$WORK_DIR/patches/001-lz4.patch"; then
  git -C "$COMMON_DIR" apply -p1 "$WORK_DIR/patches/001-lz4.patch"
  notice "LZ4 1.10 patch applied"
 else
  die "LZ4 1.10 patch failed (git apply --check)"
 fi
 if patch --batch --forward -d "$COMMON_DIR" -p1 -F3 --dry-run < "$WORK_DIR/patches/002-zstd.patch"; then
  patch --batch --forward -d "$COMMON_DIR" -p1 -F3 < "$WORK_DIR/patches/002-zstd.patch"
  notice "ZSTD 1.5.7 patch applied"
 else
  die "ZSTD 1.5.7 patch failed"
 fi
fi

if [[ "$ENABLE_BBR" == "true" ]]; then
 for cfg in CONFIG_TCP_CONG_ADVANCED=y CONFIG_TCP_CONG_BBR=y CONFIG_TCP_CONG_CUBIC=y; do add_config "$cfg"; done
fi

if [[ "$ENABLE_BETTER_NET" == "true" ]]; then
 for cfg in CONFIG_BPF_STREAM_PARSER=y CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y CONFIG_NETFILTER_XT_SET=y CONFIG_IP_SET=y CONFIG_IP_SET_MAX=65534 CONFIG_IP_SET_BITMAP_IP=y CONFIG_IP_SET_BITMAP_IPMAC=y CONFIG_IP_SET_BITMAP_PORT=y CONFIG_IP_SET_HASH_IP=y CONFIG_IP_SET_HASH_IPMARK=y CONFIG_IP_SET_HASH_IPPORT=y CONFIG_IP_SET_HASH_IPPORTIP=y CONFIG_IP_SET_HASH_IPPORTNET=y CONFIG_IP_SET_HASH_IPMAC=y CONFIG_IP_SET_HASH_MAC=y CONFIG_IP_SET_HASH_NETPORTNET=y CONFIG_IP_SET_HASH_NET=y CONFIG_IP_SET_HASH_NETNET=y CONFIG_IP_SET_HASH_NETPORT=y CONFIG_IP_SET_HASH_NETIFACE=y CONFIG_IP_SET_LIST_SET=y; do add_config "$cfg"; done
fi

if [[ "$ENABLE_REKERNEL" == "true" ]]; then
 # 当前 cctv18 6.6.89 风驰源码已携带 Re:Kernel 实现时只需打开配置；
 # 若源码没有对应 Kconfig，olddefconfig 后的严格校验会失败，避免生成“假开启”内核。
 add_config "CONFIG_REKERNEL=y"
fi

if [[ "${PURE_KERNEL:-false}" == "true" ]]; then
 [[ ! -s "$FEATURE_CONFIG" ]] || die "Pure mode generated feature config"
 [[ -z "$(git -C "$COMMON_DIR" status --porcelain)" ]] || die "Pure mode modified source tree"
fi
cat "$FEATURE_CONFIG" || true