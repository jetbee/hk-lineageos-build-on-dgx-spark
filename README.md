# hk-lineageos-build-on-dgx-spark

**English** | [日本語](README.ja.md)

Steps and notes for building LineageOS 24.0 (Android 17) on an NVIDIA DGX Spark (ARM64, Ubuntu 24.04).

The only officially supported build host for AOSP and LineageOS is x86_64. This is an unofficial
experiment, and the results come with no guarantee.

## Results

| Date | Target | Source | Result | Time |
|---|---|---|---|---|
| 2026-10-04 | Kernel: `LineageOS/android_kernel_asus_sdm660` (config for the Asus X00TD) | lineage-24.0 @ `a598e30e2dd2` (4.19.325) | **Success** (host clang 18) | about 135 s |
| 2026-10-04 | Same, host gcc 13 | same | Failed (see "Known problems") | n/a |
| 2026-10-05 | Whole Android: `lineage_X00TD-cp2a-userdebug` → `m bacon` | lineage-24.0 | **Success** (LFI verification on; limits in "Step 2") | total not measured |
| 2026-10-05 onward | Another sdm660 phone (its device tree is not public): the whole `userdebug` build and the five images `system`, `system_ext`, `product`, `vendor`, `odm` | lineage-24.0, same patches | **Success** (same limits; no new patches) | first full pass 13 min 40 s, reusing the X00TD outputs; later five-image builds were incremental |

This record shows that the build passes. It does not show that the result is the same as an official
build: the binaries differ (see the comparison below).

## Environment

| Item | Value |
|---|---|
| Machine | NVIDIA DGX Spark (DGX OS 7.2.3) |
| CPU | 20 cores (Cortex-X925 x10 + Cortex-A725 x10) |
| Memory | 128 GB (LPDDR5x, shared by CPU and GPU) |
| OS | Ubuntu 24.04.4 LTS, Linux 6.17.0-1031-nvidia, aarch64 |
| Disk | 5 GB for the kernel only. The whole of Android is about 220 GB of source plus build output (plan for 400 GB or more) |

Installed packages (standard Ubuntu 24.04 repositories, versions of 2026-10-04):

| Package | Version |
|---|---|
| clang / lld / llvm | 1:18.0-59~exp2 (clang 18.1.3) |
| device-tree-compiler | 1.7.0-2build1 |
| libssl-dev | 3.0.13-0ubuntu3.16 |
| libelf-dev | 0.190-1.1ubuntu0.1 |
| lz4 | 1.9.4-1build1.1 |
| ccache | 4.9.1-1 |
| gcc (for reference) | 4:13.2.0-7ubuntu1 |
| make / bison / flex / m4 / bc / cpio | 4.3 / 3.8.2 / 2.6.4 / 1.4.19 / 1.07.1 / 2.15 |

## Step 1: the kernel

LineageOS's 4.19 sdm660 kernel targets arm64, so on a DGX Spark it builds natively with the host's own
tools. The x86_64 AOSP prebuilts (clang, kernel-build-tools) are not needed.

```sh
git clone https://github.com/jetbee/hk-lineageos-build-on-dgx-spark
cd hk-lineageos-build-on-dgx-spark

# 1. Install the packages (needs sudo)
./scripts/setup-host.sh

# 2. Get the source (about 1.4 GB)
git clone --depth=1 -b lineage-24.0 \
  https://github.com/LineageOS/android_kernel_asus_sdm660 ~/src/android_kernel_asus_sdm660

# 3. Build (X00TD configuration)
./scripts/build-kernel.sh ~/src/android_kernel_asus_sdm660 X00TD
#   -> ~/src/android_kernel_asus_sdm660/out-X00TD/arch/arm64/boot/Image.gz-dtb

# 4. (optional) Make a set to use as a prebuilt kernel
./scripts/package-kernel.sh ~/src/android_kernel_asus_sdm660 out-X00TD
#   -> Image.gz-dtb, config, kernel-headers/, BUILD_INFO.txt, SHA256SUMS
```

What `build-kernel.sh` does:

```sh
CFG="vendor/sdm660-perf_defconfig vendor/common.config vendor/debugfs.config vendor/X00TD.config"
make O=out-X00TD ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang $CFG
make O=out-X00TD ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang -j$(nproc)
```

- The host is aarch64, so `CROSS_COMPILE` is not needed.
- The output is `Image.gz-dtb` (Image.gz with the dtb appended; the same as `BOARD_KERNEL_IMAGE_NAME` in the X00TD device tree).
- Official LineageOS builds use the AOSP prebuilt clang. This uses Ubuntu's clang 18, so the result is not binary-identical.

## Step 2: the whole of Android

`m bacon` for `lineage_X00TD-cp2a-userdebug` ran to the end on a DGX Spark (2026-10-05, source lineage-24.0).
The build was resumed many times while the failures were fixed, so the total time was not measured (the last two
resumes took 6 to 14 minutes each, incrementally). The five images of another sdm660 phone (its device tree is
not public) then built with the same patches and no additional fixes.
**This is not an official build.** Please read "Limits" below.

### Procedure

