#!/usr/bin/env python3
"""Pastes each character sheet's first three columns back from git HEAD.

tools/npcgen draws every sheet with all its poses; run through
`upgrade.py --fresh`, the stand and step frames come out the same as before
but for a stray pixel or two where Scale2x now sees the next pose beside them.
This keeps the frames the game has always shown exactly as they were:

    python3 tools/art32/keep_old_columns.py assets/sprites/player.png assets/sprites/npcs/*.png
"""
from __future__ import annotations

import io
import subprocess
import sys

import numpy as np
from PIL import Image

OLD_W = 96  # three 32px columns


def main() -> None:
    for path in sys.argv[1:]:
        try:
            blob = subprocess.check_output(["git", "show", "HEAD:" + path], stderr=subprocess.DEVNULL)
        except subprocess.CalledProcessError:
            continue  # a new character: nothing to keep
        old = np.array(Image.open(io.BytesIO(blob)).convert("RGBA"))
        new = np.array(Image.open(path).convert("RGBA"))
        if old.shape[0] != new.shape[0] or new.shape[1] <= OLD_W:
            continue
        new[:, :OLD_W] = old[:, :OLD_W]
        Image.fromarray(new).save(path)


if __name__ == "__main__":
    main()
