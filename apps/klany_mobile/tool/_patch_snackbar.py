#!/usr/bin/env python3
"""Migrate ScaffoldMessenger snackbars to context.showKlanySnackBar (+ import)."""

import pathlib
import re
import sys

LIB_SRC = pathlib.Path(__file__).resolve().parent.parent / "lib" / "src"


def import_line_for(path: pathlib.Path) -> str:
    rel = path.relative_to(LIB_SRC)
    depth = len(rel.parent.parts)
    up = "../" * depth
    return f"import '{up}core/app_snackbar.dart';"


FILES = [
    "features/auth/pages/join_family_code_page.dart",
    "features/auth/pages/child_request_access_page.dart",
    "features/auth/pages/parent_sign_in_page.dart",
    "features/auth/pages/recover_access_page.dart",
    "features/notifications/pages/notifications_page.dart",
    "features/wallet/pages/parent_wallets_page.dart",
    "features/wallet/pages/child_wallet_page.dart",
    "features/shop/pages/parent_shop_page.dart",
    "features/shop/pages/child_shop_page.dart",
    "features/quests/pages/child_quests_page.dart",
    "features/home/pages/parent_access_requests_page.dart",
    "features/home/avatar_store.dart",
    "features/home/pages/parent_family_settings_page.dart",
    "features/quests/pages/parent_quests_page.dart",
]


def patch_text(text: str) -> str:
    text = text.replace(
        "ScaffoldMessenger.of(context).showSnackBar(", "context.showKlanySnackBar("
    )
    text = text.replace(
        "ScaffoldMessenger.of(dialogCtx).showSnackBar(",
        "dialogCtx.showKlanySnackBar(",
    )
    text = text.replace("ScaffoldMessenger.of(ctx).showSnackBar(", "ctx.showKlanySnackBar(")
    ml2 = (
        ("ScaffoldMessenger.of(context)\n          .showSnackBar(", "context.showKlanySnackBar("),
        ("ScaffoldMessenger.of(context)\n        .showSnackBar(", "context.showKlanySnackBar("),
        ("ScaffoldMessenger.of(context)\n      .showSnackBar(", "context.showKlanySnackBar("),
        (
            "ScaffoldMessenger.of(\n        context,\n      ).showSnackBar(",
            "context.showKlanySnackBar(",
        ),
        (
            "ScaffoldMessenger.of(\n      context,\n    ).showSnackBar(",
            "context.showKlanySnackBar(",
        ),
        (
            "ScaffoldMessenger.of(\n      context\n    )\n      .showSnackBar(",
            "context.showKlanySnackBar(",
        ),
    )
    for a, b in ml2:
        text = text.replace(a, b)

    rx = re.compile(
        r" *\n *final messenger = ScaffoldMessenger\.of\(context\);\s*\n", re.MULTILINE
    )
    text = rx.sub("\n", text)
    text = text.replace("messenger.showSnackBar(", "context.showKlanySnackBar(")

    return text


def insert_import(text: str, inj: str) -> str:
    if "core/app_snackbar.dart" in text:
        return text
    lines = text.splitlines(keepends=True)
    insert_at = 0
    for i, ln in enumerate(lines):
        if ln.startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, inj + "\n")
    return "".join(lines)


def main() -> None:
    for rel in FILES:
        p = LIB_SRC / rel
        if not p.exists():
            print("missing", p, file=sys.stderr)
            continue
        orig = p.read_text(encoding="utf-8")
        text = patch_text(orig)
        if "showKlanySnackBar(" in text and text != orig:
            text = insert_import(text, import_line_for(p))
            p.write_text(text, encoding="utf-8")
            print("ok", rel)


if __name__ == "__main__":
    main()
