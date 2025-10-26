#!/bin/bash
# === WiFi Connect Setup Script ===

set -e

echo "=== WiFi Connect kurulumu başlatılıyor... ==="

# 1. Gerekli paketler
echo "1. Paketlerin kurulumu..."
sudo apt update
sudo apt install -y dnsmasq hostapd network-manager curl jq

# 2. wifi-connect ikililerini indir
echo "2. WiFi Connect indiriliyor..."
sudo curl -L -o /usr/local/bin/wifi-connect https://github.com/alptekinsunnetci/WifiConnect-pi/raw/main/wifi-connect
sudo chmod +x /usr/local/bin/wifi-connect

# 3. Wrapper script oluşturuluyor
echo "3. Wrapper script oluşturuluyor..."
cat << 'EOF' | sudo tee /usr/local/sbin/wifi-connect-wrapper.sh
#!/bin/bash
# === Wrapper Script for WiFi Connect ===

# RF-kill ve servisleri temizle
sudo rfkill unblock all
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo killall dnsmasq 2>/dev/null || true

# WiFi adaptörü resetle
sudo nmcli radio wifi off
sudo ip addr flush dev wlan0
sudo ip link set wlan0 up
sudo nmcli radio wifi on

# WiFi bağlantısı kontrolü
if nmcli -t -f WIFI g | grep -q "enabled"; then
    echo "$(date) - WiFi cihaz aktif, AP başlatılacak..."
    sudo /usr/local/bin/wifi-connect --portal-interface wlan0
else
    echo "$(date) - WiFi bağlı ve IP alınmış. AP başlatılmayacak."
fi
EOF

sudo chmod +x /usr/local/sbin/wifi-connect-wrapper.sh

# 4. Systemd servisi oluşturuluyor
echo "4. Systemd servisi oluşturuluyor..."
cat << 'EOF' | sudo tee /etc/systemd/system/wifi-connect.service
[Unit]
Description=WiFi Connect AP
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/wifi-connect-wrapper.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 5. Servis enable ve başlatılıyor
sudo systemctl daemon-reload
sudo systemctl enable --now wifi-connect.service

echo "=== WiFi Connect kurulumu tamamlandı! ==="
