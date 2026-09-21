# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT

def pldm_package(
        name,
        firmware_image,
        manifest_template,
        metadata_v1_0,
        version_config,
        out,
        visibility = None):
    cmd = "\n".join([
        "set -e",
        "OUT=$$(realpath $(@D))/{}".format(out),
        "FIRMWARE_IMAGE=$$(realpath $(location {}))".format(firmware_image),
        "VERSION_CONFIG=$(location {})".format(version_config),
        "PLDM_TMPDIR=$$(mktemp -d)",
        "trap 'rm -rf $$PLDM_TMPDIR' EXIT",
        "if grep -qx 'CONFIG_PLDM_FW_UPDATE_VERSION_1_0=y' $$VERSION_CONFIG; then",
        "  python3 $(location @zephyr_ws//:pfr_pldm_fwu_pkg_v1_tool) $$OUT $(location {}) $$FIRMWARE_IMAGE".format(metadata_v1_0),
        "elif grep -qx 'CONFIG_PLDM_FW_UPDATE_VERSION_1_3=y' $$VERSION_CONFIG; then",
        "  PLDM_MANIFEST=$$PLDM_TMPDIR/pldm-package.toml",
        "  sed \"s|@@IMAGE_LOCATION@@|$$FIRMWARE_IMAGE|\" $(location {}) > $$PLDM_MANIFEST".format(manifest_template),
        "  source $$CARGO_HOME/env",
        "  cd $$MY_BAZEL_BASE/caliptra-mcu-sw",
        "  cargo xtask pldm-firmware create --manifest $$PLDM_MANIFEST --file $$OUT",
        "else",
        "  echo 'Exactly one PLDM firmware update version must be selected in' $$VERSION_CONFIG >&2",
        "  exit 1",
        "fi",
        "echo \"Generated $$OUT\"",
    ])

    native.genrule(
        name = name,
        srcs = [
            firmware_image,
            manifest_template,
            metadata_v1_0,
            version_config,
            "@zephyr_ws//:pfr_pldm_fwu_pkg_v1_tool",
            "@caliptra_mcu_sw//:all",
        ],
        outs = [out],
        cmd = cmd,
        local = True,
        visibility = visibility,
    )
