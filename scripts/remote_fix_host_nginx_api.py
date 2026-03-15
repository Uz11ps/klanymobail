import os
import sys
import time

import paramiko


HOST = os.getenv("VPS_IP", "91.197.99.149").strip()
USER = os.getenv("VPS_USER", "root").strip() or "root"
PASSWORD = (os.getenv("VPS_PASSWORD") or "").strip()

NGINX_VHOST = os.getenv(
    "NGINX_VHOST_FILE",
    "/etc/nginx/vhosts/www-root/91-197-99-149.regru.cloud.conf",
).strip()


def _connect() -> paramiko.SSHClient:
    last_err: Exception | None = None
    for attempt in range(1, 9):
        try:
            c = paramiko.SSHClient()
            c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            c.connect(
                HOST,
                username=USER,
                password=PASSWORD,
                timeout=20,
                banner_timeout=120,
                auth_timeout=60,
                look_for_keys=False,
                allow_agent=False,
            )
            return c
        except Exception as e:
            last_err = e
            time.sleep(min(2 * attempt, 12))
    raise RuntimeError(f"SSH connect failed after retries: {last_err}")


def _run(ssh: paramiko.SSHClient, cmd: str) -> tuple[int, str, str]:
    stdin, stdout, stderr = ssh.exec_command(cmd)
    _ = stdin
    out = (stdout.read() or b"").decode("utf-8", errors="ignore")
    err = (stderr.read() or b"").decode("utf-8", errors="ignore")
    code = stdout.channel.recv_exit_status()
    return code, out, err


def must(ssh: paramiko.SSHClient, cmd: str) -> str:
    code, out, err = _run(ssh, cmd)
    if code != 0:
        msg = (err or out).strip()
        raise RuntimeError(f"Remote command failed ({code}): {cmd}\n{msg}")
    return (out or "").strip()


def main() -> int:
    if not PASSWORD:
        print("VPS_PASSWORD is required", file=sys.stderr)
        return 2

    print(f"[fix] Connecting to {USER}@{HOST} ...")
    ssh = _connect()
    try:
        # Backup file once (idempotent).
        must(
            ssh,
            f"test -f '{NGINX_VHOST}.bak' || cp -a '{NGINX_VHOST}' '{NGINX_VHOST}.bak'",
        )

        # Normalize CRLF, then fix /api location modifier and proxy_pass target.
        # We KEEP /api prefix because backend uses app.setGlobalPrefix('api').
        must(ssh, f"sed -i 's/\\r$//' '{NGINX_VHOST}'")

        # Make sure location modifier is '^~' (prefix match, no regex pitfalls).
        must(ssh, f"sed -i \"s/location ~\\^ \\/api\\//location ^~ \\/api\\//g\" '{NGINX_VHOST}'")
        must(ssh, f"sed -i \"s/location ~ \\/api\\//location ^~ \\/api\\//g\" '{NGINX_VHOST}'")

        # Ensure proxy_pass does NOT end with '/', otherwise nginx strips /api.
        must(ssh, f"sed -i \"s|proxy_pass http://127\\.0\\.0\\.1:3000/;|proxy_pass http://127.0.0.1:3000;|g\" '{NGINX_VHOST}'")

        # Make it explicit in case some block still points /api to 8782.
        must(ssh, f"sed -i \"s|proxy_pass http://127\\.0\\.0\\.1:8782;|proxy_pass http://127.0.0.1:8782;|g\" '{NGINX_VHOST}'")

        # Validate and reload nginx.
        must(ssh, "nginx -t")
        must(ssh, "systemctl reload nginx")

        # Local checks on the server.
        print("[fix] Verifying local endpoints ...")
        print(must(ssh, "curl -sS -m 5 http://127.0.0.1:3000/api/health || true"))
        print(must(ssh, "curl -sS -m 5 -i https://klanymobail.ru/api/health | head -n 12"))

        print("[fix] OK")
        return 0
    finally:
        ssh.close()


if __name__ == "__main__":
    raise SystemExit(main())

