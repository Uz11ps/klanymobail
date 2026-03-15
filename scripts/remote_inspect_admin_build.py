import os
import time

import paramiko


HOST = os.getenv("VPS_IP", "91.197.99.149").strip()
USER = os.getenv("VPS_USER", "root").strip() or "root"
PASSWORD = (os.getenv("VPS_PASSWORD") or "").strip()


def main() -> None:
    last_err: Exception | None = None
    ssh: paramiko.SSHClient | None = None
    for attempt in range(1, 8):
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(
                HOST,
                username=USER,
                password=PASSWORD,
                timeout=20,
                banner_timeout=120,
                auth_timeout=60,
                look_for_keys=False,
                allow_agent=False,
            )
            break
        except Exception as e:
            last_err = e
            try:
                if ssh:
                    ssh.close()
            except Exception:
                pass
            time.sleep(min(2 * attempt, 10))
    if ssh is None:
        raise RuntimeError(f"SSH connect failed after retries: {last_err}")

    cmds = [
        "date",
        "docker ps --format 'table {{.Image}}\t{{.Names}}\t{{.Status}}' | sed -n '1,25p'",
        "ls -la /opt/klany/current/apps/klany_admin/build/web/index.html 2>/dev/null || echo no-index",
        "pgrep -af 'flutter|dart|dartaotruntime' | sed -n '1,25p' || true",
    ]
    for c in cmds:
        print("===", c, "===")
        _, stdout, stderr = ssh.exec_command(c)
        out = (stdout.read() or b"").decode("utf-8", errors="ignore")
        err = (stderr.read() or b"").decode("utf-8", errors="ignore")
        if out.strip():
            print(out.rstrip())
        if err.strip():
            print("---err---")
            print(err.rstrip())

    ssh.close()


if __name__ == "__main__":
    main()

