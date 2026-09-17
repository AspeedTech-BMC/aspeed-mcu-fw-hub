# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT

_TOOL = "target/tools/cptra_2x"

def manifest_targets(platform, chip, ssmcu_runtime_target, bmc_pb_target,
                     manifest_cfg, cm4_target = None, bootmcu_target = None,
                     name = "manifest",
                     out_namespace = None,
                     flash_image_out = "aspeed-manifest-flash-image.bin",
                     serialize_after = None):
    _IMAGE_PREFIX = "{}-default".format(chip)
    _MANIFEST_CFG = manifest_cfg
    _MANIFEST_CFG_IS_LABEL = manifest_cfg.startswith("//") or manifest_cfg.startswith(":")
    # Distinct out_namespace/flash_image_out needed if calling this twice
    # for the same chip — two genrules can't share an output path.
    _OUT_NS = out_namespace or _IMAGE_PREFIX
    _REC = "recovery/{}".format(_OUT_NS)

    _srcs = [
        ssmcu_runtime_target,
        bmc_pb_target,
        "@cptra_imgtool//:all",
        "@caliptra_mcu_sw//:all",
    ]
    if _MANIFEST_CFG_IS_LABEL:
        _srcs.append(manifest_cfg)
    if cm4_target != None:
        _srcs.append(cm4_target)
    if bootmcu_target != None:
        _srcs.append(bootmcu_target)
    if serialize_after != None:
        # Both builds run `rm -rf out/` in the same shared cptra_imgtool
        # checkout; force this one to run after serialize_after to avoid
        # the two racing and corrupting each other's output.
        _srcs.append(serialize_after)

    _install_input_lines = [
        # Fixed name: the manifest toml expects "zephyr-shell-module.bin" /
        # "ssmcu-runtime.bin" in prebuilt-dir regardless of these targets'
        # own output filenames.
        "install -m 644 $(location {}) $$STAGE/ssmcu-runtime.bin".format(ssmcu_runtime_target),
        "install -m 644 $(locations {}) $$STAGE/".format(bmc_pb_target),
    ]
    if cm4_target != None:
        _install_input_lines.append(
            "install -m 644 $(location {}) $$STAGE/zephyr-shell-module.bin".format(cm4_target)
        )
    if bootmcu_target != None:
        _install_input_lines.append(
            "install -m 644 $(location {}) $$STAGE/".format(bootmcu_target)
        )

    _setup_lines = [
        "set -e",
        "EXECROOT=$$(pwd)",
        "BAZEL_OUT=$$EXECROOT/$$(dirname $(location {}))".format(flash_image_out),
        "STAGE=$$MY_BAZEL_BASE/.stage/{}/{}".format(platform, name),
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
        "cargo build -p caliptra-mcu-xtask --target-dir $$TOOL_TARGET",
        "install -D -m 755 $$TOOL_TARGET/debug/caliptra-mcu-xtask $$IMGTOOL/target/debug/xtask-2x",
    ]

    if _MANIFEST_CFG_IS_LABEL:
        _MANIFEST_CFG_ARG = "$$EXECROOT/$(location {})".format(_MANIFEST_CFG)
    else:
        # Backward compatibility for configs stored under cptra_imgtool/config.
        _MANIFEST_CFG_ARG = _MANIFEST_CFG

    _run_lines = [
        "cd $$IMGTOOL",
        "rm -rf out/",
        "cargo run create-auth-flash-2x --cfg {} --pqc-key-type 1 --prebuilt-dir $$STAGE".format(_MANIFEST_CFG_ARG),
    ]

    _install_lines = [
        "install -D -m 644 $$IMGTOOL/out/$$IMAGE_PREFIX-flash-image.bin $$BAZEL_OUT/{}".format(flash_image_out),
        ("install -D -m 644 $$IMGTOOL/out/$$IMAGE_PREFIX-auth-manifest.bin"
         + " $$BAZEL_OUT/{}/{}-auth-manifest.bin".format(_REC, _OUT_NS)),
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
        flash_image_out,
        "{}/{}-auth-manifest.bin".format(_REC, _OUT_NS),
        "{}/fw_toc.bin".format(_REC),
        "{}/caliptra-fw_align_256.bin".format(_REC),
        "{}/ssmcu-runtime_align_256.bin".format(_REC),
    ]
    if cm4_target != None:
        _outs.append("{}/zephyr-shell-module_align_256.bin".format(_REC))
    if bootmcu_target != None:
        _outs.append("{}/zephyr-mcu-runtime_align_256.bin".format(_REC))

    native.genrule(
        name = name,
        srcs = _srcs,
        outs = _outs,
        cmd = cmd,
        local = True,
    )