1. Packages: `scripts/setup-host.sh` (`imagemagick` and `python3-pil` are for the boot-animation `mogrify`).
2. Source: `repo sync` lineage-24.0 (about 220 GB including the X00TD local_manifests and blobs).
3. ARM64 prebuilts: `scripts/fetch-arm64-prebuilts.sh` (clang, Go, Rust, JDK 21; fetched from the official
   distribution points; versions, URLs and sha256 values are recorded in `SOURCES.txt`).
4. Rust: `scripts/make-rust-musl-toolchain.sh` (assembles a musl rustc; the reason is at the top of the script).
5. Make the prebuilts visible to the tree: `scripts/place-arm64-prebuilts.sh` (symlinks only).
6. Apply the aarch64-host fixes: `scripts/apply-patches.sh <tree>` (`git am` of the 16 patches for 13 projects in
   `patches/`; provide a committer name and e-mail through the environment or `git config`).
7. bison: after applying the patches, rename `prebuilts/build-tools/linux-arm64/bin/bison` to `bison.real`
   and install `scripts/bison-arm64-wrapper.sh` as an executable `bison` (the binary is not part of the patches).
8. Build: `scripts/build-full.sh <tree> lineage_X00TD-cp2a-userdebug <log>` (the default target is `bacon`).
   For images only: `scripts/build-images.sh <tree> <lunch target> <log> systemimage vendorimage ...`.

Note: `make-rust-musl-toolchain.sh` and `build-images.sh` (on a dummy tree: automatic `-j` and the stale-timestamp
guard) were each checked on their own. `place-arm64-prebuilts.sh` and `apply-patches.sh` bundle the operations done by
hand for this record; the patches were checked to apply to the commit just before the first local commit
(`git apply --check`, and the applied result equals the original branch). Running all of it on a fresh tree in one go has
not been checked.

### What was fixed, and why (summary; each patch in `patches/` has a longer description)

| Where | What |
|---|---|
| `build/make` | Treat aarch64 as `HOST_ARCH=arm64` / `linux-arm64`. Make `HOST_OUT` match Soong's. Add `clang/HOST_arm64.mk` |
| `build/soong` | Rust on the host (musl std, `RUSTC_BOOTSTRAP=1`), `host_second_srcs` (there is no 32-bit host), the install location of Common modules, put the musl loader and libc++ into the sandbox (bison, m4, ...), drop x86-only compiler options (`-msse3` and others) |
| `prebuilts/build-tools` | Add arm64 targets for bison, flex, m4 and make. bison finds its data relative to its own path, so a wrapper fills that in (`bison.real`) |
| `prebuilts/jdk/jdk21`, `tools-lineage`, `clang/host/linux-x86` | Point javap, mogrify (Pillow stand-in if ImageMagick is missing) and the llvm tools at arm64 |
| `vendor/lineage` | Build the kernel's host tools with the machine's libc and the system lz4 (and pahole if present), not an x86 sysroot and lz4 |
| `bionic` | Make the kernel-header cleaning tool read the arm64 libclang |
| `system/sepolicy` | Receive the result of `getopt()` in an `int`, not a `char` (on aarch64 `char` is unsigned, so the comparison with `-1` never ends the loop; a global `-fsigned-char` broke toybox and was not used) |
| `system/librustutils`, `prebuilts/rust-toolchain`, `external/rust` | Use the prebuilt std (with its matching proc_macro) on an arm64 host as well. `aarch64-paging` is enabled for the device only |
| `frameworks/libs/binary_translation` | Enable the berberis generators on the arm64 host (so that analysis passes; the x86 emulator is not built) |

Environment variables (set by `scripts/build-images.sh`): `SOONG_NINJA=ninja` (siso is x86-only),
`SKIP_ABI_CHECKS=true` (there is no arm64 `header-abi-dumper`), `SOONG_DISABLE_CLIPPY=true` (there is no arm64
`clippy-driver`), `THINLTO_USE_MLGO=false` (the arm64 clang has no MLGO model), `OUT_DIR=out` (an absolute path
stops Soong in a few places; use a symlink named `out` to put the output on another disk). The build runs in a clean
environment (`env -i`) so that shell functions such as a `grep` replacement cannot get into the build scripts.

### Limits (where this differs from an official build)

- **Mind the clang name**: LineageOS selects `clang-r596125` (the release setting in `vendor/lineage`). Google has not
  published an arm64 build of it, so this record uses `clang-r584948b` (22.0.1) under the names `clang-r596125` and
  `clang-stable`. The tree says r596125; what runs is r584948b. MLGO (machine-learned optimization) is off. Because
  of this, native code is not binary-identical to an official build (see the comparison below).
