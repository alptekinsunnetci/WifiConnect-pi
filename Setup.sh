#!/bin/bash
# Setup script for WiFi Connect autostart

set -e

echo "=== WiFi Connect Setup Başlatılıyor ==="

# 1️⃣ Wifi-connect indir ve kur
echo "Wifi-connect indiriliyor..."
curl -L https://github.com/balena-os/wifi-connect/releases/download/v4.4.6/wifi-connect-v4.4.6-linux-aarch64.tar.gz -o /tmp/wifi-connect.tar.gz
tar -xzf /tmp/wifi-connect.tar.gz -C /tmp
sudo mv /tmp/wifi-connect /usr/local/sbin/
sudo chmod +x /usr/local/sbin/wifi-connect
echo "Wifi-connect kuruldu."

# 2️⃣ Wrapper script oluştur
echo "Wrapper script oluşturuluyor..."
cat << 'EOF' | sudo tee /usr/local/sbin/wifi-connect-wrapper.sh
#!/bin/bash
# WiFi Connect Startup Script

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "=== WiFi Connect Startup Başlatılıyor ==="

# Stop conflicting services
systemctl stop hostapd 2>/dev/null
systemctl stop dnsmasq 2>/dev/null
killall dnsmasq 2>/dev/null

# RF-kill unblock
rfkill unblock all

# Reset wlan0
nmcli radio wifi off
ip addr flush dev wlan0
ip link set wlan0 up
nmcli radio wifi on

# Remove old WiFi Connect connections
nmcli connection delete "WiFi Connect" 2>/dev/null

# Make sure 192.168.42.1 is free
ip addr del 192.168.42.1/24 dev wlan0 2>/dev/null

# Start WiFi Connect
log "WiFi Connect başlatılıyor..."
/usr/local/sbin/wifi-connect --portal-interface wlan0

log "WiFi Connect tamamlandı."
exit 0
EOF

sudo chmod +x /usr/local/sbin/wifi-connect-wrapper.sh
echo "Wrapper script hazır."

# Startup olarak ekle (rc.local)
echo "Startup için /etc/rc.local ayarlanıyor..."
sudo bash -c 'cat << EOF > /etc/rc.local
#!/bin/bash
/usr/local/sbin/wifi-connect-wrapper.sh &
exit 0
EOF'

sudo chmod +x /etc/rc.local
echo "Startup ayarlandı (/etc/rc.local)."

echo "=== WiFi Connect Setup Tamamlandı ==="
echo "Makineyi yeniden başlattığınızda WiFi Connect otomatik olarak başlayacaktır."
