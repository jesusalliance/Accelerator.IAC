FROM nginx:alpine

# Copy your custom nginx config to override default
COPY nginx.conf /etc/nginx/nginx.conf

# Copy your app files
COPY . /usr/share/nginx/html

# Expose the port (optional, but good practice)
EXPOSE 8080

# Start nginx
CMD ["nginx", "-g", "daemon off;"]