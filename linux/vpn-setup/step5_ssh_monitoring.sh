#!/bin/bash
# Step 5: SSH authorized key + DNS monitoring cron job
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

echo "[$(date)] STEP 5/6: SSH key + DNS monitoring cron..."
send_telegram "$TELEGRAM_CONSULTANT_ID" "[${SERVER_GIVEN_ID}] STEP 5/6: SSH + monitoring setup..."

# SSH Key Setup
mkdir -p /home/ubuntu/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCqFC5UI6Qx0GJf+K7piDWLjSrWIZUi3kDdGKd98h0Xzbr8Q8nbNbndyoVgYgrAy8jdTzuJyIdfY9NUCr4OGooiuD5yHmmtaRiAmnXa327qf87YfGHWQvry+BQREVbB02F5EmbURXrEdAGO83eJ6R4SYlkIUkMK5qYEE5tyGL5nwuKg0cTRtQ+maVm5RGgWufmDQdzMEUfXMXcs0SAb4A39tKLX/TYwHLypz4EJ6RkDX1jO1Abgri3qyGwg3bp21To2xrYytl+9IbuTC+cyom/sN9gOzJZf6wP14CH0V1+neAKRHJan3nOMCV932f26U8WRYRRRxcRvjIy1ItXuyeTrTXRP/Xg+xqO+YcslV784vEgep8sVoe8YSWMkHZN1GbuKGxrRJ94ouZmuV+/0RcQzXHyFGYki3SCtPa7TTnhQ1nejQpg7mmOnbagg5XWjn0TfRDe+T0G9tgfuSZw815YjmnNgWdlPzRvdJrytpeCPxsYgdV31ZfZTv5sYUfAvsFhec40oBdAIBVWpOQ6+WweKVVcqkgUW7PtKpMKkkWWv0+zXsaW6Sd1hmmEXw3NNFgn5Ouro/Il8tZ5caAilLPs+duYiGDK8Ehd46Rhujtyb2OVNWx6pYhiNSQ4Vrfc/YcuDaVPmuqeda2gx0QU5p6zXwz7O0SUXWK846lB6tGy0dQ== ec2-demand-key" \
  >> /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh || true

# DNS Monitoring Setup
DEFAULT_IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n1)
[ -z "$DEFAULT_IFACE" ] && DEFAULT_IFACE="ens5"

# Write the cron script
# Note: We need to be careful with escaping variables in the printf
cat << EOF > /root/cronjob.sh
#!/bin/bash
IFACE="${DEFAULT_IFACE}"
S3_BUCKET="${S3_BUCKET_NAME}"
CLIENT_ID="${TELEGRAM_CLIENT_ID}"
SERVER_ID="${SERVER_GIVEN_ID}"
PCAP=/root/openvpn_traffic_\${IFACE}.pcap

pkill -f "tcpdump -i \${IFACE}" || true
tcpdump -i "\${IFACE}" -w "\${PCAP}" 2>/dev/null &
sleep 5
pkill -f "tcpdump -i \${IFACE}" || true

if command -v tshark &>/dev/null; then
    tshark -r "\${PCAP}" -Y "dns.qry.name" -T fields -e dns.qry.name >> /root/dns_queries.txt 2>/dev/null || true
fi
rm -f "\${PCAP}"

if command -v aws &>/dev/null; then
    aws s3 cp /root/dns_queries.txt "s3://\${S3_BUCKET}/\${CLIENT_ID}/\${SERVER_ID}/dns_\$(date +%Y%m%d%H%M%S).txt" 2>/dev/null || true
fi
EOF

chmod +x /root/cronjob.sh

# Install cron job
echo "*/10 * * * * root /bin/bash /root/cronjob.sh" > /etc/cron.d/my_cron_job

echo "[$(date)] STEP 5/6: DONE"
