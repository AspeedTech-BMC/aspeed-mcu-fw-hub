# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT

def caliptra_targets(
        platform,
        ssmcu_runtime_bin,
        ssmcu_rom_bin,
        ssmcu_runtime_out = "ssmcu-runtime.bin",
        ssmcu_rom_out = None):

    _ssmcu_runtime_cmd_lines = [
        "set -e",
        "export RUSTUP_AUTO_UPDATE=0",
        "BAZEL_OUT=$$(realpath $@)",
        "source $$CARGO_HOME/env",
        "cd $$MY_BAZEL_BASE/caliptra-mcu-sw",
        "cargo xtask runtime-build --platform {}".format(platform),
        "install -D -m 644 {} $$BAZEL_OUT".format(ssmcu_runtime_bin),
    ]
    cmd = "\n".join(_ssmcu_runtime_cmd_lines)

    native.genrule(
        name = "ssmcu-runtime",
        srcs = ["@caliptra_mcu_sw//:all"],
        outs = [ssmcu_runtime_out],
        cmd = cmd,
        local = True,
        visibility = ["//visibility:public"],
    )

    _ssmcu_rom_cmd_lines = [
        "set -e",
        "export RUSTUP_AUTO_UPDATE=0",
        "BAZEL_OUT=$$(realpath $@)",
        "source $$CARGO_HOME/env",
        "cd $$MY_BAZEL_BASE/caliptra-mcu-sw",
        "cargo xtask-xip rom-build --platform {}".format(platform),
        "install -D -m 644 {} $$BAZEL_OUT".format(ssmcu_rom_bin),
    ]
    cmd = "\n".join(_ssmcu_rom_cmd_lines)

    native.genrule(
        name = "ssmcu-rom",
        srcs = ["@caliptra_mcu_sw//:all", ":ssmcu-runtime"],
        outs = [ssmcu_rom_out],
        cmd = cmd,
        local = True,
        visibility = ["//visibility:public"],
    )
