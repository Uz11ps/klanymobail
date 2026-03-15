import json
import os
from pathlib import Path
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env.server"


def read_env_token() -> str:
    if not ENV_PATH.exists():
        return ""
    for raw in ENV_PATH.read_text(encoding="utf-8", errors="ignore").splitlines():
        if raw.strip().startswith("#"):
            continue
        if raw.startswith("TELEGRAM_BOT_TOKEN="):
            return raw.split("=", 1)[1].strip()
    return ""


def post_json(url: str, body: dict) -> dict:
    data = json.dumps(body).encode("utf-8")
    req = Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
    with urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8", errors="ignore"))


def main() -> None:
    token = read_env_token()
    if not token:
        raise SystemExit("TELEGRAM_BOT_TOKEN is missing in .env.server")

    webhook_url = os.getenv("TELEGRAM_WEBHOOK_URL", "https://klanymobail.ru/api/webhooks/telegram").strip()

    # Set webhook.
    res = post_json(f"https://api.telegram.org/bot{token}/setWebhook", {"url": webhook_url})
    if not res.get("ok"):
        raise SystemExit(f"setWebhook failed: {res}")

    # Read webhook info (sanitized output).
    info = post_json(f"https://api.telegram.org/bot{token}/getWebhookInfo", {})
    if not info.get("ok"):
        raise SystemExit(f"getWebhookInfo failed: {info}")

    result = info.get("result") or {}
    print(json.dumps(
        {
            "ok": True,
            "webhookUrl": result.get("url"),
            "hasCustomCertificate": result.get("has_custom_certificate"),
            "pendingUpdateCount": result.get("pending_update_count"),
            "lastErrorMessage": result.get("last_error_message"),
        },
        ensure_ascii=False,
    ))


if __name__ == "__main__":
    main()

