import json
import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env.server"
SERVICE_ACCOUNT_PATH = ROOT / "apps" / "klany_mobile" / "android" / "app" / "klany-push-firebase-adminsdk-fbsvc-1248fd1254.json"

# Provided earlier in the chat; do not print it.
DEFAULT_TELEGRAM_BOT_TOKEN = "8235976102:AAGX7QnWiCBFxxYdOnfWCgxUuyi7llBp-sc"


def parse_env(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip()
    return out


def upsert_env_lines(lines: list[str], updates: dict[str, str]) -> list[str]:
    # Keep order, update existing keys, append missing.
    seen: set[str] = set()
    out: list[str] = []
    for raw in lines:
        if raw.lstrip().startswith("#") or "=" not in raw:
            out.append(raw)
            continue
        k = raw.split("=", 1)[0].strip()
        if k in updates:
            out.append(f"{k}={updates[k]}\n")
            seen.add(k)
        else:
            out.append(raw)
    for k, v in updates.items():
        if k not in seen:
            out.append(f"{k}={v}\n")
    return out


def main() -> None:
    if not ENV_PATH.exists():
        raise SystemExit(f".env.server not found at: {ENV_PATH}")
    if not SERVICE_ACCOUNT_PATH.exists():
        raise SystemExit(f"Firebase service account json not found at: {SERVICE_ACCOUNT_PATH}")

    env_lines = ENV_PATH.read_text(encoding="utf-8", errors="ignore").splitlines(True)
    current = parse_env("".join(env_lines))

    sa = json.loads(SERVICE_ACCOUNT_PATH.read_text(encoding="utf-8", errors="ignore"))
    project_id = (sa.get("project_id") or "").strip()
    client_email = (sa.get("client_email") or "").strip()
    private_key = (sa.get("private_key") or "")
    # Store private key with escaped newlines (backend replaces \\n -> \n).
    private_key_escaped = private_key.replace("\r\n", "\n").replace("\n", "\\n").strip()

    updates: dict[str, str] = {}
    if project_id:
        updates["FIREBASE_PROJECT_ID"] = project_id
    if client_email:
        updates["FIREBASE_CLIENT_EMAIL"] = client_email
    if private_key_escaped:
        updates["FIREBASE_PRIVATE_KEY"] = private_key_escaped

    # Telegram token: set if missing or blank.
    if not (current.get("TELEGRAM_BOT_TOKEN") or "").strip():
        updates["TELEGRAM_BOT_TOKEN"] = DEFAULT_TELEGRAM_BOT_TOKEN

    new_lines = upsert_env_lines(env_lines, updates)
    ENV_PATH.write_text("".join(new_lines), encoding="utf-8")


if __name__ == "__main__":
    main()

