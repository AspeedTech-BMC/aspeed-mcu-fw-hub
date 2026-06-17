# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT

def _basename(path):
    return path.split("/")[-1]

def bmc_pb_target(pb):
    _outs = [_basename(src) for src in pb]

    _cmd_lines = ["set -e"]
    for src in pb:
        _cmd_lines.append(
            "install -m 644 $$MY_BAZEL_BASE/bmc-pb/{} $(@D)/{}".format(src, _basename(src))
        )
    cmd = "\n".join(_cmd_lines)

    native.genrule(
        name = "bmc-pb",
        srcs = ["@bmc_pb//:all"],
        outs = _outs,
        cmd = cmd,
        local = True,
        visibility = ["//visibility:public"],
    )
