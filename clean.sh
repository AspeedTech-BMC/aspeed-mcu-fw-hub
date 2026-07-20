#!/usr/bin/env bash
# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT
# clean.sh - remove build artefacts and/or the downloaded environment.
#
# Modes:
#   expunge  (default) bazel clean --expunge
#   env      remove everything setup.sh downloads/installs, KEEP git clones.
#            Re-run "source setup.sh" to restore the environment.
#   all      remove everything including git clones.
#            Re-run "source setup.sh" to restore.

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-expunge}" in
    expunge)
        echo "=== bazel clean --expunge ==="
        "$BASE/tools/bazel" clean --expunge
        rm -rf "$BASE/zephyr-workspace/build"
        rm -rf "$BASE/caliptra-mcu-sw/target"
        rm -rf "$BASE/cptra_imgtool/target"
        rm -rf "$BASE/cptra_imgtool/out"
        rm -rf "$BASE/.stage"
        rm -rf "$BASE/qemu-image"
        echo "Done."
        ;;
    env)
        echo "=== env clean: removing downloaded tools / env (git repos kept) ==="

        # Bazel cache + build output
        if [ -f "$BASE/tools/bazel" ]; then
            echo "  bazel clean --expunge ..."
            "$BASE/tools/bazel" clean --expunge 2>/dev/null || true
        fi

        # Staging dir
        rm -rf "$BASE/.stage"
        rm -rf "$BASE/qemu-image"

        # Downloaded / installed by setup.sh
        rm -rf "$BASE/.venv"
        rm -rf "$BASE/.cargo"
        rm -rf "$BASE/.rustup"
        rm -rf "$BASE/tools"
        rm -rf "$BASE"/zephyr-sdk-*

        # Generated config files
        rm -f "$BASE/.bazelrc.local"
        rm -f "$BASE/MODULE.bazel.lock"

        echo ""
        echo "Run 'source setup.sh' to restore the environment."
        echo "Done."
        ;;
    all)
        echo "=== all clean: removing everything including git clones ==="

        # Bazel cache
        if [ -f "$BASE/tools/bazel" ]; then
            echo "  bazel clean --expunge ..."
            "$BASE/tools/bazel" clean --expunge 2>/dev/null || true
        fi

        # Git clones
        rm -rf "$BASE/caliptra-mcu-sw"
        rm -rf "$BASE/cptra_imgtool"
        rm -rf "$BASE/bmc-pb"
        rm -rf "$BASE/zephyr-workspace"

        # Staging dir
        rm -rf "$BASE/.stage"
        rm -rf "$BASE/qemu-image"

        # Downloaded / installed by setup.sh
        rm -rf "$BASE/.venv"
        rm -rf "$BASE/.cargo"
        rm -rf "$BASE/.rustup"
        rm -rf "$BASE/tools"
        rm -rf "$BASE"/zephyr-sdk-*

        # Generated config files
        rm -f "$BASE/.bazelrc.local"
        rm -f "$BASE/MODULE.bazel.lock"

        echo ""
        echo "Done. Run 'source setup.sh' to restore everything."
        ;;
    *)
        echo "Usage: $0 [expunge|env|all]"
        echo "  expunge  (default) bazel clean --expunge"
        echo "  env      remove all downloaded tools/env; keep git clones"
        echo "  all      remove everything including git clones"
        ;;
esac
