#!/usr/bin/env sh
# Fix host nginx so Certbot webroot challenges work, then renew klanymobail.ru cert.
# Run on the VPS as root:
#   sh /opt/klanymobail/scripts/server/fix_acme_nginx.sh
set -eu

VHOST="${NGINX_VHOST_FILE:-/etc/nginx/vhosts/www-root/91-197-99-149.regru.cloud.conf}"
WEBROOT="/var/www/letsencrypt"

echo "[acme] backup $VHOST"
test -f "${VHOST}.bak-acme" || cp -a "$VHOST" "${VHOST}.bak-acme"

echo "[acme] normalize line endings"
sed -i 's/\r$//' "$VHOST"

echo "[acme] remove server-level HTTPS redirects (break ACME on port 80)"
sed -i '/if ($host = klanymobail.ru)/,/}/d' "$VHOST" || true
sed -i '/if ($host = www.klanymobail.ru)/,/}/d' "$VHOST" || true

ACME_BLOCK='    location ^~ /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type "text/plain";
    }
'

if ! grep -q 'location \^~ /\.well-known/acme-challenge/' "$VHOST"; then
  echo "[acme] ERROR: no acme location in $VHOST — add it manually from scripts/server/host_vhost_klany.conf"
  exit 1
fi

# Insert acme block into each 443 ssl server if missing (after server_name line).
python3 - "$VHOST" <<'PY'
import re
import sys
from pathlib import Path

vhost = Path(sys.argv[1])
acme = """    location ^~ /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type "text/plain";
    }

"""

text = vhost.read_text(encoding="utf-8", errors="ignore")
lines = text.splitlines(keepends=True)

def is_443_server_start(i: int) -> bool:
    if not re.match(r"^\s*server\s*\{\s*$", lines[i]):
        return False
    depth = 0
    j = i
    while j < len(lines):
        depth += lines[j].count("{")
        depth -= lines[j].count("}")
        block = lines[i : j + 1]
        if depth == 0 and j > i:
            return any(re.search(r"\blisten\b.*\b443\b.*\bssl\b", ln) for ln in block)
        j += 1
    return False

def server_range(i: int) -> tuple[int, int]:
    depth = 0
    j = i
    while j < len(lines):
        depth += lines[j].count("{")
        depth -= lines[j].count("}")
        if depth == 0 and j > i:
            return i, j
        j += 1
    return i, len(lines) - 1

def has_acme(block: list[str]) -> bool:
    return any("/.well-known/acme-challenge/" in ln for ln in block)

def insert_after_server_name(block: list[str], snippet: str) -> list[str]:
    out: list[str] = []
    inserted = False
    for ln in block:
        out.append(ln)
        if (not inserted) and re.search(r"\bserver_name\b", ln):
            out.append(snippet)
            inserted = True
    if not inserted:
        out = block[:1] + [snippet] + block[1:]
    return out

i = 0
while i < len(lines):
    if is_443_server_start(i):
        start, end = server_range(i)
        block = lines[start : end + 1]
        if not has_acme(block):
            block = insert_after_server_name(block, acme)
            lines[start : end + 1] = block
        i = end + 1
    else:
        i += 1

# Ensure HTTP redirect lives inside "location /" on port 80, not at server level.
out = []
i = 0
while i < len(lines):
    ln = lines[i]
    if re.match(r"^\s*location\s+/\s*\{\s*$", ln) and i > 0:
        # Peek server block listen
        j = i
        while j >= 0 and not re.match(r"^\s*server\s*\{\s*$", lines[j]):
            j -= 1
        block_start = j
        _, block_end = server_range(block_start)
        block = lines[block_start : block_end + 1]
        is_80 = any(re.search(r"\blisten\b[^;]*\b80\b", b) for b in block) and not any(
            re.search(r"\blisten\b.*\b443\b", b) for b in block
        )
        if is_80:
            indent = re.match(r"^(\s*)", ln).group(1)
            redirect = (
                f"{indent}  if ($host = klanymobail.ru) {{\n"
                f"{indent}    return 301 https://$host$request_uri;\n"
                f"{indent}  }}\n"
                f"{indent}  if ($host = www.klanymobail.ru) {{\n"
                f"{indent}    return 301 https://$host$request_uri;\n"
                f"{indent}  }}\n"
            )
            if "klanymobail.ru)" not in "".join(block[block.index(ln) : block.index(ln) + 12]):
                out.append(ln)
                out.append(redirect)
                i += 1
                continue
    out.append(ln)
    i += 1

vhost.write_text("".join(out), encoding="utf-8")
print("[acme] patched", vhost)
PY

mkdir -p "$WEBROOT/.well-known/acme-challenge"
chmod -R a+rX "$WEBROOT" 2>/dev/null || true

echo "[acme] nginx -t && reload"
nginx -t
systemctl reload nginx

echo "[acme] test challenge path (expect 404, NOT admin HTML)"
curl -sS -m 5 "http://klanymobail.ru/.well-known/acme-challenge/ping-test" | head -c 120 || true
echo ""

echo "[acme] certbot renew (force)"
certbot renew --cert-name klanymobail.ru --force-renewal

nginx -t
systemctl reload nginx

echo "[acme] verify HTTPS"
curl -sS -m 10 "https://klanymobail.ru/api/health" || true
echo ""
echo "[acme] done"
