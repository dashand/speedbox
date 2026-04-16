# SpeedBox

Application web de test réseau et diagnostic pour Raspberry Pi et autres SBC (Single Board Computers).

**Network testing and diagnostics web application for Raspberry Pi and other SBCs.**

---

## Démarrage rapide / Quick start

```bash
docker run -d \
  --name speedbox \
  --network host \
  --privileged \
  --restart unless-stopped \
  seblalanne/speedbox
```

Puis ouvrir / Then open: **http://\<IP\>:5000**

---

## Avec Docker Compose / With Docker Compose

```yaml
services:
  speedbox:
    image: seblalanne/speedbox
    container_name: speedbox
    restart: unless-stopped
    network_mode: host
    privileged: true
    volumes:
      - speedbox-config:/opt/speedbox/config
      - speedbox-results:/opt/speedbox/results

volumes:
  speedbox-config:
  speedbox-results:
```

```bash
docker compose up -d
```

---

## Fonctionnalités / Features

- **SpeedTest** — Tests iperf3 TCP/UDP (upload, download, multi-stream)
- **QuickTest** — Séquence automatisée MTR + UDP + TCP vers serveurs favoris
- **Diagnostic** — Ping, MTR, DNS lookup avec analyse par hop
- **Réseau** — Configuration IP statique/DHCP, VLAN, export FTP/SFTP/SCP
- **Historique** — Graphiques Chart.js, filtrage, export
- **Interface bilingue** — Français / English

---

## Architectures supportées / Supported platforms

| Plateforme | Exemples |
|------------|---------|
| `linux/arm64` | Raspberry Pi 5, Orange Pi 5, Rock Pi 4 |
| `linux/amd64` | PC, VM, NAS, VPS |

---

## Variables d'environnement / Environment variables

| Variable | Défaut | Description |
|----------|--------|-------------|
| `ETH_INTERFACE` | auto-détecté | Nom de l'interface Ethernet principale (`eth0`, `ens18`…) |

---

## Prérequis / Requirements

- `--network host` : accès aux interfaces réseau du host
- `--privileged` : nécessaire pour ping, mtr, traceroute, ethtool

> **Note WiFi AP** : le point d'accès WiFi (hostapd/dnsmasq) n'est pas inclus dans l'image Docker. Pour une installation complète avec AP WiFi sur Raspberry Pi, utiliser l'image DietPi disponible dans les [releases GitHub](https://github.com/dashand/speedbox/releases).

---

## Volumes

| Volume | Contenu |
|--------|---------|
| `/opt/speedbox/config` | Configuration (FTP, clés de chiffrement) |
| `/opt/speedbox/results` | Résultats des tests (JSON) |

---

## Liens / Links

- [Code source / Source code](https://github.com/dashand/speedbox)
- [Releases & image SD DietPi](https://github.com/dashand/speedbox/releases)
- [Licence AGPL-3.0](https://github.com/dashand/speedbox/blob/main/LICENSE)
