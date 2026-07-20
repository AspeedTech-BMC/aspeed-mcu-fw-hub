# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT
#
# QEMU is built via a single local shell action (configure/make), not a
# native Bazel build. All qemu_build/qemu_run targets are tagged "manual".

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def _qemu_build_impl(ctx):
    dist_dir = ctx.actions.declare_directory(ctx.label.name)

    # command-line override (see //flags:qemu_configure_opts) wins over the
    # configure_opts baked into the BUILD.bazel target.
    configure_opts = ctx.attr._configure_opts_flag[BuildSettingInfo].value or ctx.attr.configure_opts

    ctx.actions.run_shell(
        inputs = ctx.attr.srcs[DefaultInfo].files,
        outputs = [dist_dir],
        command = "\n".join([
            "set -e",
            "SRC=$(realpath {})".format(ctx.file.configure.dirname),
            "OUT=$(realpath {})".format(dist_dir.path),
            # Persistent build dir inside the @qemu_src checkout itself: plain
            # "bazel clean" leaves external/ alone; only "bazel clean --expunge"
            # wipes it (along with the checkout), so make can reuse previous
            # .o files across builds until an expunge.
            "BUILD_DIR=\"$SRC/_bazel_build\"",
            "mkdir -p \"$BUILD_DIR\"",
            "cd \"$BUILD_DIR\"",
            "\"$SRC\"/configure --target-list={} {} --prefix=\"$OUT\"".format(
                ctx.attr.target_list,
                configure_opts,
            ),
            "make -j$(nproc)",
            "make install",
        ]),
        use_default_shell_env = True,
        execution_requirements = {"local": "1", "no-sandbox": "1"},
        mnemonic = "QemuBuild",
        progress_message = "Building QEMU (target-list=%s, configure_opts=%s)" % (
            ctx.attr.target_list,
            configure_opts,
        ),
    )

    return [DefaultInfo(files = depset([dist_dir]))]

_qemu_build_rule = rule(
    implementation = _qemu_build_impl,
    attrs = {
        "srcs": attr.label(default = Label("@qemu_src//:all")),
        "configure": attr.label(
            default = Label("@qemu_src//:configure"),
            allow_single_file = True,
        ),
        "target_list": attr.string(default = "arm-softmmu"),
        "configure_opts": attr.string(default = ""),
        "_configure_opts_flag": attr.label(
            default = "//flags:qemu_configure_opts",
            providers = [BuildSettingInfo],
        ),
    },
)

def qemu_build(name, target_list = "arm-softmmu", configure_opts = "", **kwargs):
    tags = kwargs.pop("tags", [])
    _qemu_build_rule(
        name = name,
        target_list = target_list,
        configure_opts = configure_opts,
        tags = tags + ["manual"],
        **kwargs
    )
