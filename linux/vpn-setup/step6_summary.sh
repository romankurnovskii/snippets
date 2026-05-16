#!/bin/bash
# Step 6: Send final summary to admin and client via Telegram
set -e

# Variables (override with env vars if needed)
TELEGRAM_BOT_TOKEN="${TelegramBotToken:-}"
TELEGRAM_CONSULTANT_ID="${TelegramConsultantId:-}"
SERVER_GIVEN_ID="${ServerGivenId:-1000}"
TELEGRAM_CLIENT_ID="${TelegramClientId:-12345}"
AWS_REGION="${AWS_Region:-us-east-1}"
AWS_STACK_NAME="${AWS_StackName:-unknown-stack}"

send_telegram() {
    local chat_id="$1"
    local message="$2"
    local content_type="$3"
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$chat_id" ]; then
        if [ "$content_type" = "json" ]; then
            curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
              -H 'Content-Type: application/json' \
              -d "${message}" || true
        else
            curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
              -d "chat_id=${chat_id}" \
              -d "text=${message}" || true
        fi
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

echo "[$(date)] STEP 6/6: Sending credentials summary to admin..."

# Get IP and creds (fallback if file missing)
PROXY_IP_ADDRESS=$(curl -s --max-time 10 https://api.ipify.org || echo "unknown")
PROXY_USER="pr${TELEGRAM_CLIENT_ID}"
PROXY_PORT=32533

if [ -f "/root/proxy_credentials.txt" ]; then
    # Parse username and port if needed, or just use defaults
    # For now we use the variables set above or in script
    echo "Using existing proxy_credentials.txt"
fi

CLIENT="client432"

send_telegram "$TELEGRAM_CONSULTANT_ID" "[${SERVER_GIVEN_ID}] COMPLETE for client ${TELEGRAM_CLIENT_ID}. IP: $PROXY_IP_ADDRESS Region: ${AWS_REGION} User: $PROXY_USER"

# Send logs if they exist
send_document "$TELEGRAM_CONSULTANT_ID" "/var/log/cloud-init-output.log" "[${SERVER_GIVEN_ID}] Setup log for ${TELEGRAM_CLIENT_ID}"
send_document "$TELEGRAM_CONSULTANT_ID" "/var/log/user-data.log" "[${SERVER_GIVEN_ID}] User-data log for ${TELEGRAM_CLIENT_ID}"

# Send credentials
send_document "$TELEGRAM_CONSULTANT_ID" "/root/proxy_credentials.txt" "[${SERVER_GIVEN_ID}] Proxy creds for ${TELEGRAM_CLIENT_ID}"
send_document "$TELEGRAM_CONSULTANT_ID" "/root/$CLIENT.ovpn" "[${SERVER_GIVEN_ID}] OVPN for ${TELEGRAM_CLIENT_ID}"

# =======================================================================
# SUCCESS — notify client and signal CloudFormation
# =======================================================================
SUCCESS_MSG="[${SERVER_GIVEN_ID}] Server is ready! Proxy IP: $PROXY_IP_ADDRESS Port: $PROXY_PORT User: $PROXY_USER. OpenVPN config sent separately."

# JSON payload for client
JSON_PAYLOAD="{\"chat_id\":\"${TELEGRAM_CLIENT_ID}\",\"text\":\"$SUCCESS_MSG\"}"
send_telegram "$TELEGRAM_CLIENT_ID" "$JSON_PAYLOAD" "json"

# Signal CloudFormation if available
if command -v cfn-signal &>/dev/null; then
    cfn-signal --stack "${AWS_STACK_NAME}" --resource EC2Instance --region "${AWS_REGION}" --exit-code 0 || true
else
    echo "[WARN] cfn-signal not found, skipping CF signal."
fi

echo "[$(date)] ALL STEPS COMPLETE"
