#!/usr/bin/env python3
"""Patch xcodegen-generated schemes to embed the StoreKit configuration
file reference in <TestAction> (xcodegen only emits it for LaunchAction).

Idempotent: safe to run multiple times. Run after `xcodegen generate`.
"""
import sys
from pathlib import Path

SCHEME_PATH = Path(__file__).resolve().parent.parent / "Moove.xcodeproj" / "xcshareddata" / "xcschemes" / "Moove.xcscheme"
STOREKIT_REF = '      <StoreKitConfigurationFileReference\n         identifier = "../../Resources/Moove.storekit">\n      </StoreKitConfigurationFileReference>\n'


def patch() -> int:
    if not SCHEME_PATH.exists():
        print(f"patch-scheme: {SCHEME_PATH} not found", file=sys.stderr)
        return 1
    text = SCHEME_PATH.read_text()
    test_section = text.split("<TestAction")[1].split("</TestAction>")[0]
    if "StoreKitConfigurationFileReference" in test_section:
        print("patch-scheme: TestAction already has StoreKit config — nothing to do")
        return 0
    test_close = "   </TestAction>"
    if test_close not in text:
        print("patch-scheme: </TestAction> not found", file=sys.stderr)
        return 1
    text = text.replace(test_close, STOREKIT_REF + test_close, 1)
    SCHEME_PATH.write_text(text)
    print("patch-scheme: added StoreKitConfigurationFileReference to TestAction")
    return 0


if __name__ == "__main__":
    raise SystemExit(patch())
