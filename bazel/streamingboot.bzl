# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT

def streamingboot_i3c_targets(
        chip,
        caliptra_fw_target,
        ssmcu_runtime_target,
        auth_manifest_target,
        gen_script,
        runner,
        readme,
        pldm_manifest_template = None,
        pldm_output_name = None,
        flash_image_target = ":aspeed-manifest-flash-image.bin"):
    _IMAGE_PREFIX = "{}-default".format(chip)
    _STAGE = "streamingboot-i3c"
    _PLDM_NAME = pldm_output_name or "{}-cm4-test.pldm".format(chip)

    _srcs = [
        caliptra_fw_target,
        ssmcu_runtime_target,
        auth_manifest_target,
        gen_script,
        runner,
        readme,
    ]

    _outs = [
        "{}/caliptra-fw_align_256.bin".format(_STAGE),
        "{}/{}-auth-manifest.bin".format(_STAGE, _IMAGE_PREFIX),
        "{}/ssmcu-runtime_align_256.bin".format(_STAGE),
        "{}/run_streaming_boot.sh".format(_STAGE),
        "{}/README.md".format(_STAGE),
    ]

    _cmd_lines = [
        "set -e",
        "OUTDIR=$(@D)/{}".format(_STAGE),
        "python3 $(location {}) \\".format(gen_script),
        "  --caliptra-fw $$(realpath $(location {})) \\".format(caliptra_fw_target),
        "  --auth-manifest $$(realpath $(location {})) \\".format(auth_manifest_target),
        "  --ssmcu-runtime $$(realpath $(location {})) \\".format(ssmcu_runtime_target),
        "  --runner $$(realpath $(location {})) \\".format(runner),
        "  --readme $$(realpath $(location {})) \\".format(readme),
        "  --image-prefix {} \\".format(_IMAGE_PREFIX),
        "  --output-dir $$OUTDIR",
    ]

    if pldm_manifest_template != None:
        _srcs.append(pldm_manifest_template)
        _srcs.append(flash_image_target)
        _srcs.append("@caliptra_mcu_sw//:all")
        _outs.append("{}/{}".format(_STAGE, _PLDM_NAME))
        _cmd_lines += [
            "FLASH_IMAGE=$$(realpath $(location {}))".format(flash_image_target),
            "OUTDIR_ABS=$$(realpath $$OUTDIR)",
            "PLDM_TMPDIR=$$(mktemp -d)",
            "trap 'rm -rf $$PLDM_TMPDIR' EXIT",
            "PLDM_MANIFEST=$$PLDM_TMPDIR/{}-pldm-package.toml".format(chip),
            "sed \"s|@@IMAGE_LOCATION@@|$$FLASH_IMAGE|\" $(location {}) > $$PLDM_MANIFEST".format(pldm_manifest_template),
            "source $$CARGO_HOME/env",
            "cd $$MY_BAZEL_BASE/caliptra-mcu-sw",
            "cargo xtask pldm-firmware create --manifest $$PLDM_MANIFEST --file $$OUTDIR_ABS/{}".format(_PLDM_NAME),
        ]

    native.genrule(
        name = "image-streamingboot-i3c",
        srcs = _srcs,
        outs = _outs,
        cmd = "\n".join(_cmd_lines),
        local = True,
    )
