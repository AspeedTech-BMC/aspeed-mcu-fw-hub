# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def _zephyr_west_build_impl(ctx):
    if ctx.attr.role == "cm4":
        board = ctx.attr._cm4_zephyr_board_flag[BuildSettingInfo].value or ctx.attr.board
        app = ctx.attr._cm4_zephyr_app_flag[BuildSettingInfo].value or ctx.attr.app
    else:
        board = ctx.attr._bootmcu_zephyr_board_flag[BuildSettingInfo].value or ctx.attr.board
        app = ctx.attr._bootmcu_zephyr_app_flag[BuildSettingInfo].value or ctx.attr.app

    if not board:
        fail("zephyr board not set.")
    if not app:
        fail("zephyr app not set.")

    out = ctx.outputs.output_bin
    build_dir = "build/{}/{}".format(ctx.label.package, ctx.label.name)
    base = "$MY_BAZEL_BASE"

    srcs = depset(transitive = [s[DefaultInfo].files for s in ctx.attr.srcs])

    ctx.actions.run_shell(
        inputs = srcs,
        outputs = [out],
        command = "\n".join([
            "set -e",
            "BAZEL_OUT=$(realpath {})".format(out.path),
            "source {}/.venv/zephyr/bin/activate".format(base),
            "cd {}/zephyr-workspace".format(base),
            "west build -p always -b {} -d {} {}".format(board, build_dir, app),
            "install -D -m 644 {}/zephyr/zephyr.bin $BAZEL_OUT".format(build_dir),
        ]),
        use_default_shell_env = True,
        execution_requirements = {"local": "1"},
        mnemonic = "ZephyrWestBuild",
        progress_message = "west build {} (board={}, app={})".format(ctx.label.name, board, app),
    )

    return [DefaultInfo(files = depset([out]))]


_zephyr_west_build_rule = rule(
    implementation = _zephyr_west_build_impl,
    attrs = {
        "board": attr.string(default = ""),
        "app": attr.string(default = ""),
        "role": attr.string(default = "cm4"),
        "srcs": attr.label_list(allow_files = True),
        "output_bin": attr.output(mandatory = True),
        "_cm4_zephyr_board_flag": attr.label(
            default = "//flags:cm4_zephyr_board",
            providers = [BuildSettingInfo],
        ),
        "_cm4_zephyr_app_flag": attr.label(
            default = "//flags:cm4_zephyr_app",
            providers = [BuildSettingInfo],
        ),
        "_bootmcu_zephyr_board_flag": attr.label(
            default = "//flags:bootmcu_zephyr_board",
            providers = [BuildSettingInfo],
        ),
        "_bootmcu_zephyr_app_flag": attr.label(
            default = "//flags:bootmcu_zephyr_app",
            providers = [BuildSettingInfo],
        ),
    },
)


def zephyr_west_build(name, board, app, output_bin, role = "cm4", visibility = None):
    _zephyr_west_build_rule(
        name = name,
        board = board,
        app = app,
        role = role,
        srcs = ["@zephyr_ws//:all"],
        output_bin = output_bin,
        visibility = visibility,
    )
