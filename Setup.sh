#!/bin/bash
set -e

# Değişkenler
WIFI_CONNECT_VERSION="4.4.6"
WIFI_CONNECT_URL="https://github.com/balena-os/wifi-connect/releases/download/v${WIFI_CONNECT_VERSION}/wifi-connect-v${WIFI_CONNECT_VERSION}-linux-aarch64.tar.gz"
WIFI_CONNECT_BIN="/usr/local/sbin/wifi-connect"
CONFIG_DIR="/etc/wifi-connect"
CONFIG_FILE="${CONFIG_DIR}/config.json"
WRAPPER_SCRIPT="/usr/local/sbin/wifi-connect-wrapper.sh"
SERVICE_FILE="/etc/systemd/system/wifi-connect.service"
WLAN_IF="wlan0"

echo "1. Paketlerin kurulumu..."
sudo apt update
sudo apt install -y network-manager dnsmasq hostapd iw wireless-tools curl

echo "2. Wifi-Connect indirme ve kurulum..."
cd /tmp
wget -O wifi-connect.tar.gz "$WIFI_CONNECT_URL"
tar -xzf wifi-connect.tar.gz
sudo mv wifi-connect "$WIFI_CONNECT_BIN"
sudo chmod +x "$WIFI_CONNECT_BIN"

echo "3. Config dizini ve dosyasını oluşturma..."
sudo mkdir -p "$CONFIG_DIR"

cat <<EOF | sudo tee "$CONFIG_FILE"
{
    "portal_ssid": "WiFi Connect",
    "portal_password": "12345678",
    "portal_ip": "192.168.42.1",
    "portal_port": 80,
    "wifi_scan_timeout": 10,
    "wifi_scan_repeat": 3
}
EOF

echo "4. Wrapper script oluşturma..."
cat <<'EOF' | sudo tee "$WRAPPER_SCRIPT"
#!/bin/bash
WLAN_IF="wlan0"
IP_CHECK=$(ip addr show $WLAN_IF | grep "inet " || true)

if [ -n "$IP_CHECK" ]; then
    echo "WiFi bağlı ve IP alınmış. AP başlatılmayacak."
    exit 0
else
    echo "WiFi bağlı değil veya IP yok. WiFi Connect AP başlatılıyor."
    exec /usr/local/sbin/wifi-connect --config /etc/wifi-connect/config.json
fi
EOF

sudo chmod +x "$WRAPPER_SCRIPT"

echo "5. Systemd servisi oluşturma..."
cat <<EOF | sudo tee "$SERVICE_FILE"
[Unit]
Description=WiFi Connect AP
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$WRAPPER_SCRIPT
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "6. Servisi etkinleştirme..."
sudo systemctl daemon-reload
sudo systemctl enable wifi-connect
sudo systemctl start wifi-connect

echo "Kurulum tamamlandı! Servisin durumu:"
sudo systemctl status wifi-connect --no-pager

echo "Cihaz internete bağlı değilse AP otomatik olarak 192.168.42.1 üzerinde açılacak."
