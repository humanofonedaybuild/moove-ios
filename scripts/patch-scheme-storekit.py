#!/usr/bin/env python3
"""Patch xcodegen-generated schemes so the StoreKit configuration file
reference resolves correctly in <LaunchAction> and <TestAction>.

xcodegen emits `identifier = "../../Resources/Moove.storekit"`, but Xcode
resolves `StoreKitConfigurationFileReference.identifier` relative to the
project directory (the folder containing the `.xcodeproj`, i.e. the repo
root). With xcodegen's path the reference never resolves, storekitd never
binds the config to the app, and every `Product.products(for:)` call
returns an empty list — both in unit tests (SKTestSession) and in UI tests
/ app runs. The correct identifier is `Resources/Moove.storekit`.

This script also injects the reference into <TestAction> (xcodegen only
emits it for <LaunchAction>), so `xcodebuild test` picks up the config too.

Idempotent: safe to run multiple times. Run after `xcodegen generate`.
"""
import re
import sys
from pathlib import Path

SCHEME_PATH = (
    Path(__file__).resolve().parent.parent
    / "Moove.xcodeproj"
    / "xcshareddata"
    / "xcschemes"
    / "Moove.xcscheme"
)
CORRECT_IDENTIFIER = "Resources/Moove.storekit"
XCODEGEN_IDENTIFIER = "../../Resources/Moove.storekit"

REFERENCE_BLOCK = (
    "      <StoreKitConfigurationFileReference\n"
    f"         identifier = \"{CORRECT_IDENTIFIER}\">\n"
    "      </StoreKitConfigurationFileReference>\n"
)


def _reference_block_for(action_text: str) -> str:
    """Return the existing reference block text within `action_text`, or ''."""
    m = re.search(
        r"\s*<StoreKitConfigurationFileReference\b.*?</StoreKitConfigurationFileReference>",
        action_text,
        flags=re.DOTALL,
    )
    return m.group(0) if m else ""


def patch_action(text: str, action_name: str) -> tuple[str, bool]:
    """Fix the StoreKit reference inside <{action_name}>…</{action_name}>.

    Returns (new_text, changed)."""
    open_tag, close_tag = f"<{action_name}", f"</{action_name}>"
    start = text.find(open_tag)
    if start == -1:
        print(f"patch-scheme: <{action_name}> not found", file=sys.stderr)
        return text, False
    end = text.find(close_tag, start)
    if end == -1:
        print(f"patch-scheme: </{action_name}> not found", file=sys.stderr)
        return text, False

    action_text = text[start:end]
    existing = _reference_block_for(action_text)
    if existing:
        if CORRECT_IDENTIFIER in existing:
            return text, False  # already correct
        # Replace the wrong identifier (and whole block) with the correct one.
        new_action = action_text.replace(existing, "\n" + REFERENCE_BLOCK)
    else:
        # Inject the reference just before the closing tag.
        new_action = action_text.rstrip() + "\n" + REFERENCE_BLOCK
    return text[:start] + new_action + text[end:], True


def patch() -> int:
    if not SCHEME_PATH.exists():
        print(f"patch-scheme: {SCHEME_PATH} not found", file=sys.stderr)
        return 1
    text = SCHEME_PATH.read_text()
    changed = False
    for action in ("LaunchAction", "TestAction"):
        text, c = patch_action(text, action)
        if c:
            print(f"patch-scheme: fixed StoreKitConfigurationFileReference in <{action}>")
        changed = changed or c
    # Also normalise any stray xcodegen identifiers that survived (defensive).
    if XCODEGEN_IDENTIFIER in text:
        text = text.replace(XCODEGEN_IDENTIFIER, CORRECT_IDENTIFIER)
        changed = True
        print("patch-scheme: normalised stray xcodegen identifier")
    if changed:
        SCHEME_PATH.write_text(text)
    else:
        print("patch-scheme: StoreKit references already correct — nothing to do")
    return 0


if __name__ == "__main__":
    raise SystemExit(patch())
