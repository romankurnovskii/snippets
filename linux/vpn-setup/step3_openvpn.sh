#!/bin/bash
# Step 3: OpenVPN server installation
set -e

# Variables (override with env vars if needed)
TELEGRAM_BOT_TOKEN="${TelegramBotToken:-}"
TELEGRAM_CONSULTANT_ID="${TelegramConsultantId:-}"
SERVER_GIVEN_ID="${ServerGivenId:-1000}"
TELEGRAM_CLIENT_ID="${TelegramClientId:-12345}"

send_telegram() {
    local chat_id="$1"
    local message="$2"
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$chat_id" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
          -d "chat_id=${chat_id}" \
          -d "text=${message}" || true
    fi
}

send_document() {
    local chat_id="$1"
    local file_path="$2"
    local caption="$3"
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$chat_id" ] && [ -f "$file_path" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
          -F "chat_id=${chat_id}" \
          -F "document=@${file_path}" \
          -F "caption=${caption}" || true
    fi
}

echo "[$(date)] STEP 3/6: Installing OpenVPN (may take 3–5 min)..."
send_telegram "$TELEGRAM_CONSULTANT_ID" "[${SERVER_GIVEN_ID}] STEP 3/6: Installing OpenVPN for client ${TELEGRAM_CLIENT_ID} (3-5 min)..."

cd /root
export AUTO_INSTALL=y
export IPV6_SUPPORT=n
export PORT=443
export PORT_CHOICE=2
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if ! command -v wget &>/dev/null; then
    echo "[ERROR] wget not found. Please install it first."
    exit 1
fi

wget -q https://raw.githubusercontent.com/angristan/openvpn-install/refs/heads/master/openvpn-install.sh -O openvpn-install.sh
chmod +x openvpn-install.sh

# Apply fixes to the script
sed -i 's/ip\.seeip\.org/api.seeip.org/g' openvpn-install.sh
sed -i 's|sha256sum.*\/easy-rsa\.tgz|sha256sum /root/easy-rsa.tgz|g' openvpn-install.sh || true

# Run the installer
bash openvpn-install.sh install </dev/null 2>&1

# Get IP for filename (fallback to unknown if failed)
PROXY_IP_ADDRESS=$(curl -s --max-time 10 https://api.ipify.org || echo "unknown")

OPEN_VPN_FILE="/root/${SERVER_GIVEN_ID}-$PROXY_IP_ADDRESS.ovpn"
if [ -f "/root/client.ovpn" ]; then
    cp /root/client.ovpn "$OPEN_VPN_FILE"
    sed -i '1i #t.me/DemandVPNBot' "$OPEN_VPN_FILE"
    
    send_document "$TELEGRAM_CLIENT_ID" "$OPEN_VPN_FILE" "[${SERVER_GIVEN_ID}] Your OpenVPN config is ready!"
else
    echo "[ERROR] /root/client.ovpn not found after installation."
    exit 1
fi

echo "[$(date)] STEP 3/6: DONE"
