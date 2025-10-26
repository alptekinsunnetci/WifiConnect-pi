#!/bin/bash
set -e

echo "=== WiFi Connect kurulumu başlatılıyor... ==="

# Gereken paketleri kur
sudo apt update
sudo apt install -y curl dnsmasq network-manager jq

# WiFi Connect binary'sini indir
if [ ! -f /usr/local/bin/wifi-connect ]; then
    echo "WiFi Connect indiriliyor..."
    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64) FILE="wifi-connect-v4.4.2-linux-aarch64" ;;
        armv7l)  FILE="wifi-connect-v4.4.2-linux-armv7hf" ;;
        x86_64)  FILE="wifi-connect-v4.4.2-linux-x64" ;;
        *) echo "Desteklenmeyen mimari: $ARCH"; exit 1 ;;
    esac

    curl -L -o /usr/local/bin/wifi-connect "https://github.com/balena-os/wifi-connect/releases/download/v4.4.2/$FILE"
    chmod +x /usr/local/bin/wifi-connect
    echo "WiFi Connect başarıyla kuruldu."
fi

# Wrapper script oluştur
cat << 'EOF' | sudo tee /usr/local/sbin/wifi-connect-wrapper.sh > /dev/null
#!/bin/bash
set -e

echo "$(date) - WiFi Connect servisi başlatılıyor..."

IFACE="wlan0"
if ! nmcli device | grep -q "$IFACE"; then
  echo "Wi-Fi arayüzü ($IFACE) bulunamadı!"
  exit 1
fi

if ! nmcli -t -f WIFI g | grep -q "enabled"; then
  nmcli radio wifi on
fi

CONNECTED=$(nmcli -t -f DEVICE,STATE dev | grep "$IFACE" | grep "connected" || true)
if [ -z "$CONNECTED" ]; then
  echo "Wi-Fi bağlantısı yok, erişim noktası başlatılıyor..."
  /usr/local/bin/wifi-connect \
    --portal-ssid "DeviceSetup" \
    --portal-passphrase "12345678"
else
  echo "Wi-Fi zaten bağlı, erişim noktası başlatılmayacak."
fi
EOF

sudo chmod +x /usr/local/sbin/wifi-connect-wrapper.sh

# systemd servisini oluştur
cat << 'EOF' | sudo tee /etc/systemd/system/wifi-connect.service > /dev/null
[Unit]
Description=WiFi Connect AP
After=network.target NetworkManager.service
StartLimitIntervalSec=0

[Service]
ExecStart=/usr/local/sbin/wifi-connect-wrapper.sh
Restart=always
RestartSec=15
User=root

[Install]
WantedBy=multi-user.target
EOF

# Servisi başlat
sudo systemctl daemon-reload
sudo systemctl enable wifi-connect.service
sudo systemctl restart wifi-connect.service

echo "=== WiFi Connect servisi başarıyla kuruldu ve başlatıldı! ==="
sudo systemctl status wifi-connect.service --no-pager
