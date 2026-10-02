# QEMU

QEMU is fetched by Bazel (not manually cloned), pinned to a fixed commit.

## Switching to a different QEMU version

Edit `QEMU_COMMIT` in `/MODULE.bazel`:

```
QEMU_COMMIT = "<commit-hash>"
```

Set it to the commit hash of the upstream `qemu/qemu.git` revision you want,
then rebuild:

```
bazel build //qemu:dist
```

If any patches in `qemu/patches/` fail to apply against the new commit, see
the "Adding / updating a patch" section below for how to rebase them.

## Patches

Patches under `qemu/patches/` are applied on top of `QEMU_COMMIT`, in the
order listed in `QEMU_PATCHES` in `/MODULE.bazel`, via `patch_args = ["-p1"]`.

Naming follows `git format-patch` convention: `0001-xxx.patch`,
`0002-xxx.patch`, ... An optional `vN-` prefix (e.g. `v1-0001-xxx.patch`)
comes from `git format-patch -v<n>`, used when a patch is regenerated/revised.

### Adding / updating a patch

`git_repository` deletes `.git` from the fetched checkout after applying
patches, so `$(bazel info output_base)/external/+git_repository+qemu_src` has
no git history and cannot be used to develop or diff a change. Do all
development in a separate, ordinary clone outside this project:

1. `git clone https://github.com/qemu/qemu.git ~/work/qemu-dev && cd ~/work/qemu-dev`
   `git checkout <QEMU_COMMIT>` (the value currently in `/MODULE.bazel`).
   Iterate here with a normal manual `./configure && make` — this is much
   faster than going through Bazel for every debug cycle.
2. Once the change is confirmed working, regenerate patch files:
   `git format-patch <QEMU_COMMIT>..HEAD -o <path-to-aspeed-mcu-fw-hub>/qemu/patches/`.
3. Register each new patch file in `QEMU_PATCHES` in `/MODULE.bazel`.
4. `bazel build //qemu:dist` re-fetches a clean `QEMU_COMMIT` checkout and applies
   all patches on top — this is what actually verifies the patch applies and
   builds. If it fails to apply, go back to step 1, rebase in the separate
   clone, and regenerate the patch file.
