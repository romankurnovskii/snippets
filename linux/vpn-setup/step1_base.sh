#!/bin/bash
# Step 1: Base package installation
set -e

# Variables (override with env vars if needed)
TELEGRAM_BOT_TOKEN="${TelegramBotToken:-}"
TELEGRAM_CONSULTANT_ID="${TelegramConsultantId:-}"
SERVER_GIVEN_ID="${ServerGivenId:-1000}"
TELEGRAM_CLIENT_ID="${TelegramClientId:-}"

send_telegram() {
    local message="$1"
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CONSULTANT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
          -d "chat_id=${TELEGRAM_CONSULTANT_ID}" \
          -d "text=${message}" || true
    fi
}

echo "[$(date)] STEP 1/6: Installing base packages..."
send_telegram "[${SERVER_GIVEN_ID}] STEP 1/6: Installing base packages (client ${TELEGRAM_CLIENT_ID})..."

# Retry apt-get update up to 3 times
for attempt in 1 2 3; do
  if apt-get update -qq; then
    echo "[$(date)] apt-get update succeeded"
    break
  fi
  echo "[WARN] apt-get update failed (attempt $attempt/3), retrying in 10s..."
  sleep 10
done

# Pre-answer tshark's interactive prompt BEFORE install
echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections

# Install packages even if update partially failed
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  awscli python3-pip apache2-utils squid tshark || true

# Fix for aws-cfn-bootstrap on Ubuntu 22.04 (Python 3.10)
echo "[$(date)] Installing aws-cfn-bootstrap..."
pip3 install -q https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-py3-latest.tar.gz

# Apply fix for collections.MutableMapping
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
LIB_PATH="/usr/local/lib/python${PYTHON_VERSION}/dist-packages/cfnbootstrap/util.py"
if [ -f "$LIB_PATH" ]; then
    echo "[$(date)] Applying Python 3.10 fix to $LIB_PATH"
    sed -i "s/collections.MutableMapping/collections.abc.MutableMapping/g" "$LIB_PATH"
fi

# Verify cfn-signal
command -v cfn-signal || { echo "[ERROR] cfn-signal not found"; exit 1; }

echo "[$(date)] STEP 1/6: DONE"
