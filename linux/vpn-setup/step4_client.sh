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

if [ ! -d "/etc/openvpn/easy-rsa/" ]; then
    echo "[ERROR] /etc/openvpn/easy-rsa/ not found. Please install OpenVPN first."
    exit 1
fi

cd /etc/openvpn/easy-rsa/

# Generate client cert
./easyrsa --batch build-client-full "$CLIENT" nopass 2>/dev/null || {
    echo "[WARN] easyrsa failed, maybe client already exists or error occurred. Continuing..."
}

if [ ! -f "/etc/openvpn/client-template.txt" ]; then
    echo "[WARN] /etc/openvpn/client-template.txt not found. Creating a minimal one or assuming it exists."
    # The angristan script usually creates client configs differently or puts them in /root/
    # But let's follow the CF template logic if it assumes it exists.
fi

OUTPUT_FILE="/root/$CLIENT.ovpn"
cp /etc/openvpn/client-template.txt "$OUTPUT_FILE" 2>/dev/null || touch "$OUTPUT_FILE"

{
  echo "<ca>"
  cat /etc/openvpn/easy-rsa/pki/ca.crt 2>/dev/null || echo "CA_NOT_FOUND"
  echo "</ca>"
  echo "<cert>"
  awk '/BEGIN/,/END CERTIFICATE/' /etc/openvpn/easy-rsa/pki/issued/$CLIENT.crt 2>/dev/null || echo "CERT_NOT_FOUND"
  echo "</cert>"
  echo "<key>"
  cat /etc/openvpn/easy-rsa/pki/private/$CLIENT.key 2>/dev/null || echo "KEY_NOT_FOUND"
  echo "</key>"
  echo "<tls-crypt>"
  cat /etc/openvpn/tls-crypt.key 2>/dev/null || echo "TLS_CRYPT_NOT_FOUND"
  echo "</tls-crypt>"
} >> "$OUTPUT_FILE"

sed -i '1i #t.me/DemandVPNBot' "$OUTPUT_FILE"

# S3 Upload
if command -v aws &>/dev/null; then
    aws s3 cp "$OUTPUT_FILE" \
      "s3://${S3_BUCKET_NAME}/${TELEGRAM_CLIENT_ID}/${SERVER_GIVEN_ID}/$CLIENT.ovpn" || true
else
    echo "[WARN] aws cli not found, skipping S3 upload."
fi

echo "[$(date)] STEP 4/6: DONE"
