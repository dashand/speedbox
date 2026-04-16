#!/bin/bash
# =============================================================================
# SpeedBox - Script de configuration de la partition boot DietPi
# =============================================================================
# Usage : bash apply-config.sh /chemin/vers/partition/boot
#         bash apply-config.sh /media/user/bootfs
#
# Ce script est autonome : il n'a besoin d'aucun autre fichier.
# Mot de passe par défaut : SpeedBox!  — à changer après installation : passwd
# =============================================================================

set -e

BOOT_DIR="${1:-}"

if [ -z "$BOOT_DIR" ]; then
    echo "Usage: bash apply-config.sh /chemin/vers/partition/boot"
    echo "Exemple: bash apply-config.sh /media/user/bootfs"
    exit 1
fi

if [ ! -f "$BOOT_DIR/dietpi.txt" ]; then
    echo "Erreur: $BOOT_DIR/dietpi.txt introuvable."
    echo "Vérifiez que la partition boot est bien montée."
    exit 1
fi

echo "============================================"
echo "  SpeedBox - Configuration DietPi"
echo "============================================"

echo "[1/2] Application des paramètres dans dietpi.txt..."

sed -i 's/^AUTO_SETUP_GLOBAL_PASSWORD=.*/AUTO_SETUP_GLOBAL_PASSWORD=SpeedBox!/'      "$BOOT_DIR/dietpi.txt"
sed -i 's/^AUTO_SETUP_LOCALE=.*/AUTO_SETUP_LOCALE=C.UTF-8/'                          "$BOOT_DIR/dietpi.txt"
sed -i 's/^AUTO_SETUP_KEYBOARD_LAYOUT=.*/AUTO_SETUP_KEYBOARD_LAYOUT=fr/'             "$BOOT_DIR/dietpi.txt"
sed -i 's/^AUTO_SETUP_TIMEZONE=.*/AUTO_SETUP_TIMEZONE=Europe\/Paris/'                "$BOOT_DIR/dietpi.txt"
sed -i 's/^AUTO_SETUP_NET_ETHERNET_ENABLED=.*/AUTO_SETUP_NET_ETHERNET_ENABLED=1/'    "$BOOT_DIR/dietpi.txt"
sed -i 's/^AUTO_SETUP_NET_WIFI_ENABLED=.*/AUTO_SETUP_NET_WIFI_ENABLED=0/'            "$BOOT_DIR/dietpi.txt"
sed -i 's/^AUTO_SETUP_NET_HOSTNAME=.*/AUTO_SETUP_NET_HOSTNAME=SpeedBox/'             "$BOOT_DIR/dietpi.txt"
sed -i 's/^AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=.*/AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=1/'  "$BOOT_DIR/dietpi.txt"
sed -i 's/^AUTO_SETUP_AUTOMATED=.*/AUTO_SETUP_AUTOMATED=1/'                          "$BOOT_DIR/dietpi.txt"
sed -i 's/^AUTO_SETUP_CUSTOM_SCRIPT_EXEC=.*/AUTO_SETUP_CUSTOM_SCRIPT_EXEC=1/'        "$BOOT_DIR/dietpi.txt"
sed -i 's/^AUTO_SETUP_AUTOSTART_TARGET_INDEX=.*/AUTO_SETUP_AUTOSTART_TARGET_INDEX=7/' "$BOOT_DIR/dietpi.txt"
sed -i 's/^AUTO_SETUP_AUTOSTART_LOGIN_USER=.*/AUTO_SETUP_AUTOSTART_LOGIN_USER=root/' "$BOOT_DIR/dietpi.txt"
sed -i 's/^AUTO_SETUP_SSH_SERVER_INDEX=.*/AUTO_SETUP_SSH_SERVER_INDEX=-1/'           "$BOOT_DIR/dietpi.txt"
sed -i 's/^SURVEY_OPTED_IN=.*/SURVEY_OPTED_IN=0/'                                    "$BOOT_DIR/dietpi.txt"

echo "  OK"

echo "[2/2] Écriture du script d'installation automatique..."

cat > "$BOOT_DIR/Automation_Custom_Script.sh" << 'INSTALL_SCRIPT'
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

# 1. Installer les paquets systeme
echo "[1/5] Installation des paquets systeme..."

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
    if apt-get install -y iperf3 mtr traceroute ethtool dnsutils python3-venv git > /tmp/apt-install.log 2>&1; then
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
echo "[2/5] Telechargement de SpeedBox..."
if [ -d "$INSTALL_DIR/.git" ]; then
    cd "$INSTALL_DIR"
    git pull --ff-only
else
    git clone "$REPO_URL" "$INSTALL_DIR"
fi
echo "  OK"

# 3. Environnement Python
echo "[3/5] Installation de l'environnement Python..."
cd "$INSTALL_DIR"
python3 -m venv venv
venv/bin/pip install --quiet --upgrade pip
venv/bin/pip install --quiet -r requirements.txt
echo "  OK"

# 4. Configuration
echo "[4/5] Configuration..."
mkdir -p config results
echo "  OK"

# 5. Service systemd
echo "[5/5] Configuration du service..."
cp speedbox.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable speedbox
systemctl start speedbox
echo "  OK"

# Verification
sleep 3
if systemctl is-active --quiet speedbox; then
    IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "=========================================="
    echo "  SpeedBox installe avec succes !"
    echo "  Acces : http://${IP}:5000"
    echo "=========================================="
else
    echo "ERREUR: SpeedBox n'a pas demarre."
    echo "Logs: journalctl -u speedbox"
    exit 1
fi
INSTALL_SCRIPT

chmod +x "$BOOT_DIR/Automation_Custom_Script.sh"
echo "  OK"

echo ""
echo "============================================"
echo "  Configuration terminée !"
echo ""
echo "  Mot de passe par défaut : SpeedBox!"
echo "  >> Changez-le après installation : passwd"
echo ""
echo "  Éjectez la carte SD, insérez-la dans le"
echo "  Raspberry Pi et démarrez."
echo "  SpeedBox sera accessible sur http://<IP>:5000"
echo "  (~5-10 min au premier boot)"
echo "============================================"
