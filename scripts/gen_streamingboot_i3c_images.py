#!/usr/bin/env python3
"""Stage 256-byte-aligned streaming-boot-i3c images with the BMC runner."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import stat
import tempfile


ALIGNMENT = 256


def align_and_copy(source: Path, destination: Path) -> int:
    """Copy source to destination and zero-pad it to ALIGNMENT bytes."""
    size = source.stat().st_size
    padding = (-size) % ALIGNMENT
    with source.open("rb") as src, destination.open("wb") as dst:
        shutil.copyfileobj(src, dst)
        if padding:
            dst.write(b"\0" * padding)
    return size + padding


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--caliptra-fw", type=Path, required=True)
    parser.add_argument("--auth-manifest", type=Path, required=True)
    parser.add_argument("--ssmcu-runtime", type=Path, required=True)
    parser.add_argument("--runner", type=Path, required=True)
    parser.add_argument("--readme", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--image-prefix", default="ast1040a0-default")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    outputs = [
        (args.caliptra_fw, "caliptra-fw_align_256.bin"),
        (args.auth_manifest, f"{args.image_prefix}-auth-manifest.bin"),
        (args.ssmcu_runtime, "ssmcu-runtime_align_256.bin"),
    ]
    for source in [src for src, _ in outputs] + [args.runner, args.readme]:
        if not source.is_file():
            raise SystemExit(f"missing input: {source}")

    args.output_dir.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=args.output_dir.parent, prefix=".streamingboot-i3c-") as tmp:
        staging = Path(tmp)
        for source, output_name in outputs:
            size = align_and_copy(source, staging / output_name)
            assert size % ALIGNMENT == 0
        runner = staging / args.runner.name
        shutil.copyfile(args.runner, runner)
        runner.chmod(runner.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        shutil.copyfile(args.readme, staging / "README.md")

        if args.output_dir.exists():
            shutil.rmtree(args.output_dir)
        os.replace(staging, args.output_dir)


if __name__ == "__main__":
    main()
