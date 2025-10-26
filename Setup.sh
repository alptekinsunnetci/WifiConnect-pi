#!/bin/bash

set -e

echo "=== WiFi Connect kurulumu başlatılıyor... ==="

# 1. Gerekli paketlerin kurulumu
echo "1. Paketlerin kurulumu..."
sudo apt update
sudo apt install -y dnsmasq hostapd network-manager curl jq

# 2. wifi-connect indirme
echo "2. WiFi Connect indiriliyor..."
WC_VERSION="v4.4.6"
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    WC_ARCH="linux-aarch64"
else
    echo "Desteklenmeyen mimari: $ARCH"
    exit 1
fi
cd /tmp
curl -L -o wifi-connect.tar.gz https://github.com/balena-os/wifi-connect/releases/download/$WC_VERSION/wifi-connect-$WC_VERSION-$WC_ARCH.tar.gz
tar -xzf wifi-connect.tar.gz
sudo mv wifi-connect-$WC_VERSION-$WC_ARCH/wifi-connect /usr/local/bin/
sudo chmod +x /usr/local/bin/wifi-connect
rm -rf wifi-connect-$WC_VERSION-$WC_ARCH wifi-connect.tar.gz

# 3. Config dizini ve dosyası
echo "3. Config dizini ve dosyası oluşturuluyor..."
sudo mkdir -p /etc/wifi-connect
sudo tee /etc/wifi-connect/config.json > /dev/null <<EOF
{
    "portal_ssid": "WiFi Connect",
    "portal_password": "12345678",
    "portal_ip": "192.168.42.1",
    "portal_port": 80,
    "wifi_scan_timeout": 10,
    "wifi_scan_repeat": 3
}
EOF

# 4. Wrapper script oluşturma
echo "4. Wrapper script oluşturuluyor..."
sudo tee /usr/local/sbin/wifi-connect-wrapper.sh > /dev/null <<'EOF'
#!/bin/bash
WLAN_IF="wlan0"

# IP varsa AP başlatma
IP_CHECK=$(ip addr show $WLAN_IF | grep "inet " || true)
if [ -n "$IP_CHECK" ]; then
    echo "WiFi bağlı ve IP alınmış. AP başlatılmayacak."
    exit 0
else
    echo "WiFi bağlı değil veya IP yok. WiFi Connect AP başlatılıyor."
    /usr/local/bin/wifi-connect
fi
EOF

sudo chmod +x /usr/local/sbin/wifi-connect-wrapper.sh

# 5. Systemd servisi oluşturma
echo "5. Systemd servisi oluşturuluyor..."
sudo tee /etc/systemd/system/wifi-connect.service > /dev/null <<'EOF'
[Unit]
Description=WiFi Connect AP
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/wifi-connect-wrapper.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 6. Servisi etkinleştirme
echo "6. Servisi etkinleştir ve başlat..."
sudo systemctl daemon-reload
sudo systemctl enable wifi-connect.service
sudo systemctl start wifi-connect.service

echo "=== Kurulum tamamlandı! Servis durumu: ==="
sudo systemctl status wifi-connect.service
