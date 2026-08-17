# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT

def pldm_package(name, firmware_image, manifest_template, out, visibility = None):
    cmd = "\n".join([
        "set -e",
        "OUT=$$(realpath $(@D))/{}".format(out),
        "FIRMWARE_IMAGE=$$(realpath $(location {}))".format(firmware_image),
        "PLDM_TMPDIR=$$(mktemp -d)",
        "trap 'rm -rf $$PLDM_TMPDIR' EXIT",
        "PLDM_MANIFEST=$$PLDM_TMPDIR/pldm-package.toml",
        "sed \"s|@@IMAGE_LOCATION@@|$$FIRMWARE_IMAGE|\" $(location {}) > $$PLDM_MANIFEST".format(manifest_template),
        "source $$CARGO_HOME/env",
        "cd $$MY_BAZEL_BASE/caliptra-mcu-sw",
        "cargo xtask pldm-firmware create --manifest $$PLDM_MANIFEST --file $$OUT",
        "echo \"Generated $$OUT\"",
    ])

    native.genrule(
        name = name,
        srcs = [
            firmware_image,
            manifest_template,
            "@caliptra_mcu_sw//:all",
        ],
        outs = [out],
        cmd = cmd,
        local = True,
        visibility = visibility,
    )
