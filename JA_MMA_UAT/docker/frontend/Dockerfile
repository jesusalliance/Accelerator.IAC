FROM nginx:alpine

USER root

RUN apk update --no-cache && \
    apk add --no-cache \
    bind-tools \
    curl \
    iputils \
    traceroute \
    busybox-extras \
    nmap-ncat

# Pre-create dirs and set permissions
RUN mkdir -p /var/cache/nginx/client_temp \
             /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp \
             /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp \
             /run/nginx \
    && chown -R nginx:nginx /var/cache/nginx /run/nginx \
    && chmod -R 755 /var/cache/nginx /run/nginx \
    && chmod 1777 /run   # Force /run writable (sticky bit + full access)

USER nginx

COPY nginx.conf /etc/nginx/nginx.conf
COPY . /usr/share/nginx/html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]