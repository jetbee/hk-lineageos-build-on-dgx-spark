# Verification record (2026-10-12)

What was checked before this repository is published, and what was not.

## Patches (`patches/`, 13 projects, 16 patches)
- Each project's patches were generated from the local `dgx-arm64` commits and then given
  descriptive subjects and bodies (no "WIP"); the only trailer is `Assisted-by: LLM`.
- For every project, the patches apply (`git apply --cached --check`, then applied) to the commit
  just before the first local commit, and the resulting tree is identical to the local branch.
  One exception by design: in `prebuilts/build-tools` the two bison binaries (`bison` and
  `bison.real`) are not part of the patches (see step 7 of "Procedure" in the README).
- The patches contain no binary hunks.

## Scripts
- `bash -n` passes for the new and changed scripts.
- `build-images.sh` / `build-full.sh` were run against a dummy tree (a stub `envsetup.sh` with
  `lunch` and `m`): the environment is clean (`OUT_DIR=out`, `SOONG_NINJA=ninja`,
  `THINLTO_USE_MLGO=false`), `-j` is chosen automatically (and overridden by `JOBS`), a file with an old
  modification time that differs from the last built commit is touched, and the last built commit
  is recorded only after a successful run. They were not run against a full Android tree in this form;
  the full builds in the README were run with the earlier hand-written equivalents.
- `place-arm64-prebuilts.sh` and `apply-patches.sh` were not run end to end on a fresh tree.

## Build results quoted in the README
- X00TD `m bacon` and the second device's images were built on the DGX Spark with the same patch set
  (build logs are kept privately and are not published). The x86 comparison table is from the
  checksum dry run recorded on 2026-10-05.

## Audit for content that must not be published
The published history is a single commit. The working tree and that commit (file contents and the
commit message) were searched for: personal names and user names, home directory paths other than
`~/`, IP addresses and host names, VPN names, e-mail addresses other than the GitHub no-reply
address, keys and tokens, IMEI / serial numbers, vendor / stock firmware file names or hashes, GApps,
private kernel kits, IMS vendor files, internal project names and session names, and co-author trailers.
Result: no hits, except
- the author address `7734987+jetbee@users.noreply.github.com` (the public no-reply address),
- the device names X00TD and sdm660 (public LineageOS device / SoC),
- the general words in this paragraph's own list.
No binary files above 100 kB, no firmware, no images.

Not published on purpose: the borrowed `libopus_lfi_bin` build artifact, any vendor / stock blob,
GApps, the private device tree of the second device, build logs, and the images.
