"""The room specs of tools/hubs/build_interiors.gd, read into Python.

The builder keeps each room as a GDScript dictionary literal; those are close
enough to Python literals to evaluate once Vector2/Vector2i, true/false and
the builder's few constants are given meanings. Coordinates stay in the
builder's 16px units; the painters double them."""
from __future__ import annotations

import os
import re

from kit import ROOT

SRC = os.path.join(ROOT, "tools", "hubs", "build_interiors.gd")


def _front(room_id, label, region):
    return {"side": "front", "to": region, "label": label}


def load() -> dict[str, dict]:
    """Every room spec by id, in the builder's order."""
    src = open(SRC).read()
    out: dict[str, dict] = {}
    for fn in re.finditer(r"^func (_\w+_rooms)\(\) -> Array:\n(.*?)(?=^func |\Z)", src, re.S | re.M):
        body = fn.group(2)
        consts = dict(re.findall(r'^\tconst (\w+) := ("[^"]*"|\[[^\]]*\])', body, re.M))
        m = re.search(r"^\treturn \[(.*)^\t\]", body, re.S | re.M)
        if not m:
            continue
        lit = "[" + m.group(1) + "]"
        lit = re.sub(r"(?m)^\s*#.*$", "", lit)
        lit = re.sub(r"\bVector2i?\(", "(", lit)
        lit = lit.replace("true", "True").replace("false", "False")
        env = {"front": _front, "__builtins__": {}}
        for k, v in consts.items():
            env[k] = eval(v, {"__builtins__": {}})
        for spec in eval(lit, env):
            spec.setdefault("doors", [])
            if "outside" in spec and not any(d["side"] == "front" for d in spec["doors"]):
                spec["doors"].append({"side": "front"})
            out[spec["id"]] = spec
    return out


if __name__ == "__main__":
    import sys
    sys.path.insert(0, os.path.dirname(__file__))
    for k, v in load().items():
        print(k, v["size"], v["rows"], v["floor"], v["wall"], len(v.get("deco", [])), len(v.get("props", [])))
