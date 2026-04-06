# SpeedBox - Image SD Pre-built

Ce dossier contient les outils pour creer une image SD "cles en main" de SpeedBox.

## Methode 1 : Automation DietPi (recommandee pour creer l'image)

Cette methode configure une image DietPi vierge pour installer SpeedBox automatiquement au premier demarrage.

### Prerequis

- Image DietPi officielle pour Raspberry Pi 5 : https://dietpi.com/#download
- Un lecteur de carte SD
- Logiciel de flash : [balenaEtcher](https://etcher.balena.io/) ou `dd`

### Etapes

1. **Flasher l'image DietPi** sur une carte SD (16 Go minimum)

2. **Monter la partition boot** de la carte SD sur votre PC

3. **Modifier `/boot/dietpi.txt`** avec les valeurs de `dietpi.txt.patch` :
   ```bash
   # Les lignes cles a modifier :
   AUTO_SETUP_GLOBAL_PASSWORD=VotreMotDePasse
   AUTO_SETUP_NET_HOSTNAME=SpeedBox
   AUTO_SETUP_AUTOMATED=1
   AUTO_SETUP_CUSTOM_SCRIPT_EXEC=1
   AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=1
   ```

4. **Copier le script d'installation** :
   ```bash
   cp Automation_Custom_Script.sh /boot/
   ```

5. **Ejecter la carte SD** et l'inserer dans le Raspberry Pi

6. **Connecter le Pi en Ethernet** (DHCP requis) et demarrer

7. **Attendre ~5-10 minutes** : DietPi fait sa configuration initiale puis installe SpeedBox

8. SpeedBox est accessible sur `http://<IP-du-Pi>:5000`

---

## Methode 2 : Creer une image .img pre-built

Cette methode clone une installation existante pour creer une image prete a flasher.

### Prerequis

- Un Raspberry Pi 5 avec SpeedBox installe et fonctionnel
- Un PC Linux (ou un 2e Pi) avec `pishrink.sh`
- Un lecteur de carte SD USB

### Etape 1 : Preparer le Pi source

Avant de cloner, nettoyer l'installation pour une image propre :

```bash
# Supprimer les resultats de test
rm -f /opt/speedbox/results/*.json

# Supprimer les secrets (seront regeneres au prochain boot)
rm -f /opt/speedbox/config/.secret_key
rm -f /opt/speedbox/config/ftp_config.json

# Vider les logs
journalctl --rotate && journalctl --vacuum-time=1s
rm -f /var/tmp/dietpi/logs/*.log

# Vider l'historique bash
> /root/.bash_history
> /home/dietpi/.bash_history

# Reinitialiser le hostname si besoin
hostnamectl set-hostname SpeedBox

# Arreter proprement
sudo shutdown -h now
```

### Etape 2 : Cloner la carte SD

Sur un PC Linux, inserer la carte SD du Pi et la cloner :

```bash
# Identifier le device (ex: /dev/sdb)
lsblk

# Cloner la carte SD (ATTENTION au device !)
sudo dd if=/dev/sdb of=speedbox-v1.0.0.img bs=4M status=progress

# Ou avec dcfldd pour plus de feedback
sudo dcfldd if=/dev/sdb of=speedbox-v1.0.0.img bs=4M sizeprobe=if
```

### Etape 3 : Reduire l'image avec PiShrink

```bash
# Installer pishrink si pas deja fait
wget https://raw.githubusercontent.com/Drewsif/PiShrink/master/pishrink.sh
chmod +x pishrink.sh
sudo mv pishrink.sh /usr/local/bin/

# Reduire l'image (supprime l'espace vide, active l'expansion auto)
sudo pishrink.sh -z speedbox-v1.0.0.img
```

Resultat : `speedbox-v1.0.0.img.gz` (~1-2 Go au lieu de 16-32 Go)

### Etape 4 : Flasher l'image

```bash
# Avec dd
gunzip -c speedbox-v1.0.0.img.gz | sudo dd of=/dev/sdX bs=4M status=progress

# Ou avec balenaEtcher (interface graphique)
```

### Etape 5 : Premier demarrage

Au premier boot :
- La partition s'etend automatiquement (grace a PiShrink)
- La cle secrete Flask est regeneree automatiquement
- SpeedBox est immediatement accessible sur `http://<IP>:5000`

---

## Notes importantes

### Securite
- **Changer le mot de passe** par defaut apres le premier boot : `passwd`
- La cle secrete Flask est generee automatiquement, unique par installation
- Les identifiants FTP ne sont jamais inclus dans l'image

### Reseau
- Par defaut, le Pi utilise **DHCP sur eth0**
- L'IP peut etre configuree via l'interface SpeedBox (page Reseau)
- Le hostname par defaut est "SpeedBox"

### Mises a jour
Pour mettre a jour SpeedBox sur une image deployee :
```bash
cd /opt/speedbox
git pull
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart speedbox
```
