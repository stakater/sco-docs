#!/usr/bin/env python3
"""Resolve `{{ screenshot: <name> }}` directives in the docs to real images.

A directive stands in for an image PATH, so the page keeps its own alt text:

    ![The dashboard showing the organisation summary]({{ screenshot: dashboard-org-stats }})

Two ways to use this:

  * `--check` (recommended, and what CI should gate on) verifies every directive
    resolves to an image and writes nothing. The BUILD itself is handled by
    screenshots/mkdocs_hook.py, loaded via mkdocs' built-in `hooks:` key, which
    resolves directives IN MEMORY -- no source file is ever rewritten.
  * without `--check`, it rewrites the pages on disk. Only useful for inspecting the
    result, or for a pipeline that cannot load a mkdocs hook.

Why a directive at all, when the capture filenames are already deterministic?
Because it makes the contract checkable. content/images/ holds hand-committed art
too (diagrams, screenshots of third-party UIs); a plain path can silently render a
stale file and nothing notices. A directive can only resolve to an image produced
for it, and an unresolved one fails the build.

screenshots/captured/<name>.png is the only source, and there is deliberately no
fallback: falling back would publish a stale screenshot, the exact failure this
exists to prevent.

  python3 screenshots/inject.py           # resolve directives on disk
  python3 screenshots/inject.py --check   # report only, write nothing
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
CAPTURED = ROOT / "screenshots" / "captured"
GENERATED = CONTENT / "images" / "generated"

DIRECTIVE = re.compile(r"\{\{\s*screenshot:\s*([A-Za-z0-9._-]+)\s*\}\}")


def resolve_source(name: str) -> Path | None:
    """The captured image for <name>, or None. No fallback -- see module docstring."""
    captured = CAPTURED / f"{name}.png"
    return captured if captured.exists() else None


def path_for(name: str, depth: int) -> str:
    """Image path for a directive, relative to a page `depth` dirs below content/."""
    return f"{'../' * depth}images/generated/{name}.png"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="read-only: report and exit non-zero on a missing image, "
                         "without copying images or rewriting any page")
    args = ap.parse_args()

    pages = sorted(CONTENT.rglob("*.md"))
    wanted: dict[str, list[Path]] = {}
    for page in pages:
        for name in DIRECTIVE.findall(page.read_text()):
            wanted.setdefault(name, []).append(page)

    if not wanted:
        print("inject: no {{ screenshot: ... }} directives found")
        return 0

    resolved = [n for n in sorted(wanted) if resolve_source(n)]
    missing = [n for n in sorted(wanted) if not resolve_source(n)]

    print(f"inject: {len(wanted)} directives across "
          f"{len({p for ps in wanted.values() for p in ps})} pages")
    print(f"  resolved from captured/: {len(resolved)}")

    # A capture nobody references is a docs/flow mismatch in the other direction.
    if CAPTURED.is_dir():
        orphans = sorted(
            p.stem for p in CAPTURED.glob("*.png")
            if p.stem not in wanted and not p.stem.startswith("_")
        )
        if orphans:
            print(f"  WARNING: {len(orphans)} captured image(s) referenced by no "
                  f"page: {', '.join(orphans)}")

    if missing:
        print(f"\ninject: FAILED -- {len(missing)} directive(s) have no image in "
              f"screenshots/captured/ (run ./screenshots/capture.sh):", file=sys.stderr)
        for name in missing:
            pgs = ", ".join(str(p.relative_to(ROOT)) for p in wanted[name])
            print(f"  {name}  (referenced by {pgs})", file=sys.stderr)
        return 1

    if args.check:
        print("\ninject: check passed (nothing written)")
        return 0

    GENERATED.mkdir(parents=True, exist_ok=True)
    for name in resolved:
        shutil.copy2(CAPTURED / f"{name}.png", GENERATED / f"{name}.png")

    for page in pages:
        text = page.read_text()
        if not DIRECTIVE.search(text):
            continue
        # Depth from the page to content/, so the path works wherever the page lives.
        depth = len(page.relative_to(CONTENT).parent.parts)
        new = DIRECTIVE.sub(lambda m: path_for(m.group(1), depth), text)
        page.write_text(new)

    print(f"\ninject: wrote {len(wanted)} images to "
          f"{GENERATED.relative_to(ROOT)} and rewrote the directives")
    return 0


if __name__ == "__main__":
    sys.exit(main())
