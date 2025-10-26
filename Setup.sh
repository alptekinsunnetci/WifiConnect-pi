#!/bin/bash
set -e

echo "1. Paketlerin kurulumu..."
sudo apt update
sudo apt install -y network-manager iw wireless-tools curl dnsmasq hostapd

echo "2. Wifi-Connect indirme ve kurulum..."
cd /tmp
curl -L -o wifi-connect.tar.gz https://github.com/balena-os/wifi-connect/releases/download/v4.4.6/wifi-connect-v4.4.6-linux-aarch64.tar.gz
tar -xzf wifi-connect.tar.gz
sudo mv wifi-connect /usr/local/sbin/
sudo chmod +x /usr/local/sbin/wifi-connect

echo "3. Config dizini ve dosyasını oluşturma..."
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

echo "4. Wrapper script oluşturma..."
sudo tee /usr/local/sbin/wifi-connect-wrapper.sh > /dev/null <<'EOF'
#!/bin/bash
WLAN_IF="wlan0"

# IP var mı kontrol et
IP_CHECK=$(ip addr show $WLAN_IF | grep "inet " || true)

if [ -n "$IP_CHECK" ]; then
    echo "$(date) - WiFi bağlı ve IP alınmış. AP başlatılmayacak."
    exit 0
else
    echo "$(date) - WiFi bağlı değil veya IP yok. WiFi Connect AP başlatılıyor."
    exec /usr/local/sbin/wifi-connect --config /etc/wifi-connect/config.json
fi
EOF
sudo chmod +x /usr/local/sbin/wifi-connect-wrapper.sh

echo "5. Systemd servisi oluşturma..."
sudo tee /etc/systemd/system/wifi-connect.service > /dev/null <<EOF
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

echo "6. Servisi etkinleştirme..."
sudo systemctl daemon-reload
sudo systemctl enable wifi-connect.service
sudo systemctl restart wifi-connect.service

echo "Kurulum tamamlandı! Servisin durumu:"
sudo systemctl status wifi-connect.service
