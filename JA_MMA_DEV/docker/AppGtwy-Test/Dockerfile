FROM nginx:alpine

# Install dos2unix (fixes CRLF) + gettext (optional future use)
RUN apk add --no-cache dos2unix gettext

# Create required nginx directories and fix permissions
RUN mkdir -p /var/cache/nginx/client_temp \
             /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp \
             /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp \
             /run/nginx \
    && chown -R nginx:nginx /var/cache/nginx /run/nginx \
    && chmod -R 755 /var/cache/nginx /run/nginx \
    && chmod 1777 /run

# Copy configuration and static files
COPY nginx.conf /etc/nginx/nginx.conf
COPY . /usr/share/nginx/html

# IMPORTANT: Make the html directory writable by nginx user (fixes permission denied)
RUN chown -R nginx:nginx /usr/share/nginx/html \
    && chmod -R 755 /usr/share/nginx/html

# Copy entrypoint, convert line endings, make executable
COPY entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh \
    && chmod +x /entrypoint.sh

USER nginx

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]