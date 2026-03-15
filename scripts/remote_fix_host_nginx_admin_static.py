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

ADMIN_WEB_ROOT = os.getenv(
    "ADMIN_WEB_ROOT",
    "/opt/klany/current/apps/klany_admin/build/web",
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


def must(ssh: paramiko.SSHClient, cmd: str) -> str:
    stdin, stdout, stderr = ssh.exec_command(cmd)
    _ = stdin
    out = (stdout.read() or b"").decode("utf-8", errors="ignore")
    err = (stderr.read() or b"").decode("utf-8", errors="ignore")
    code = stdout.channel.recv_exit_status()
    if code != 0:
        msg = (err or out).strip()
        raise RuntimeError(f"Remote command failed ({code}): {cmd}\n{msg}")
    return (out or "").strip()


def main() -> int:
    if not PASSWORD:
        print("VPS_PASSWORD is required", file=sys.stderr)
        return 2

    ssh = _connect()
    try:
        must(ssh, f"test -f '{NGINX_VHOST}.bak_static' || cp -a '{NGINX_VHOST}' '{NGINX_VHOST}.bak_static'")
        must(ssh, f"sed -i 's/\\r$//' '{NGINX_VHOST}'")

        # Ensure admin build exists; if not, keep proxy to 8782.
        has_admin = must(ssh, f"test -f '{ADMIN_WEB_ROOT}/index.html' && echo yes || echo no").strip() == "yes"
        if not has_admin:
            print(f"[fix-admin] No admin build at {ADMIN_WEB_ROOT}/index.html; skipping static switch.")
            return 0

        # Patch 443 server block: serve static, keep /api proxy untouched.
        must(
            ssh,
            "python3 - <<'PY'\n"
            "import re\n"
            "from pathlib import Path\n"
            f"vhost = Path({NGINX_VHOST!r})\n"
            f"root_path = {ADMIN_WEB_ROOT!r}\n"
            "txt = vhost.read_text(encoding='utf-8', errors='ignore')\n"
            "lines = txt.splitlines(True)\n"
            "\n"
            "def split_servers(lines):\n"
            "  out=[]\n"
            "  i=0\n"
            "  while i < len(lines):\n"
            "    if re.match(r'^\\s*server\\s*\\{\\s*$', lines[i]):\n"
            "      start=i\n"
            "      depth=0\n"
            "      j=i\n"
            "      while j < len(lines):\n"
            "        depth += lines[j].count('{')\n"
            "        depth -= lines[j].count('}')\n"
            "        if depth==0 and j>start:\n"
            "          out.append((start, j))\n"
            "          i=j\n"
            "          break\n"
            "        j+=1\n"
            "    i+=1\n"
            "  return out\n"
            "\n"
            "def is_443(block):\n"
            "  return any(re.search(r'\\blisten\\b.*\\b443\\b.*\\bssl\\b', ln) for ln in block)\n"
            "\n"
            "def remove_location_root(block):\n"
            "  out=[]\n"
            "  i=0\n"
            "  while i < len(block):\n"
            "    if re.match(r'^\\s*location\\s+/\\s*\\{\\s*$', block[i]):\n"
            "      depth=0\n"
            "      j=i\n"
            "      while j < len(block):\n"
            "        depth += block[j].count('{')\n"
            "        depth -= block[j].count('}')\n"
            "        if depth==0 and j>i:\n"
            "          i=j+1\n"
            "          break\n"
            "        j+=1\n"
            "      continue\n"
            "    out.append(block[i])\n"
            "    i+=1\n"
            "  return out\n"
            "\n"
            "servers = split_servers(lines)\n"
            "out = lines[:]\n"
            "for start,end in reversed(servers):\n"
            "  block = out[start:end+1]\n"
            "  if not is_443(block):\n"
            "    continue\n"
            "  indent='  '\n"
            "  # Ensure root/index at server level\n"
            "  has_root = any(re.match(r'^\\s*root\\s+', ln) for ln in block)\n"
            "  has_index = any(re.match(r'^\\s*index\\s+', ln) for ln in block)\n"
            "  if not (has_root and has_index):\n"
            "    inserted=[]\n"
            "    done=False\n"
            "    for ln in block:\n"
            "      inserted.append(ln)\n"
            "      if (not done) and re.search(r'\\bserver_name\\b', ln):\n"
            "        if not has_root:\n"
            "          inserted.append(f\"{indent}root {root_path};\\n\")\n"
            "        if not has_index:\n"
            "          inserted.append(f\"{indent}index index.html;\\n\")\n"
            "        done=True\n"
            "    block = inserted\n"
            "  # Replace location / with SPA fallback\n"
            "  block = remove_location_root(block)\n"
            "  spa = [\n"
            "    f\"{indent}location / {{\\n\",\n"
            "    f\"{indent}  try_files $uri $uri/ /index.html;\\n\",\n"
            "    f\"{indent}}}\\n\",\n"
            "  ]\n"
            "  block = block[:-1] + spa + block[-1:]\n"
            "  out[start:end+1] = block\n"
            "\n"
            "vhost.write_text(''.join(out), encoding='utf-8')\n"
            "print('patched', vhost)\n"
            "PY"
        )

        must(ssh, "nginx -t")
        must(ssh, "systemctl reload nginx")

        # Quick validations.
        print(must(ssh, "curl -sS -m 10 -I https://klanymobail.ru/ | head -n 8"))
        print(must(ssh, "curl -sS -m 10 -I https://klanymobail.ru/manifest.json | head -n 8 || true"))
        return 0
    finally:
        ssh.close()


if __name__ == "__main__":
    raise SystemExit(main())

