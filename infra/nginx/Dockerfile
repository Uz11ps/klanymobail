FROM nginx:1.27-alpine

COPY infra/nginx/default.conf /etc/nginx/conf.d/default.conf
# Static bundles are built locally when available. admin_web is intentionally
# gitignored, so clean server checkouts must still produce a valid nginx image.
COPY infra/nginx /tmp/klany-nginx
RUN set -eux; \
    mkdir -p /usr/share/nginx/html /usr/share/nginx/app; \
    if [ -d /tmp/klany-nginx/admin_web ]; then \
      cp -a /tmp/klany-nginx/admin_web/. /usr/share/nginx/html/; \
    else \
      printf '%s\n' '<!doctype html><html><head><meta charset="utf-8"><title>Klany Admin</title></head><body>Admin web bundle is not deployed.</body></html>' > /usr/share/nginx/html/index.html; \
    fi; \
    if [ -d /tmp/klany-nginx/mobile_web ]; then \
      cp -a /tmp/klany-nginx/mobile_web/. /usr/share/nginx/app/; \
    else \
      printf '%s\n' '<!doctype html><html><head><meta charset="utf-8"><title>Klany App</title></head><body>Mobile web bundle is not deployed.</body></html>' > /usr/share/nginx/app/index.html; \
    fi; \
    rm -rf /tmp/klany-nginx

