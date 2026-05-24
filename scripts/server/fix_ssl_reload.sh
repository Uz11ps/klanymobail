#!/usr/bin/env sh
# After certbot renew: verify cert on disk vs what nginx serves, then reload.
set -eu

echo "=== cert on disk (klanymobail.ru) ==="
openssl x509 -in /etc/letsencrypt/live/klanymobail.ru/fullchain.pem -noout -subject -dates

echo ""
echo "=== cert served on 443 (SNI klanymobail.ru) ==="
echo | openssl s_client -connect 127.0.0.1:443 -servername klanymobail.ru 2>/dev/null \
  | openssl x509 -noout -subject -dates

echo ""
echo "=== nginx ssl_certificate lines ==="
nginx -T 2>/dev/null | grep -E '^\s*(listen|server_name|ssl_certificate)' | head -n 80

echo ""
echo "=== reload nginx ==="
nginx -t
systemctl reload nginx
sleep 1

echo ""
echo "=== cert served AFTER reload ==="
echo | openssl s_client -connect 127.0.0.1:443 -servername klanymobail.ru 2>/dev/null \
  | openssl x509 -noout -subject -dates

echo ""
echo "=== curl health ==="
curl -sS -m 12 "https://klanymobail.ru/api/health" || true
echo ""
