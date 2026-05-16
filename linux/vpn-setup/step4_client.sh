#!/bin/bash
# Step 4: Generate a secondary VPN client certificate
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

echo "[$(date)] STEP 4/6: Generating secondary client certificate..."
send_telegram "$TELEGRAM_CONSULTANT_ID" "[${SERVER_GIVEN_ID}] STEP 4/6: Secondary client config for ${TELEGRAM_CLIENT_ID}..."

CLIENT="client432"

# Use the installer script to generate the client config
if [ -f "/root/openvpn-install.sh" ]; then
    bash /root/openvpn-install.sh client add "$CLIENT" --output "/root/$CLIENT.ovpn"
elif [ -f "openvpn-install.sh" ]; then
    bash openvpn-install.sh client add "$CLIENT" --output "/root/$CLIENT.ovpn"
else
    echo "[ERROR] openvpn-install.sh not found. Please download it first."
    exit 1
fi

sed -i '1i #t.me/DemandVPNBot' "/root/$CLIENT.ovpn"

# S3 Upload
if command -v aws &>/dev/null; then
    aws s3 cp "/root/$CLIENT.ovpn" \
      "s3://${S3_BUCKET_NAME}/${TELEGRAM_CLIENT_ID}/${SERVER_GIVEN_ID}/$CLIENT.ovpn" || true
else
    echo "[WARN] aws cli not found, skipping S3 upload."
fi

echo "[$(date)] STEP 4/6: DONE"
