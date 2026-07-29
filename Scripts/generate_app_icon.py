#!/usr/bin/env python3
"""Generate a macOS ICNS file from the Work Louder product PNG."""

from pathlib import Path
import struct
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Resources" / "AppIconSource.png"
OUTPUT = ROOT / "Resources" / "AppIcon.icns"
SIZES = [
    ("icp4", 16),
    ("icp5", 32),
    ("icp6", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024),
]


def main() -> None:
    chunks: list[bytes] = []
    with tempfile.TemporaryDirectory() as directory:
        temporary = Path(directory)
        for kind, size in SIZES:
            png = temporary / f"{size}.png"
            subprocess.run(
                ["/usr/bin/sips", "-z", str(size), str(size), str(SOURCE), "--out", str(png)],
                check=True,
                stdout=subprocess.DEVNULL,
            )
            payload = png.read_bytes()
            chunks.append(kind.encode("ascii") + struct.pack(">I", len(payload) + 8) + payload)

    body = b"".join(chunks)
    OUTPUT.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)
    print(f"Generated {OUTPUT}")


if __name__ == "__main__":
    main()
