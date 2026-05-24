"""Patch host nginx for ACME webroot + renew klanymobail.ru cert."""
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

REMOTE_SCRIPT = "/opt/klanymobail/scripts/server/fix_acme_nginx.sh"


def _connect() -> paramiko.SSHClient:
    last_err: Exception | None = None
    for attempt in range(1, 9):
        try:
            c = paramiko.SSHClient()
            c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            kwargs: dict = {
                "hostname": HOST,
                "username": USER,
                "timeout": 20,
                "banner_timeout": 120,
                "auth_timeout": 60,
            }
            if PASSWORD:
                kwargs["password"] = PASSWORD
                kwargs["look_for_keys"] = False
                kwargs["allow_agent"] = False
            else:
                kwargs["look_for_keys"] = True
                kwargs["allow_agent"] = True
            c.connect(**kwargs)
            return c
        except Exception as e:
            last_err = e
            time.sleep(min(2 * attempt, 12))
    raise RuntimeError(f"SSH connect failed: {last_err}")


def _run(ssh: paramiko.SSHClient, cmd: str, *, timeout_sec: int = 600) -> tuple[int, str, str]:
    stdin, stdout, stderr = ssh.exec_command(cmd, get_pty=True)
    _ = stdin
    ch = stdout.channel
    start = time.time()
    out_chunks: list[str] = []
    err_chunks: list[str] = []

    while True:
        if ch.recv_ready():
            out_chunks.append(ch.recv(8192).decode("utf-8", errors="ignore"))
        if ch.recv_stderr_ready():
            err_chunks.append(ch.recv_stderr(8192).decode("utf-8", errors="ignore"))
        if ch.exit_status_ready():
            break
        if time.time() - start > timeout_sec:
            ch.close()
            raise RuntimeError(f"timeout after {timeout_sec}s: {cmd}")
        time.sleep(0.2)

    code = ch.recv_exit_status()
    return code, "".join(out_chunks), "".join(err_chunks)


def must(ssh: paramiko.SSHClient, cmd: str) -> str:
    code, out, err = _run(ssh, cmd)
    if code != 0:
        raise RuntimeError(f"Remote failed ({code}): {cmd}\n{err or out}")
    return (out or "").strip()


def main() -> int:
    print(f"[acme] SSH {USER}@{HOST} ...")
    ssh = _connect()
    try:
        # Upload inline fix if repo script missing on server.
        must(
            ssh,
            f"test -f '{REMOTE_SCRIPT}' || test -f /opt/klany/current/scripts/server/fix_acme_nginx.sh",
        )
        script = REMOTE_SCRIPT
        code, out, _ = _run(
            ssh,
            f"test -x '{REMOTE_SCRIPT}' && echo ok || test -f '{REMOTE_SCRIPT}' && echo ok",
        )
        if code != 0:
            alt = "/opt/klany/current/scripts/server/fix_acme_nginx.sh"
            code2, _, _ = _run(ssh, f"test -f '{alt}' && echo ok")
            if code2 == 0:
                script = alt

        # If no script on server, pipe local file via base64.
        code, _, _ = _run(ssh, f"test -f '{script}'")
        if code != 0:
            local = os.path.join(
                os.path.dirname(__file__), "server", "fix_acme_nginx.sh"
            )
            with open(local, "rb") as f:
                import base64

                b64 = base64.b64encode(f.read()).decode("ascii")
            must(
                ssh,
                f"mkdir -p /tmp/klany-fix && echo '{b64}' | base64 -d > /tmp/klany-fix/fix_acme_nginx.sh && chmod +x /tmp/klany-fix/fix_acme_nginx.sh",
            )
            script = "/tmp/klany-fix/fix_acme_nginx.sh"

        must(ssh, f"NGINX_VHOST_FILE='{NGINX_VHOST}' sh '{script}'")
        print(must(ssh, "curl -sS -m 10 https://klanymobail.ru/api/health || true"))
        print("[acme] OK")
        return 0
    finally:
        ssh.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(str(e), file=sys.stderr)
        raise SystemExit(1) from e
