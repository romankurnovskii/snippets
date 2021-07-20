#!/bin/bash
# Step 2: Squid HTTP proxy setup
set -e

# Variables (override with env vars if needed)
TELEGRAM_BOT_TOKEN="${TelegramBotToken:-}"
TELEGRAM_CONSULTANT_ID="${TelegramConsultantId:-}"
SERVER_GIVEN_ID="${ServerGivenId:-1000}"
TELEGRAM_CLIENT_ID="${TelegramClientId:-12345}"
S3_BUCKET_NAME="${S3BucketName:-sv-vpn-shop-demand-fallback}"

send_telegram() {
    local chat_id="$1"
    local message="$2"
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$chat_id" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
          -d "chat_id=${chat_id}" \
          -d "text=${message}" || true
    fi
}

echo "[$(date)] STEP 2/6: Configuring Squid proxy..."
send_telegram "$TELEGRAM_CONSULTANT_ID" "[${SERVER_GIVEN_ID}] STEP 2/6: Configuring Squid for client ${TELEGRAM_CLIENT_ID}..."

PROXY_PORT=32533
PROXY_USER="pr${TELEGRAM_CLIENT_ID}"
PROXY_PASS=$(openssl rand -base64 20 | tr -dc 'A-Za-z0-9' | head -c 8)

# Ensure directory exists
mkdir -p /etc/squid

{
  echo "http_port $PROXY_PORT"
  for p in 32534 32496 32497 32498 32499 32500; do echo "http_port $p"; done
  echo "auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd"
  echo "auth_param basic children 5"
  echo "auth_param basic realm Squid proxy-caching web server"
  echo "auth_param basic credentialsttl 4 hours"
  echo "acl authenticated proxy_auth REQUIRED"
  echo "http_access allow authenticated"
  echo "http_access deny all"
} > /etc/squid/squid.conf

# htpasswd requires apache2-utils
if ! command -v htpasswd &>/dev/null; then
    echo "[ERROR] htpasswd not found. Please install apache2-utils first."
    exit 1
fi

htpasswd -b -c /etc/squid/passwd "$PROXY_USER" "$PROXY_PASS"
PROXY_IP_ADDRESS=$(curl -s --max-time 10 https://api.ipify.org || echo "unknown")

# Systemd check
if command -v systemctl &>/dev/null; then
    systemctl enable squid || true
    systemctl restart squid || true
else
    echo "[WARN] systemctl not found, skipping service restart. Please restart squid manually."
fi

{
  echo "HTTPS Proxy:"
  echo "IP Address: $PROXY_IP_ADDRESS"
  echo "Proxy Port: $PROXY_PORT"
  echo "Username:   $PROXY_USER"
  echo "Password:   $PROXY_PASS"
  echo ""
  echo "Quick connect string:"
  echo "$PROXY_IP_ADDRESS:$PROXY_PORT@$PROXY_USER:$PROXY_PASS"
} > /root/proxy_credentials.txt

send_telegram "$TELEGRAM_CLIENT_ID" "[${SERVER_GIVEN_ID}] Proxy ready! IP: $PROXY_IP_ADDRESS Port: $PROXY_PORT User: $PROXY_USER"

# S3 Upload
if command -v aws &>/dev/null; then
    aws s3 cp /root/proxy_credentials.txt \
      "s3://${S3_BUCKET_NAME}/${TELEGRAM_CLIENT_ID}/${SERVER_GIVEN_ID}/proxy_credentials.txt" || true
else
    echo "[WARN] aws cli not found, skipping S3 upload."
fi

echo "[$(date)] STEP 2/6: DONE"
