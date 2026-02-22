FROM ghcr.io/cirruslabs/flutter:stable AS admin-build

WORKDIR /repo
COPY apps/klany_admin ./apps/klany_admin

RUN cd apps/klany_admin && flutter pub get
RUN cd apps/klany_admin && flutter build web --release

FROM nginx:1.27-alpine

COPY infra/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=admin-build /repo/apps/klany_admin/build/web /usr/share/nginx/html

