# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT

def caliptra_targets(
        platform,
        ssmcu_runtime_bin,
        ssmcu_runtime_out = "ssmcu-runtime.bin",
        features = None,
        name = "ssmcu-runtime",
        serialize_after = None):

    _runtime_build_cmd = "cargo xtask runtime-build --platform {}".format(platform)
    if features != None:
        _runtime_build_cmd += " --features {}".format(features)

    _srcs = ["@caliptra_mcu_sw//:all"]
    if serialize_after != None:
        # Two calls for the same platform write to the same hardcoded
        # cargo output path in the shared caliptra-mcu-sw checkout; force
        # this one to run after serialize_after to avoid a install-time race.
        _srcs.append(serialize_after)

    _ssmcu_runtime_cmd_lines = [
        "set -e",
        "export RUSTUP_AUTO_UPDATE=0",
        "BAZEL_OUT=$$(realpath $@)",
        "source $$CARGO_HOME/env",
        "cd $$MY_BAZEL_BASE/caliptra-mcu-sw",
        _runtime_build_cmd,
        "install -D -m 644 {} $$BAZEL_OUT".format(ssmcu_runtime_bin),
    ]
    cmd = "\n".join(_ssmcu_runtime_cmd_lines)

    native.genrule(
        name = name,
        srcs = _srcs,
        outs = [ssmcu_runtime_out],
        cmd = cmd,
        local = True,
        visibility = ["//visibility:public"],
    )
