#!/usr/bin/env python3
"""Puts two folders of same-named screenshots side by side, half size, for
judging a change by eye: BEFORE on the left, AFTER on the right.

    python3 tools/shots/side_by_side.py BEFORE_DIR AFTER_DIR OUT_DIR
"""
import os
import sys

from PIL import Image


def main() -> None:
    before, after, out = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)
    for name in sorted(os.listdir(after)):
        if not name.endswith(".png") or not os.path.exists(os.path.join(before, name)):
            continue
        a = Image.open(os.path.join(before, name)).convert("RGB")
        b = Image.open(os.path.join(after, name)).convert("RGB")
        w, h = a.width // 2, a.height // 2
        sheet = Image.new("RGB", (w * 2 + 8, h), (20, 20, 20))
        sheet.paste(a.resize((w, h), Image.NEAREST), (0, 0))
        sheet.paste(b.resize((w, h), Image.NEAREST), (w + 8, 0))
        sheet.save(os.path.join(out, name))


if __name__ == "__main__":
    main()
