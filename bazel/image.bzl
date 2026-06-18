# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT

def image_targets(
        platform,
        chip,
        image_size_kb,
        manifest_image,
        manifest_image_seek_kb,
        ssmcu_rom_bin = None,
        ssmcu_rom_seek_kb = 0,
        bootmcu_rom_bin = None,
        bootmcu_rom_seek_kb = 512):
    _C = chip + "-default"

    _srcs = [manifest_image]
    if ssmcu_rom_bin != None:
        _srcs.append(ssmcu_rom_bin)
    if bootmcu_rom_bin != None:
        _srcs.append(bootmcu_rom_bin)

    cmd_lines = [
        "set -e",
        "OUTDIR=$$(realpath $(@D))",
        "IMAGE=$$OUTDIR/{}.bin".format(platform),
        "IMAGE_SIZE_KB={}".format(image_size_kb),
        "MANIFEST_IMAGE=$$(realpath $(location {}))".format(manifest_image),
        "dd if=/dev/zero bs=1K count=$$IMAGE_SIZE_KB | tr '\\000' '\\377' > $$IMAGE",
    ]

    if ssmcu_rom_bin != None:
        cmd_lines.append(
            "dd if=$$(realpath $(location {})) of=$$IMAGE bs=1K seek={} conv=notrunc".format(
                ssmcu_rom_bin, ssmcu_rom_seek_kb)
        )

    if bootmcu_rom_bin != None:
        cmd_lines.append(
            "dd if=$$(realpath $(location {})) of=$$IMAGE bs=1K seek={} conv=notrunc".format(
                bootmcu_rom_bin, bootmcu_rom_seek_kb)
        )

    cmd_lines += [
        "dd if=$$MANIFEST_IMAGE of=$$IMAGE bs=1K seek={} conv=notrunc".format(
            manifest_image_seek_kb),
        "echo \"Generated $$IMAGE\"",
    ]

    cmd = "\n".join(cmd_lines)

    native.genrule(
        name = "image",
        srcs = _srcs,
        outs = [platform + ".bin"],
        cmd = cmd,
        local = True,
    )
