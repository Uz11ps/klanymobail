FROM nginx:1.27-alpine

COPY infra/nginx/default.conf /etc/nginx/conf.d/default.conf
# Admin web is built locally and shipped as static assets.
COPY infra/nginx/admin_web /usr/share/nginx/html

