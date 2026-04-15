#!/bin/bash
# SpeedBox - Script d'installation automatique
# Compatible: Debian 12+, DietPi, Raspberry Pi OS
# Licence: AGPL-3.0-only
set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/opt/speedbox"
SERVICE_NAME="speedbox"
VENV_DIR="$INSTALL_DIR/venv"

echo -e "${CYAN}"
echo "=============================================="
echo "  SpeedBox - Installation"
echo "=============================================="
echo -e "${NC}"

# Verification root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Erreur: ce script doit etre execute en root (sudo)${NC}"
    exit 1
fi

# Verification OS
if ! command -v apt &> /dev/null; then
    echo -e "${RED}Erreur: ce script necessite apt (Debian/Ubuntu)${NC}"
    exit 1
fi

echo -e "${CYAN}[1/7]${NC} Installation des paquets systeme..."
apt update -qq
apt install -y -qq iperf3 mtr traceroute ethtool dnsutils python3 python3-venv git > /dev/null 2>&1
echo -e "${GREEN}  OK${NC}"

echo -e "${CYAN}[2/7]${NC} Verification du repertoire SpeedBox..."
if [ -d "$INSTALL_DIR/.git" ]; then
    echo "  Mise a jour du depot existant..."
    cd "$INSTALL_DIR"
    git pull --ff-only
elif [ -f "$INSTALL_DIR/app.py" ]; then
    echo "  Installation existante detectee (sans git)"
    echo "  Initialisation git dans $INSTALL_DIR..."
    cd "$INSTALL_DIR"
else
    echo -e "${RED}Erreur: $INSTALL_DIR/app.py introuvable.${NC}"
    echo "  Clonez d'abord le depot :"
    echo "    git clone https://github.com/dashand/speedbox.git $INSTALL_DIR"
    exit 1
fi
echo -e "${GREEN}  OK${NC}"

echo -e "${CYAN}[3/7]${NC} Creation de l'environnement Python..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet -r "$INSTALL_DIR/requirements.txt"
echo -e "${GREEN}  OK${NC}"

echo -e "${CYAN}[4/7]${NC} Configuration initiale..."
mkdir -p "$INSTALL_DIR/config" "$INSTALL_DIR/results"
echo -e "${GREEN}  OK${NC}"

echo -e "${CYAN}[5/7]${NC} Installation du service systemd..."
cp "$INSTALL_DIR/speedbox.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable "$SERVICE_NAME" > /dev/null 2>&1
echo -e "${GREEN}  OK${NC}"

echo -e "${CYAN}[6/7]${NC} Reboot quotidien (stabilite Raspberry Pi)..."
(crontab -l 2>/dev/null | grep -q "/sbin/reboot" || (crontab -l 2>/dev/null; echo "0 4 * * * /sbin/reboot") | crontab -)
echo -e "${GREEN}  OK${NC}"

echo -e "${CYAN}[7/7]${NC} Demarrage de SpeedBox..."
systemctl restart "$SERVICE_NAME"
sleep 2

if systemctl is-active --quiet "$SERVICE_NAME"; then
    IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}=============================================="
    echo "  SpeedBox est installe et demarre !"
    echo ""
    echo "  Acces : http://${IP}:5000"
    echo "=============================================="
    echo -e "${NC}"
else
    echo -e "${RED}Erreur: le service n'a pas demarre.${NC}"
    echo "  Consultez les logs : journalctl -u $SERVICE_NAME"
    exit 1
fi
