#!/bin/sh
set -e

echo "Entrypoint started at $(date) as user: $(whoami)" >&2

# Force port
PORT=8080
echo "Nginx listening on port $PORT" >&2

# Collect info
HOSTNAME=$(hostname)
IP=$(hostname -i 2>/dev/null || echo "Unknown")
REPLICA_NAME=${CONTAINER_APP_REPLICA_NAME:-"Not set"}
APP_HOSTNAME=${CONTAINER_APP_HOSTNAME:-"N/A"}
ENV_DNS=${CONTAINER_APP_ENV_DNS_SUFFIX:-"N/A"}

# Generate HTML with real variable expansion (no quotes around EOF)
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Test Container - Healthy</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
    h1 { color: #2e7d32; }
    strong { color: #1565c0; }
  </style>
</head>
<body>
  <h1>TEST CONTAINER IS UP!</h1>
  <p><strong>Status:</strong> Healthy (ready for Application Gateway probe)</p>
  <p><strong>Hostname:</strong> $HOSTNAME</p>
  <p><strong>Container IP:</strong> $IP</p>
  <p><strong>Replica Name:</strong> $REPLICA_NAME</p>
  <p><strong>App Hostname:</strong> $APP_HOSTNAME</p>
  <p><strong>Env DNS Suffix:</strong> $ENV_DNS</p>
  <p><strong>Port:</strong> $PORT</p>
  <p><strong>Generated at:</strong> $(date)</p>
  <hr>
  <p>Dynamic page for AGW probe / ingress testing.</p>
</body>
</html>
EOF

chmod 644 /usr/share/nginx/html/index.html
echo "index.html written" >&2

# Start nginx with debug
exec nginx -g "daemon off; error_log /dev/stderr debug; pid /tmp/nginx.pid;"