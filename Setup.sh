#!/bin/bash
set -e

echo "=== WiFi Connect kurulumu başlatılıyor... ==="

# 1. Paketlerin kurulumu
echo "1. Paketlerin kurulumu..."
sudo apt update
sudo apt install -y dnsmasq hostapd network-manager curl jq

# 2. WiFi Connect indiriliyor
echo "2. WiFi Connect indiriliyor..."
WC_VERSION="v4.4.6"
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    ARCH="linux-aarch64"
elif [ "$ARCH" = "armv7l" ]; then
    ARCH="linux-armv7"
else
    echo "Desteklenmeyen mimari: $ARCH"
    exit 1
fi

curl -L -o /tmp/wifi-connect.tar.gz "https://github.com/balena-io/wifi-connect/releases/download/$WC_VERSION/wifi-connect-$WC_VERSION-$ARCH.tar.gz"
mkdir -p /tmp/wifi-connect
tar -xzf /tmp/wifi-connect.tar.gz -C /tmp/wifi-connect
sudo mv /tmp/wifi-connect/wifi-connect /usr/local/bin/
sudo chmod +x /usr/local/bin/wifi-connect

# 3. Wrapper script oluşturuluyor
echo "3. Wrapper script oluşturuluyor..."
sudo tee /usr/local/sbin/wifi-connect-wrapper.sh > /dev/null <<'EOF'
#!/bin/bash
WLAN_IF="wlan0"

# IP varsa AP başlatma
IP_CHECK=$(ip addr show $WLAN_IF | grep "inet " || true)
if [ -n "$IP_CHECK" ]; then
    echo "$(date) - WiFi bağlı ve IP alınmış. AP başlatılmayacak."
    exit 0
else
    /usr/local/bin/wifi-connect
fi

exit 0
EOF
sudo chmod +x /usr/local/sbin/wifi-connect-wrapper.sh

# 4. Systemd servisi oluşturuluyor
echo "4. Systemd servisi oluşturuluyor..."
sudo tee /etc/systemd/system/wifi-connect.service > /dev/null <<'EOF'
[Unit]
Description=WiFi Connect AP
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/wifi-connect-wrapper.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 5. Servisi enable ve başlat
echo "5. Servis enable ve başlatılıyor..."
sudo systemctl daemon-reload
sudo systemctl enable wifi-connect.service
sudo systemctl start wifi-connect.service

echo "=== WiFi Connect kurulumu tamamlandı! ==="
