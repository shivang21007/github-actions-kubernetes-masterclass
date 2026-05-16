FROM nginx:1.27-alpine-slim

# Base slim tag can lag behind Alpine security updates; refresh OS packages (openssl/musl/zlib, etc.).
# hadolint ignore=DL3017
RUN apk upgrade --no-cache

RUN rm -rf /usr/share/nginx/html/*

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/
COPY css/ /usr/share/nginx/html/css/
COPY js/ /usr/share/nginx/html/js/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