- **LFI** (Android 17's lightweight sandbox): the LFI rewriter of r584948b does not rewrite the `dc zva` in
  `memset`, and the newer `lfi-verify` stops with `dc zva must use x28` (the `memset` part of `libopus`). This record
  borrowed a `libopus_lfi_bin` that had passed verification, built with r596125 on an x86 host, and passed with
  **verification still on**. The borrowed binary is not included in this repository (it is a build artifact with no
  reproducible way to obtain it). Skipping the verification is possible, but such a build cannot be distributed or
  submitted officially, so it is not covered here.
- **When an arm64 `clang-r596125` appears**: (1) fetch it and re-point `clang-r596125` and `clang-stable`, (2) stop
  using the borrowed LFI binary, (3) remove `THINLTO_USE_MLGO=false`. That should be all.
- ImageMagick (`mogrify`): `apt install imagemagick`. The tree's arm64 `mogrify` calls the system `/usr/bin/mogrify`
  when it exists and otherwise stands in with Pillow (boot-animation pixels may differ slightly).
- The build sandbox (nsjail) is x86-only. "Build sandboxing disabled due to nsjail error" is printed; this is expected (sbox is still used).

### Things to watch

- **Stale timestamps**: if a project is updated with a copy that keeps modification times, such as `rsync -a`, a file changed
  during the previous build can look older than the previous output, ninja skips it, and the image keeps the old content.
  `scripts/build-images.sh` touches the files that changed since the last successfully built commit in the projects listed in
  `STALE_REPOS` before it starts.
- **`-j` and memory**: memory is shared with other work. `build-images.sh` uses available memory divided by 3 GB (at
  least 2, at most `nproc`). The 3 GB is a rule of thumb, **not a measurement**. `-j20` on a 128 GB machine ran without
  running out of memory. The peak was not measured.
- A failed build can be resumed with the same command (incremental). Stopping at the first failure is ninja's default.

### Comparison with an x86 build (X00TD)

Per-file checksum comparison (`rsync -rnc` dry run, symlinks excluded).

| Kind | Files | Different | Same |
|---|---:|---:|---:|
| Native (.so, bin) | 3003 | 1921 | 1082 |
| Other (apex, data) | 3577 | 55 | 3522 |
| Text / config | 977 | 9 | 968 |
| dex2oat (odex, vdex, art) | 518 | 355 | 163 |
| Media / fonts | 507 | 0 | 507 |
| apk | 174 | 66 | 108 |
| jar / dex | 56 | 4 | 52 |
| Total | 8812 | 2410 | 6402 (72.7%) |

- The set of files is the same (no file exists on only one side).
- The only texts that differ are the `build.prop` family (date, host, fingerprint) and `build-manifest.xml`.
- Native code, the apexes that contain it, and the dex2oat output that depends on it differ because of the compiler (clang version and MLGO).
- Four jars, such as `framework.jar`, differ only in `classes.dex`. The javac output and `d8.jar` are identical; the cause is unknown.
- Conclusion: binary identity cannot be expected because the compiler is different. Parts that do not depend on the native compiler or on build metadata are identical.

## Known problems and limits

- **Not officially supported**: the supported build host for AOSP and LineageOS is x86_64 only. These steps can break with upstream updates.
- **The kernel does not build with gcc 13**: `kernel/sched/walt.h` and `include/trace/events/sched.h` stop with `-Werror=format` because of printf format and argument type mismatches. Qualcomm's code assumes clang, so use clang.
- **libssl-dev is needed**: without it the build stops at `scripts/extract-cert.c` with "openssl/bio.h not found".
- **When updating the source**: warnings from a newer clang may stop the build under `-Werror`. Start from the recorded versions (tables above).

## What is in this repository

| Path | Contents |
|---|---|
| `scripts/setup-host.sh` | Install the packages |
| `scripts/build-kernel.sh` | Build the sdm660 kernel |
| `scripts/package-kernel.sh` | Make a prebuilt-kernel set |
| `scripts/fetch-arm64-prebuilts.sh` | Fetch the arm64 prebuilts (clang, Go, Rust, JDK) and record where they came from |
| `scripts/make-rust-musl-toolchain.sh` | Rust for an arm64 host (musl rustc with a loader wrapper) |
| `scripts/place-arm64-prebuilts.sh` | Symlinks that make the arm64 prebuilts visible to the tree |
| `scripts/apply-patches.sh` | Apply `patches/` to the tree with `git am` |
| `scripts/bison-arm64-wrapper.sh` | Wrapper that lets the arm64 bison find its data |
| `scripts/build-images.sh` | Build images in a clean environment with automatic `-j` and the stale-timestamp guard |
| `scripts/build-full.sh` | Call `build-images.sh` to build everything (`bacon`) |
| `patches/` | The arm64-host fixes (one `git am` patch set per project; 16 patches for 13 projects) |
| `tools/dts-extract.py` | Extract one node from a DTS decompiled by dtc and rewrite phandle numbers as labels |
| `tools/dt-devname-hashes.py`, `tools/dsi-cmds-format.py` | Small helpers for investigating device trees |
| `VERIFICATION.md` | What was checked before publishing, and what was not |

## Sources

- Actinis, "Building AOSP on ARM64: From an 8 GB Jetson to DGX Spark" (2026-06-26) https://actinis.io/blog/building-aosp-on-arm64
  — the list of fixes for building AOSP on an ARM64 host, and the build time on a DGX Spark (2 h 13 min).
  The fixes in this repository were written anew with the article's approach in mind; no diff from the article is included.
- LineageOS https://github.com/LineageOS

## License

Apache License 2.0 (`LICENSE`).
