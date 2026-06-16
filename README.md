# ASNUX

**Audio Streams NUX** — Moteur audio basse latence pour Linux (équivalent ASIO4ALL)

## Composants

| Composant | Langage | Description |
|-----------|---------|-------------|
| `kernel/` | C | Driver ALSA virtuel basse latence |
| `daemon/` | Rust | Daemon système (gestion module + configuration) |
| `gui/` | Rust (egui) | Interface graphique de configuration |

## Build

```bash
# Tout builder en local
make all

# Ou un composant spécifique
make kernel
make daemon
make gui
```

Les packages sont buildés automatiquement via GitHub Actions sur chaque tag `v*`.

## Installation

```bash
# Depuis une release GitHub
sudo dpkg -i asnux-*.deb          # Debian/Ubuntu
sudo rpm -ivh asnux-*.rpm          # Fedora/RHEL
sudo pacman -U asnux-*.pkg.tar.zst # Arch/Manjaro
./ASNUX-*.AppImage                 # Universel
sudo ./install_asnux.sh            # Runfile universel
```

## Utilisation

1. Lancer `asnux-gui` (ou depuis le menu applications)
2. Configurer buffer, sample rate, canaux
3. Cliquer "Charger le module"
4. Définir ASNUX comme moteur par défaut (optionnel)

## Dépannage

### Vérifier qu'ASNUX est actif

```bash
# Récupérer le numéro de carte ASNUX (peut varier : 0, 1, 2...)
CARD=$(cat /proc/asound/cards | grep -i asnux | head -1 | awk '{print $1}')

lsmod | grep asnux                       # Module chargé ?
cat /proc/asound/cards | grep -i asnux    # Carte ALSA présente ?
aplay -l | grep -i asnux                  # Périphérique playback visible ?
cat /sys/module/asnux/parameters/buffer_size  # Paramètres accessibles ?
amixer -c $CARD scontrols | grep ASNUX    # Contrôles mixer présents ?
sudo dmesg | grep -i asnux               # Chargement sans erreur ?
ls /dev/snd/controlC$CARD                # Device node existant ?
```

Test de playback : `speaker-test -D hw:$CARD,0 -c 2 -t sine -f 440`

### Module kernel "Invalid module format"

Après une mise à jour du noyau ou si le module a été compilé pour un noyau différent, le chargement échoue avec `insmod: ERROR: could not insert module ... Invalid module format`.

Vérifier le décalage :
```bash
modinfo asnux.ko | grep vermagic   # version pour laquelle le module est compilé
uname -r                           # version du noyau actuel
```

Recompiler pour le noyau actuel :
```bash
cd kernel/
make clean
make
sudo cp asnux.ko /lib/modules/$(uname -r)/kernel/drivers/sound/
sudo depmod -a
sudo modprobe asnux
```

## Licences

- Module noyau : GPL v2
- Daemon & GUI : MIT
