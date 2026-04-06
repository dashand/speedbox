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
apt-get install -y -qq iperf3 mtr traceroute ethtool dnsutils python3-venv git > /dev/null 2>&1
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
