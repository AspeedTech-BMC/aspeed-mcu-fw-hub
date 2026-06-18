# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT

_TOOL = "target/tools/cptra_2x"

def manifest_targets(platform, chip, cm4_target, ssmcu_runtime_target, bmc_pb_target,
                     manifest_cfg, bootmcu_target = None):
    _IMAGE_PREFIX = "{}-default".format(chip)
    _MANIFEST_CFG = manifest_cfg
    _REC = "recovery/{}".format(_IMAGE_PREFIX)

    _srcs = [
        cm4_target,
        ssmcu_runtime_target,
        bmc_pb_target,
        "@cptra_imgtool//:all",
        "@caliptra_mcu_sw//:all",
    ]
    if bootmcu_target != None:
        _srcs.append(bootmcu_target)

    _install_input_lines = [
        "install -m 644 $(location {}) $$STAGE/".format(cm4_target),
        "install -m 644 $(location {}) $$STAGE/".format(ssmcu_runtime_target),
        "install -m 644 $(locations {}) $$STAGE/".format(bmc_pb_target),
    ]
    if bootmcu_target != None:
        _install_input_lines.append(
            "install -m 644 $(location {}) $$STAGE/".format(bootmcu_target)
        )

    _setup_lines = [
        "set -e",
        "EXECROOT=$$(pwd)",
        "BAZEL_OUT=$$EXECROOT/$$(dirname $(location aspeed-manifest-flash-image.bin))",
        "STAGE=$$MY_BAZEL_BASE/.stage/{}/manifest".format(platform),
        "rm -rf $$STAGE",
        "mkdir -p $$STAGE",
        "source $$CARGO_HOME/env",
        "IMGTOOL=$$MY_BAZEL_BASE/cptra_imgtool",
        "MCU_SW=$$MY_BAZEL_BASE/caliptra-mcu-sw",
        "TOOL_TARGET=$$IMGTOOL/{}".format(_TOOL),
        "IMAGE_PREFIX={}".format(_IMAGE_PREFIX),
    ] + _install_input_lines

    _build_manifest_app_lines = [
        "cd $$IMGTOOL",
        "cargo build -p caliptra-auth-manifest-app-2x --target-dir $$TOOL_TARGET",
        ("install -D -m 755 $$TOOL_TARGET/debug/caliptra-auth-manifest-app-2x"
         + " $$IMGTOOL/target/debug/caliptra-auth-manifest-app-2x"),
    ]

    _build_xtask_lines = [
        "cd $$MCU_SW",
        "cargo build -p xtask --target-dir $$TOOL_TARGET",
        "install -D -m 755 $$TOOL_TARGET/debug/xtask $$IMGTOOL/target/debug/xtask-2x",
    ]

    _run_lines = [
        "cd $$IMGTOOL",
        "rm -rf out/",
        "cargo run create-auth-flash-2x --cfg {} --pqc-key-type 1 --prebuilt-dir $$STAGE".format(_MANIFEST_CFG),
    ]

    _install_lines = [
        "install -D -m 644 $$IMGTOOL/out/$$IMAGE_PREFIX-flash-image.bin $$BAZEL_OUT/aspeed-manifest-flash-image.bin",
        ("install -D -m 644 $$IMGTOOL/out/$$IMAGE_PREFIX-auth-manifest.bin"
         + " $$BAZEL_OUT/{}/$$IMAGE_PREFIX-auth-manifest.bin".format(_REC)),
        "install -D -m 644 $$IMGTOOL/out/fw_toc.bin $$BAZEL_OUT/{}/fw_toc.bin".format(_REC),
        "cp $$IMGTOOL/out/padding_output/* $$BAZEL_OUT/{}/".format(_REC),
    ]

    cmd = "\n".join(
        _setup_lines +
        _build_manifest_app_lines +
        _build_xtask_lines +
        _run_lines +
        _install_lines
    )

    _outs = [
        "aspeed-manifest-flash-image.bin",
        "{}/{}-auth-manifest.bin".format(_REC, _IMAGE_PREFIX),
        "{}/fw_toc.bin".format(_REC),
        "{}/caliptra-fw_align_256.bin".format(_REC),
        "{}/ssmcu-runtime_align_256.bin".format(_REC),
        "{}/zephyr-shell-module_align_256.bin".format(_REC),
    ]
    if bootmcu_target != None:
        _outs.append("{}/zephyr-mcu-runtime_align_256.bin".format(_REC))

    native.genrule(
        name = "manifest",
        srcs = _srcs,
        outs = _outs,
        cmd = cmd,
        local = True,
    )
