# SpeedBox - Déploiement sur image DietPi

Ce dossier contient les outils pour déployer SpeedBox sur un Raspberry Pi via une image DietPi.

## Méthode 1 : Automation DietPi (recommandée)

Cette méthode configure une image DietPi vierge pour installer SpeedBox automatiquement au premier démarrage.

### Prérequis

- Image DietPi officielle pour Raspberry Pi 5 : https://dietpi.com/#download
- Une carte SD (16 Go minimum)
- Logiciel de flash : [balenaEtcher](https://etcher.balena.io/) ou `dd`

### Étapes

**1. Flasher l'image DietPi** sur la carte SD avec balenaEtcher ou `dd`

**2. Ouvrir la partition boot** de la carte SD (appelée `bootfs`) — accessible depuis Windows, Mac ou Linux

**3. Copier `Automation_Custom_Script.sh`** à la racine de la partition boot

**4. Modifier `dietpi.txt`** avec un éditeur de texte (Notepad sur Windows) — une seule ligne à changer :
   ```
   AUTO_SETUP_AUTOMATED=1
   ```

**5. Éjecter la carte SD**, l'insérer dans le Raspberry Pi et **connecter l'Ethernet**

**6. Démarrer le Pi** et attendre ~5-10 minutes

SpeedBox est accessible sur `http://<IP-du-Pi>:5000`

> **Sur Linux/Mac**, vous pouvez utiliser `apply-config.sh` pour automatiser les étapes 3 et 4 :
> ```bash
> bash apply-config.sh /media/user/bootfs
> ```

> **Mot de passe SSH par défaut** : `dietpi` — à changer après installation avec `passwd`

---

## Méthode 2 : Créer une image .img pré-construite

Cette méthode clone une installation existante et fonctionnelle pour créer une image prête à flasher.

### Prérequis

- Un Raspberry Pi 5 avec SpeedBox installé et fonctionnel
- Un lecteur de carte SD USB
- PC Windows (méthode A) ou PC Linux natif (méthode B — **recommandée** si disponible)

### Étape 1 : Préparer le Pi source

Nettoyer l'installation avant de cloner via SSH :

```bash
# Supprimer les résultats de test
rm -f /opt/speedbox/results/*.json

# Supprimer les secrets (seront régénérés au prochain boot)
rm -f /opt/speedbox/config/.secret_key
rm -f /opt/speedbox/config/.fernet_key
rm -f /opt/speedbox/config/ftp_config.json

# Vider les logs
journalctl --rotate && journalctl --vacuum-time=1s
rm -f /var/tmp/dietpi/logs/*.log

# Vider l'historique bash
> /root/.bash_history
> /home/dietpi/.bash_history

# Arrêter proprement
sudo shutdown -h now
```

### Étape 2 (Méthode A — Windows) : Cloner et compresser

Les partitions Linux ne sont pas accessibles par Windows directement. Il faut passer par la lecture brute du disque physique.

**2a. Libérer le disque avec diskpart** (PowerShell admin) :

```
diskpart
list disk
select disk N        ← numéro du lecteur SD
offline disk
exit
```

**2b. Lire le disque brut avec PowerShell** (admin) — remplacer `N` par le numéro de disque et `SIZE` par la taille en octets :

```powershell
$src  = [System.IO.File]::OpenRead('\\.\PhysicalDriveN')
$dst  = [System.IO.File]::OpenWrite('C:\speedbox-vX.Y.Z.img')
$buf  = New-Object byte[] (4MB)
$read = 0
while (($n = $src.Read($buf, 0, $buf.Length)) -gt 0) {
    $dst.Write($buf, 0, $n)
    $read += $n
    Write-Progress -Activity "dd" -Status "$([math]::Round($read/1GB,2)) Go"
}
$src.Close(); $dst.Close()
```

**2c. Compresser dans WSL2** :

```bash
gzip -9 --keep speedbox-vX.Y.Z.img
```

> **Note** : PiShrink n'est pas utilisable dans WSL2 (loop devices non supportés). L'image résultante a la taille complète de la carte SD (compressée ~640 Mo pour 16 Go). Une carte SD ≥ 16 Go est requise pour flasher.

### Étape 2 (Méthode B — Linux natif) : Cloner, réduire et compresser

```bash
# Identifier le device (ex: /dev/sdb)
lsblk

# Cloner la carte SD
sudo dd if=/dev/sdb of=speedbox-vX.Y.Z.img bs=4M status=progress

# Réduire avec PiShrink (supprime l'espace vide, active l'expansion au boot)
wget https://raw.githubusercontent.com/Drewsif/PiShrink/master/pishrink.sh
chmod +x pishrink.sh && sudo mv pishrink.sh /usr/local/bin/
sudo pishrink.sh -z speedbox-vX.Y.Z.img
```

Résultat : `speedbox-vX.Y.Z.img.gz` (~300-500 Mo, flashable sur carte ≥ 8 Go)

### Étape 3 : Flasher l'image

```bash
# Avec dd (Linux/Mac)
gunzip -c speedbox-vX.Y.Z.img.gz | sudo dd of=/dev/sdX bs=4M status=progress

# Ou avec balenaEtcher (interface graphique, Windows/Mac/Linux)
```

### Étape 4 : Premier démarrage

Au premier boot :
- Si créée avec PiShrink : la partition s'étend automatiquement
- Les clés secrètes Flask et Fernet sont régénérées automatiquement
- SpeedBox est immédiatement accessible sur `http://<IP>:5000`

---

## Notes importantes

### Sécurité
- **Changer le mot de passe** après le premier boot : `passwd`
- Les clés secrètes Flask et Fernet sont générées automatiquement, uniques par installation
- Les identifiants FTP ne sont jamais inclus dans l'image

### Réseau
- **Ethernet** : IP statique `192.168.0.100` (configurable dans `dietpi.txt` avant boot)
- **WiFi** : point d'accès activé automatiquement
  - SSID : `SpeedBox`
  - Mot de passe : `speedbox`
  - IP du Pi sur le réseau WiFi : `192.168.10.1`
  - SpeedBox accessible sur `http://192.168.10.1:5000` depuis le WiFi
  - Le portail captif redirige tout le trafic DNS vers le Pi
  - Le Pi fait office de routeur (NAT eth0 → wlan0) : les clients WiFi ont accès à Internet via l'Ethernet du Pi
- Le hostname par défaut est `SpeedBox`

### Mises à jour
Pour mettre à jour SpeedBox sur une installation déployée :
```bash
cd /opt/speedbox
git pull
venv/bin/pip install -r requirements.txt
sudo systemctl restart speedbox
```
