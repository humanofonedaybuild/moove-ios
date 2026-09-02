#!/usr/bin/env python3
"""Patch xcodegen-generated schemes so the StoreKit configuration file
reference resolves correctly in <LaunchAction>.

xcodegen emits `identifier = "../../Resources/Moove.storekit"`, but Xcode
resolves `StoreKitConfigurationFileReference.identifier` relative to the
project directory (the folder containing the `.xcodeproj`, i.e. the repo
root). With xcodegen's path the reference never resolves, storekitd never
binds the config to the app, and every `Product.products(for:)` call
returns an empty list. The correct identifier is `Resources/Moove.storekit`.

IMPORTANT — the reference must NOT be attached to the Moove scheme's
<TestAction>: the unit tests (SubscriptionStoreKitTests,
SubscriptionManagerFallbackTests) create `SKTestSession` in-process, and
a scheme-attached StoreKit config invalidates those sessions
(SKInternalErrorDomain), which is what made the subscription tests fail
historically. UI tests use the separate `MooveUITests` scheme, which does
carry the reference in <TestAction>.

Idempotent: safe to run multiple times. Run after `xcodegen generate`.
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CORRECT_IDENTIFIER = "Resources/Moove.storekit"
XCODEGEN_IDENTIFIER = "../../Resources/Moove.storekit"

REFERENCE_BLOCK = (
    "      <StoreKitConfigurationFileReference\n"
    f"         identifier = \"{CORRECT_IDENTIFIER}\">\n"
    "      </StoreKitConfigurationFileReference>\n"
)


def _reference_block_for(action_text: str) -> str:
    m = re.search(
        r"\s*<StoreKitConfigurationFileReference\b.*?</StoreKitConfigurationFileReference>",
        action_text,
        flags=re.DOTALL,
    )
    return m.group(0) if m else ""


def patch_action(text: str, action_name: str, add_if_missing: bool) -> tuple[str, bool, bool]:
    """Fix/insert/remove the StoreKit reference inside an action.

    Returns (new_text, changed, removed)."""
    open_tag, close_tag = f"<{action_name}", f"</{action_name}>"
    start = text.find(open_tag)
    if start == -1:
        print(f"patch-scheme: <{action_name}> not found", file=sys.stderr)
        return text, False, False
    end = text.find(close_tag, start)
    if end == -1:
        print(f"patch-scheme: </{action_name}> not found", file=sys.stderr)
        return text, False, False

    action_text = text[start:end]
    existing = _reference_block_for(action_text)
    if existing and CORRECT_IDENTIFIER in existing:
        return text, False, False  # already correct
    if existing:
        new_action = action_text.replace(existing, "\n" + REFERENCE_BLOCK)
    elif add_if_missing:
        new_action = action_text.rstrip() + "\n" + REFERENCE_BLOCK
    else:
        return text, False, False
    return text[:start] + new_action + text[end:], True, False


def strip_reference_from_action(text: str, action_name: str) -> tuple[str, bool]:
    """Remove any StoreKit reference from an action (session-conflict guard)."""
    open_tag, close_tag = f"<{action_name}", f"</{action_name}>"
    start = text.find(open_tag)
    if start == -1 or text.find(close_tag, start) == -1:
        return text, False
    end = text.find(close_tag, start)
    action_text = text[start:end]
    existing = _reference_block_for(action_text)
    if not existing:
        return text, False
    new_action = action_text.replace(existing, "")
    return text[:start] + new_action + text[end:], True


def patch_scheme(path: Path) -> int:
    if not path.exists():
        print(f"patch-scheme: {path} not found", file=sys.stderr)
        return 1
    text = path.read_text()
    changed = False

    if path.name == "Moove.xcscheme":
        # Unit-test scheme: fix <LaunchAction>, strip <TestAction>.
        text, c, _ = patch_action(text, "LaunchAction", add_if_missing=True)
        if c:
            print("patch-scheme: fixed StoreKitConfigurationFileReference in <LaunchAction>")
        text, removed = strip_reference_from_action(text, "TestAction")
        if removed:
            print("patch-scheme: removed StoreKitConfigurationFileReference from <TestAction> (SKTestSession conflict)")
        changed = changed or c or removed
    elif path.name == "MooveUITests.xcscheme":
        # UI-test scheme: bind the config for the run + the app launch.
        text, c, _ = patch_action(text, "LaunchAction", add_if_missing=True)
        if c:
            print("patch-scheme: fixed StoreKitConfigurationFileReference in <LaunchAction>")
        text, c2, _ = patch_action(text, "TestAction", add_if_missing=True)
        if c2:
            print("patch-scheme: fixed StoreKitConfigurationFileReference in <TestAction>")
        changed = changed or c or c2

    if XCODEGEN_IDENTIFIER in text:
        text = text.replace(XCODEGEN_IDENTIFIER, CORRECT_IDENTIFIER)
        changed = True
        print("patch-scheme: normalised stray xcodegen identifier")

    if changed:
        path.write_text(text)
    else:
        print(f"patch-scheme: {path.name} — nothing to do")
    return 0


def patch() -> int:
    status = 0
    for scheme in ("Moove.xcscheme", "MooveUITests.xcscheme"):
        rc = patch_scheme(
            REPO / "Moove.xcodeproj" / "xcshareddata" / "xcschemes" / scheme
        )
        status = status or rc
    return status


if __name__ == "__main__":
    raise SystemExit(patch())
