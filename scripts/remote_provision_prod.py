import os
import shlex
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

# Public key that should be allowed for root login.
ROOT_AUTHORIZED_KEY = os.getenv(
    "ROOT_AUTHORIZED_KEY",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG69R6x2xTHpZIW2lEG4GZFbHTf8ZEC0JQtWoEmowar1 klany-root-deploy",
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


def _run_streaming(ssh: paramiko.SSHClient, cmd: str, *, timeout_sec: int) -> None:
    stdin, stdout, stderr = ssh.exec_command(cmd, get_pty=True)
    _ = stdin
    ch = stdout.channel
    start = time.time()

    def drain() -> None:
        while ch.recv_ready():
            sys.stdout.write(ch.recv(4096).decode("utf-8", errors="ignore"))
            sys.stdout.flush()
        while ch.recv_stderr_ready():
            sys.stderr.write(ch.recv_stderr(4096).decode("utf-8", errors="ignore"))
            sys.stderr.flush()

    while True:
        drain()
        if ch.exit_status_ready():
            break
        if time.time() - start > timeout_sec:
            try:
                ch.close()
            except Exception:
                pass
            raise RuntimeError(f"Remote command timeout after {timeout_sec}s: {cmd}")
        time.sleep(0.25)

    drain()
    code = ch.recv_exit_status()
    if code != 0:
        raise RuntimeError(f"Remote command failed ({code}): {cmd}")


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

    print(f"[prov] Connecting to {USER}@{HOST} ...")
    ssh = _connect()
    try:
        print("[prov] Ensuring root SSH key authorized...")
        # Idempotently add key.
        key_escaped = ROOT_AUTHORIZED_KEY.replace("'", "'\"'\"'")
        must(
            ssh,
            "mkdir -p /root/.ssh && chmod 700 /root/.ssh && touch /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys",
        )
        must(ssh, f"grep -qxF '{key_escaped}' /root/.ssh/authorized_keys || echo '{key_escaped}' >> /root/.ssh/authorized_keys")
        must(ssh, "chown -R root:root /root/.ssh")

        print("[prov] Building admin web bundle on server (dockerized Flutter)...")
        # Build on server to avoid relying on local Flutter install.
        # Using dockerized Flutter; output goes into mounted worktree.
        build_cmd = (
            "set -euo pipefail; "
            "cd /opt/klany/current/apps/klany_admin; "
            "docker run --rm "
            "-v /opt/klany/current:/work "
            "-w /work/apps/klany_admin "
            "ghcr.io/cirruslabs/flutter:stable "
            "bash -lc \"flutter pub get && flutter build web --release\""
        )
        _run_streaming(ssh, f"bash -lc {shlex.quote(build_cmd)}", timeout_sec=40 * 60)

        # Verify build exists.
        must(ssh, f"test -f '{ADMIN_WEB_ROOT}/index.html'")

        print("[prov] Patching host nginx vhost to serve admin + proxy /api...")
        must(ssh, f"test -f '{NGINX_VHOST}.bak' || cp -a '{NGINX_VHOST}' '{NGINX_VHOST}.bak'")
        must(ssh, f"python3 - <<'PY'\n"
                  f"import re\n"
                  f"from pathlib import Path\n"
                  f"p = Path({NGINX_VHOST!r})\n"
                  f"txt = p.read_text(encoding='utf-8', errors='ignore')\n"
                  f"lines = txt.splitlines(True)\n"
                  f"\n"
                  f"def find_server_blocks(lines):\n"
                  f"  blocks=[]\n"
                  f"  i=0\n"
                  f"  while i < len(lines):\n"
                  f"    if re.match(r'^\\s*server\\s*\\{{\\s*$', lines[i]):\n"
                  f"      start=i\n"
                  f"      depth=0\n"
                  f"      j=i\n"
                  f"      while j < len(lines):\n"
                  f"        depth += lines[j].count('{{')\n"
                  f"        depth -= lines[j].count('}}')\n"
                  f"        if depth==0 and j>start:\n"
                  f"          blocks.append((start, j))\n"
                  f"          i=j\n"
                  f"          break\n"
                  f"        j+=1\n"
                  f"    i+=1\n"
                  f"  return blocks\n"
                  f"\n"
                  f"def is_443(block_lines):\n"
                  f"  return any(re.search(r'\\blisten\\b.*\\b443\\b.*\\bssl\\b', ln) for ln in block_lines)\n"
                  f"\n"
                  f"def remove_location_slash(block, loc_prefix):\n"
                  f"  out=[]\n"
                  f"  i=0\n"
                  f"  while i < len(block):\n"
                  f"    m = re.match(r'^(\\s*)location\\s+[^\\s]+\\s+' + re.escape(loc_prefix) + r'\\s*\\{{\\s*$', block[i])\n"
                  f"    if m:\n"
                  f"      indent=m.group(1)\n"
                  f"      depth=0\n"
                  f"      j=i\n"
                  f"      while j < len(block):\n"
                  f"        depth += block[j].count('{{')\n"
                  f"        depth -= block[j].count('}}')\n"
                  f"        if depth==0 and j>i:\n"
                  f"          i=j+1\n"
                  f"          break\n"
                  f"        j+=1\n"
                  f"      continue\n"
                  f"    out.append(block[i])\n"
                  f"    i+=1\n"
                  f"  return out\n"
                  f"\n"
                  f"def remove_location_root(block):\n"
                  f"  out=[]\n"
                  f"  i=0\n"
                  f"  while i < len(block):\n"
                  f"    m = re.match(r'^(\\s*)location\\s+/\\s*\\{{\\s*$', block[i])\n"
                  f"    if m:\n"
                  f"      depth=0\n"
                  f"      j=i\n"
                  f"      while j < len(block):\n"
                  f"        depth += block[j].count('{{')\n"
                  f"        depth -= block[j].count('}}')\n"
                  f"        if depth==0 and j>i:\n"
                  f"          i=j+1\n"
                  f"          break\n"
                  f"        j+=1\n"
                  f"      continue\n"
                  f"    out.append(block[i])\n"
                  f"    i+=1\n"
                  f"  return out\n"
                  f"\n"
                  f"def ensure_api_location(block, indent='  '):\n"
                  f"  # Ensure a clean /api/ location that keeps prefix.\n"
                  f"  block = [re.sub(r'^(\\s*)location\\s+~\\^\\s+/api/', r'\\1location ^~ /api/', ln) for ln in block]\n"
                  f"  block = [re.sub(r'^(\\s*)location\\s+~\\s+/api/', r'\\1location ^~ /api/', ln) for ln in block]\n"
                  f"  # Fix proxy_pass trailing slash.\n"
                  f"  block = [re.sub(r'proxy_pass\\s+http://127\\.0\\.0\\.1:3000/;', 'proxy_pass http://127.0.0.1:3000;', ln) for ln in block]\n"
                  f"  # If no /api/ location exists, add one near end (before closing brace).\n"
                  f"  has = any(re.match(r'^\\s*location\\s+\\^~\\s+/api/', ln) for ln in block)\n"
                  f"  if not has:\n"
                  f"    api = [\n"
                  f"      f\"{indent}location ^~ /api/ {{\\n\",\n"
                  f"      f\"{indent}  proxy_pass http://127.0.0.1:3000;\\n\",\n"
                  f"      f\"{indent}  proxy_http_version 1.1;\\n\",\n"
                  f"      f\"{indent}  proxy_set_header Host $host;\\n\",\n"
                  f"      f\"{indent}  proxy_set_header X-Real-IP $remote_addr;\\n\",\n"
                  f"      f\"{indent}  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\\n\",\n"
                  f"      f\"{indent}  proxy_set_header X-Forwarded-Proto $scheme;\\n\",\n"
                  f"      f\"{indent}}}\\n\",\n"
                  f"    ]\n"
                  f"    # insert before last line (closing server brace)\n"
                  f"    block = block[:-1] + api + block[-1:]\n"
                  f"  return block\n"
                  f"\n"
                  f"def ensure_admin_root(block, root_path, indent='  '):\n"
                  f"  # Add root/index at server level.\n"
                  f"  out=[]\n"
                  f"  inserted=False\n"
                  f"  for ln in block:\n"
                  f"    out.append(ln)\n"
                  f"    if (not inserted) and re.search(r'\\bserver_name\\b', ln):\n"
                  f"      out.append(f\"{indent}root {root_path};\\n\")\n"
                  f"      out.append(f\"{indent}index index.html;\\n\")\n"
                  f"      inserted=True\n"
                  f"  if not inserted:\n"
                  f"    out = out[:1] + [f\"{indent}root {root_path};\\n\", f\"{indent}index index.html;\\n\"] + out[1:]\n"
                  f"  # Replace location / with SPA fallback.\n"
                  f"  out = remove_location_root(out)\n"
                  f"  spa = [\n"
                  f"    f\"{indent}location / {{\\n\",\n"
                  f"    f\"{indent}  try_files $uri $uri/ /index.html;\\n\",\n"
                  f"    f\"{indent}}}\\n\",\n"
                  f"  ]\n"
                  f"  out = out[:-1] + spa + out[-1:]\n"
                  f"  return out\n"
                  f"\n"
                  f"blocks = find_server_blocks(lines)\n"
                  f"out_lines = lines[:]\n"
                  f"for start,end in reversed(blocks):\n"
                  f"  block = out_lines[start:end+1]\n"
                  f"  if not is_443(block):\n"
                  f"    # Still ensure /api keeps prefix for any host hitting HTTP.\n"
                  f"    block = ensure_api_location(block)\n"
                  f"    out_lines[start:end+1] = block\n"
                  f"    continue\n"
                  f"  block = ensure_api_location(block)\n"
                  f"  block = ensure_admin_root(block, {ADMIN_WEB_ROOT!r})\n"
                  f"  out_lines[start:end+1] = block\n"
                  f"\n"
                  f"p.write_text(''.join(out_lines), encoding='utf-8')\n"
                  f"print('patched', p)\n"
                  f"PY")

        must(ssh, "nginx -t")
        must(ssh, "systemctl reload nginx")

        print("[prov] Checking public endpoints ...")
        print(must(ssh, "curl -sS -m 10 -i https://klanymobail.ru/api/health | head -n 12"))
        print(must(ssh, "curl -sS -m 10 -I https://klanymobail.ru/ | head -n 8"))

        print("[prov] Done.")
        return 0
    finally:
        ssh.close()


if __name__ == "__main__":
    raise SystemExit(main())

