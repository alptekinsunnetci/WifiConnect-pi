#!/bin/bash
set -e

echo "=== WiFi Connect kurulumu başlatılıyor... ==="

# 1. Paketlerin kurulumu
echo "1. Paketlerin kurulumu..."
apt update
apt install -y network-manager dnsmasq hostapd jq curl

# 2. Wifi Connect indirme ve kurulum
echo "2. WiFi Connect indiriliyor..."
WC_VERSION="v4.4.6"
WC_FILE="wifi-connect-${WC_VERSION}-linux-aarch64.tar.gz"
curl -L -o /tmp/$WC_FILE "https://github.com/balena-os/wifi-connect/releases/download/${WC_VERSION}/$WC_FILE"
tar -xzf /tmp/$WC_FILE -C /tmp
mv /tmp/wifi-connect /usr/local/bin/wifi-connect
chmod +x /usr/local/bin/wifi-connect

# 3. Config dizini ve dosyası
echo "3. Config dizini ve dosyası oluşturuluyor..."
mkdir -p /etc/wifi-connect
cat > /etc/wifi-connect/config.json <<EOF
{
    "portal_ssid": "WiFi Connect",
    "portal_password": "12345678",
    "portal_ip": "192.168.42.1",
    "portal_port": 80,
    "wifi_scan_timeout": 10,
    "wifi_scan_repeat": 3
}
EOF

# 4. Wrapper script
echo "4. Wrapper script oluşturuluyor..."
cat > /usr/local/sbin/wifi-connect-wrapper.sh <<'EOF'
#!/bin/bash
WLAN_IF="wlan0"

# IP kontrolü
IP_CHECK=$(ip addr show $WLAN_IF | grep "inet " || true)

if [ -n "$IP_CHECK" ]; then
    echo "$(date) - WiFi bağlı ve IP alınmış. AP başlatılmayacak."
    exit 0
else
    echo "$(date) - WiFi bağlı değil veya IP yok. WiFi Connect AP başlatılıyor."
    exec /usr/local/bin/wifi-connect --portal-ip 192.168.42.1 --config /etc/wifi-connect/config.json
fi
EOF

chmod +x /usr/local/sbin/wifi-connect-wrapper.sh

# 5. Systemd servisi
echo "5. Systemd servisi oluşturuluyor..."
cat > /etc/systemd/system/wifi-connect.service <<'EOF'
[Unit]
Description=WiFi Connect AP
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/wifi-connect-wrapper.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 6. Servisi etkinleştirme
echo "6. Servisi etkinleştiriliyor..."
systemctl daemon-reload
systemctl enable wifi-connect.service
systemctl restart wifi-connect.service

echo "=== Kurulum tamamlandı! ==="
systemctl status wifi-connect.service --no-pager
