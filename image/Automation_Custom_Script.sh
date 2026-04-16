#!/bin/bash
# =============================================================================
# SpeedBox - Script d'installation automatique pour DietPi
# Ce script est execute automatiquement au premier boot par DietPi
# =============================================================================
set -e

REPO_URL="https://github.com/dashand/speedbox.git"
INSTALL_DIR="/opt/speedbox"

echo "=========================================="
echo "  SpeedBox - Installation automatique"
echo "=========================================="

# 0. Configuration systeme
echo "[0/6] Configuration systeme..."
localectl set-locale LANG=C.UTF-8 2>/dev/null || true
localectl set-keymap fr 2>/dev/null || true
timedatectl set-timezone Europe/Paris 2>/dev/null || true
echo 'SpeedBox' > /etc/hostname
sed -i 's/127\.0\.1\.1.*/127.0.1.1\tSpeedBox/' /etc/hosts 2>/dev/null || true
echo "  OK"

# 1. Installer les paquets systeme
echo "[1/6] Installation des paquets systeme..."

# Attendre que dpkg soit libre (DietPi peut laisser des locks apres son setup initial)
echo "  Attente liberation dpkg..."
WAIT=0
while fuser /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock >/dev/null 2>&1; do
    sleep 3
    WAIT=$((WAIT + 3))
    if [ $WAIT -ge 120 ]; then
        echo "  Timeout attente dpkg, nettoyage force..."
        break
    fi
done
dpkg --configure -a 2>/dev/null || true

# Installation avec retry automatique
APT_OK=0
for attempt in 1 2 3; do
    if DEBIAN_FRONTEND=noninteractive apt-get install -y iperf3 mtr traceroute ethtool dnsutils python3-venv git hostapd dnsmasq iptables > /tmp/apt-install.log 2>&1; then
        APT_OK=1
        break
    fi
    echo "  Tentative $attempt/3 echouee, nettoyage et retry..."
    rm -f /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/cache/apt/archives/lock /var/lib/apt/lists/lock
    dpkg --configure -a 2>/dev/null || true
    sleep 10
done

if [ $APT_OK -eq 0 ]; then
    echo "ERREUR: Installation des paquets impossible apres 3 tentatives."
    echo "Log apt: $(cat /tmp/apt-install.log)"
    exit 1
fi
echo "  OK"

# 2. Cloner le depot
echo "[2/6] Telechargement de SpeedBox..."
if [ -d "$INSTALL_DIR/.git" ]; then
    cd "$INSTALL_DIR"
    git pull --ff-only
else
    git clone "$REPO_URL" "$INSTALL_DIR"
fi
echo "  OK"

# 3. Environnement Python
echo "[3/6] Installation de l'environnement Python..."
cd "$INSTALL_DIR"
python3 -m venv venv
venv/bin/pip install --quiet --upgrade pip
venv/bin/pip install --quiet -r requirements.txt
echo "  OK"

# 4. Configuration
echo "[4/6] Configuration..."
mkdir -p config results
echo "  OK"

# 5. Service systemd
echo "[5/6] Configuration du service..."
cp speedbox.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable speedbox
systemctl start speedbox
echo "  OK"

# 6. Point d'acces WiFi
echo "[6/7] Configuration du point d'acces WiFi..."

# Remplacer la config wlan0 de DietPi (station) par la config AP
# Supprimer tout bloc iface wlan0 existant et les lignes associees
sed -i '/^# WiFi/,/^$/{ /allow-hotplug wlan0/d; /iface wlan0/d; /address 192\.168\.0\./d; /netmask/d; /gateway/d; /dns-nameservers/d; /wireless-power/d; /wpa-conf/d; /pre-up.*wlan0/d; /post-down.*wlan0/d; /up iptables/d; /up ip6tables/d }' /etc/network/interfaces
sed -i '/^#allow-hotplug wlan0/d; /^allow-hotplug wlan0/d' /etc/network/interfaces

# Ajouter la config AP
cat >> /etc/network/interfaces << 'EOF'

# WiFi AP
allow-hotplug wlan0
iface wlan0 inet static
address 192.168.10.1
netmask 255.255.255.0
pre-up iw dev wlan0 set power_save off
post-down iw dev wlan0 set power_save on
up iptables-restore < /etc/iptables.ipv4.nat
up ip6tables-restore < /etc/iptables.ipv6.nat
EOF

# hostapd
cat > /etc/hostapd/hostapd.conf << 'EOF'
interface=wlan0
driver=nl80211
ssid=SpeedBox
country_code=FR
hw_mode=g
channel=3
ieee80211n=0
ieee80211ac=0
ieee80211ax=0
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=SpeedBox
wpa=2
wpa_passphrase=speedbox
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF
echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd

# dnsmasq captive portal
mkdir -p /etc/dnsmasq.d
cat > /etc/dnsmasq.d/hotspot.conf << 'EOF'
interface=wlan0
bind-interfaces
dhcp-range=192.168.10.10,192.168.10.50,255.255.255.0,1h
dhcp-option=3,192.168.10.1
dhcp-option=6,192.168.10.1
no-resolv
address=/#/192.168.10.1
EOF

# IP forwarding
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-speedbox-forward.conf
sysctl -w net.ipv4.ip_forward=1

# iptables NAT (eth0 partage sa connexion vers wlan0)
cat > /etc/iptables.ipv4.nat << 'EOF'
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i wlan0 -o eth0 -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 192.168.10.0/24 -o eth0 -j MASQUERADE
COMMIT
EOF
cat > /etc/iptables.ipv6.nat << 'EOF'
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i wlan0 -o eth0 -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o eth0 -j MASQUERADE
COMMIT
EOF
iptables-restore < /etc/iptables.ipv4.nat
ip6tables-restore < /etc/iptables.ipv6.nat

systemctl unmask hostapd 2>/dev/null || true
systemctl enable hostapd
systemctl enable dnsmasq 2>/dev/null || true
ifup wlan0 2>/dev/null || true
systemctl restart hostapd || true
systemctl restart dnsmasq || true
echo "  OK"

# 7. Reboot quotidien pour stabilite long terme
echo "[7/7] Configuration du reboot quotidien..."
CRON_LINE="0 4 * * * /sbin/reboot"
if ! crontab -l 2>/dev/null | grep -qF "$CRON_LINE"; then
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
fi
echo "  OK"

# Verification
sleep 3
if systemctl is-active --quiet speedbox; then
    IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "=========================================="
    echo "  SpeedBox installe avec succes !"
    echo "  Acces (Ethernet) : http://${IP}:5000"
    echo "  Acces (WiFi)     : http://192.168.10.1:5000"
    echo "  WiFi SSID        : SpeedBox"
    echo "  WiFi Mot de passe: speedbox"
    echo "  Mot de passe SSH : dietpi (a changer !)"
    echo "=========================================="
else
    echo "ERREUR: SpeedBox n'a pas demarre."
    echo "Logs: journalctl -u speedbox"
    exit 1
fi
