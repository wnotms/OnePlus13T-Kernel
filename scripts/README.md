# scripts

- `common.sh` — shared paths, config helpers, strict patch helper.
- `setup_source.sh` — fetches the exact OnePlusOSS commit pinned in `configs/device.env`, verifies it is Linux 6.6.89, then installs Clang/build-tools.
- `apply_features.sh` — applies only the features selected by the workflow; pure mode requires a clean source tree.
- `build_kernel.sh` — creates `gki_defconfig`, merges selected config values, builds `Image`, and records build metadata.
- `package.sh` — creates the OnePlus 13T AnyKernel3 ZIP.
