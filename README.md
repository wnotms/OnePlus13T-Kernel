# OnePlus 13T Kernel Action — Linux 6.6.89

GitHub Actions builder for the OnePlus 13T / PKX110 / pagani (SM8750). The kernel source is **fixed to Linux 6.6.89** instead of following the moving OnePlus branch tip.

## Fixed source

- Repository: `OnePlusOSS/android_kernel_common_oneplus_sm8750`
- OnePlus branch lineage: `oneplus/sm8750_b_16.0.0_oneplus_13t`
- Fixed commit: `c3e7212c79678ea7f320f6ef86c0e4b3d13495d9`
- Expected kernel version: `6.6.89`

`setup_source.sh` checks both the exact Git SHA and `Makefile` version. If the checked-out tree is not exactly 6.6.89, the workflow stops.

## Build modes

The default is **Pure Kernel**. When `pure_kernel=true`, every third-party feature is forcibly disabled and the builder checks that the OnePlus source tree remains clean before compilation.

Available switches:

| Option | Values / default | Purpose |
|---|---|---|
| `pure_kernel` | `true` | Build without third-party patches. Overrides all feature switches. |
| `root_solution` | `none` | `none`, `kernelsu_next`, or `resukisu`. |
| `enable_susfs` | `false` | SUSFS; this repository wires it to ReSukiSU. |
| `enable_droidspaces` | `false` | Droidspaces namespaces/SYSVIPC/container support plus the SM8750 compatibility patch. |
| `enable_ntsync` | `false` | NTSync support. |
| `enable_scx` | `false` | OnePlus 13T HMBIRD/SCX scheduler patch. |
| `enable_bbg` | `false` | Baseband Guard. |
| `enable_adios` | `false` | ADIOS I/O scheduler. |
| `publish_release` | `false` | Publish Image and AnyKernel3 ZIP in GitHub Releases. |

## Pure 6.6.89 build

Open **Actions → Build OnePlus 13T Kernel 6.6.89 → Run workflow** and keep the defaults:

```text
pure_kernel=true
root_solution=none
enable_susfs=false
enable_droidspaces=false
enable_ntsync=false
enable_scx=false
enable_bbg=false
enable_adios=false
```

The result is a 6.6.89 Image built from the pinned OnePlusOSS tree without Action-added feature patches.

## Droidspaces-only build

Use:

```text
pure_kernel=false
root_solution=none
enable_susfs=false
enable_droidspaces=true
enable_ntsync=false
enable_scx=false
enable_bbg=false
enable_adios=false
```

This keeps Root/SUSFS/scheduler/BBG/ADIOS disabled and only adds Droidspaces support.

## Artifacts

Every successful build uploads:

- `Image`
- `Image.sha256`
- `OnePlus13T_6.6.89_pure.zip` or `OnePlus13T_6.6.89_custom.zip`
- ZIP SHA256
- `kernel.config`
- `kernel-uname.txt`
- `build-info.txt`
- `build.log`

The ZIP is an AnyKernel3 package that replaces the boot kernel Image while retaining the device ramdisk.

## Important compatibility note

6.6.89 is deliberately pinned even though the current OnePlus 13T branch has moved to newer 6.6.x releases. A kernel Image and the phone's vendor modules still need to be compatible. Keep a stock boot backup and verify that the target ROM/vendor stack works with this pinned kernel before relying on it as a daily kernel.

## References

The builder structure and optional feature integration were adapted from active community projects including WildKernels OnePlus/GKI builders, qdykernel's SM8750 Action, Numbersf SCHED_PATCH, and Droidspaces-OSS. Third-party components remain subject to their own upstream licenses.
