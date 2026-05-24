#!/usr/bin/env sh
# ONE COMMAND on VPS as root (copy entire file or pipe via curl):
#   curl -fsSL ... | sh
# Or paste from repo:
#   sh /opt/klanymobail/scripts/server/fix_acme_one_shot.sh
set -eu

VHOST="${NGINX_VHOST_FILE:-/etc/nginx/vhosts/www-root/91-197-99-149.regru.cloud.conf}"

echo "=== [1/4] backup nginx vhost ==="
test -f "${VHOST}.bak-acme-$(date +%Y%m%d)" || cp -a "$VHOST" "${VHOST}.bak-acme-$(date +%Y%m%d)"
sed -i 's/\r$//' "$VHOST"

echo "=== [2/4] patch nginx (ACME on 80+443, redirect only inside location /) ==="
python3 - "$VHOST" <<'PY'
import re
import sys
from pathlib import Path

p = Path(sys.argv[1])
lines = p.read_text(encoding="utf-8", errors="ignore").splitlines(keepends=True)

acme = """    location ^~ /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type "text/plain";
    }

"""
redirect = """        if ($host = klanymobail.ru) {
            return 301 https://$host$request_uri;
        }
        if ($host = www.klanymobail.ru) {
            return 301 https://$host$request_uri;
        }

"""

def server_blocks(lines):
    blocks = []
    i = 0
    while i < len(lines):
        if re.match(r"^\s*server\s*\{\s*$", lines[i]):
            start, depth, j = i, 0, i
            while j < len(lines):
                depth += lines[j].count("{") - lines[j].count("}")
                if depth == 0 and j > start:
                    blocks.append((start, j))
                    i = j
                    break
                j += 1
        i += 1
    return blocks

def block_lines(lines, start, end):
    return lines[start : end + 1]

def is_443(block):
    return any(re.search(r"\blisten\b.*\b443\b.*\bssl\b", ln) for ln in block)

def is_80(block):
    return any(re.search(r"\blisten\b[^;]*\b80\b", ln) for ln in block) and not is_443(block)

def strip_server_level_redirects(block):
    out, i = [], 0
    while i < len(block):
        if re.match(r"^\s*if\s*\(\s*\$host\s*=\s*klanymobail\.ru\s*\)\s*\{\s*$", block[i]):
            depth, j = 0, i
            while j < len(block):
                depth += block[j].count("{") - block[j].count("}")
                if depth == 0 and j > i:
                    i = j + 1
                    break
                j += 1
            continue
        if re.match(r"^\s*if\s*\(\s*\$host\s*=\s*www\.klanymobail\.ru\s*\)\s*\{\s*$", block[i]):
            depth, j = 0, i
            while j < len(block):
                depth += block[j].count("{") - block[j].count("}")
                if depth == 0 and j > i:
                    i = j + 1
                    break
                j += 1
            continue
        out.append(block[i])
        i += 1
    return out

def has_acme(block):
    return any("/.well-known/acme-challenge/" in ln for ln in block)

def insert_after_server_name(block, snippet):
    out, done = [], False
    for ln in block:
        out.append(ln)
        if (not done) and re.search(r"\bserver_name\b", ln):
            out.append(snippet)
            done = True
    return out if done else block[:1] + [snippet] + block[1:]

def patch_location_slash(block, add_redirect):
    out, i = [], 0
    while i < len(block):
        if re.match(r"^\s*location\s+/\s*\{\s*$", block[i]):
            out.append(block[i])
            rest_start = i + 1
            depth, j = 1, i + 1
            inner = []
            while j < len(block) and depth:
                line = block[j]
                depth += line.count("{") - line.count("}")
                if depth:
                    inner.append(line)
                j += 1
            inner_text = "".join(inner)
            if add_redirect and "klanymobail.ru)" not in inner_text:
                out.append(redirect)
            out.extend(inner)
            out.append(block[j - 1] if j - 1 > i else "}\n")
            i = j
            continue
        out.append(block[i])
        i += 1
    return out

for start, end in reversed(server_blocks(lines)):
    block = block_lines(lines, start, end)
    block = strip_server_level_redirects(block)
    if not has_acme(block):
        block = insert_after_server_name(block, acme)
    if is_80(block):
        block = patch_location_slash(block, add_redirect=True)
    lines[start : end + 1] = block

p.write_text("".join(lines), encoding="utf-8")
print("patched", p)
PY

mkdir -p /var/www/letsencrypt/.well-known/acme-challenge
chmod -R a+rX /var/www/letsencrypt

echo "=== [3/4] nginx reload ==="
nginx -t
systemctl reload nginx

echo "ACME probe (must NOT contain 'Admin web bundle'):"
curl -sS -m 8 "http://klanymobail.ru/.well-known/acme-challenge/probe-$$" | head -c 100 || true
echo ""

echo "=== [4/4] certbot renew ==="
certbot renew --cert-name klanymobail.ru --force-renewal
systemctl reload nginx

echo "=== health ==="
curl -sS -m 12 "https://klanymobail.ru/api/health" || true
echo ""
echo "=== DONE ==="
