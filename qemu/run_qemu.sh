#!/usr/bin/env bash
# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT
set -e

# Each fixed arg arrives as "key=value" (self-describing in Bazel's "Running
# command line" trace). Strip the "key=" prefix.
QEMU_BIN="${1#qemu_bin=}"; shift
KERNEL="${1#kernel=}"; shift
MACHINE="${1#machine=}"; shift
INTERNAL_FLASH_IMAGE="${1#internal_flash_image=}"; shift
RUN_NAME="${1#run_name=}"; shift
shift # drop the "external_option=" marker

# FMC CS0's flash model needs a writable backing file, but the internal
# flash image is a read-only build output. To keep the build output
# untouched, copy it to qemu-image/<chip><rev>-<board>-copy.bin (e.g.
# "ast1040a0-evb-copy.bin", from run_name "ast1040a0_evb"). Reused as-is if
# it already exists, so guest writes persist across reruns; delete it
# manually to reset.
IMAGE_DIR="${BUILD_WORKING_DIRECTORY:-$PWD}/qemu-image"
mkdir -p "$IMAGE_DIR"
INTERNAL_IMAGE_DST="$IMAGE_DIR/${RUN_NAME//_/-}-copy.bin"
if [ ! -f "$INTERNAL_IMAGE_DST" ]; then
    cp "$INTERNAL_FLASH_IMAGE" "$INTERNAL_IMAGE_DST"
    chmod +w "$INTERNAL_IMAGE_DST"
fi

# external_option (from qemu/BUILD.bazel) uses "__INTERNAL_FLASH_IMAGE__" as
# a placeholder for $INTERNAL_IMAGE_DST, substituted in below since the real
# path is only known once this script runs.
ARGS=()
for arg in "$@"; do
    ARGS+=("${arg//__INTERNAL_FLASH_IMAGE__/$INTERNAL_IMAGE_DST}")
done

echo "Running: $QEMU_BIN -M $MACHINE -kernel $KERNEL -serial mon:stdio -nographic -snapshot ${ARGS[*]}"

exec "$QEMU_BIN" \
    -M "$MACHINE" \
    -kernel "$KERNEL" \
    -serial mon:stdio \
    -nographic \
    -snapshot \
    "${ARGS[@]}"
