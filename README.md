# Debian-Based NAS Setup: A Complete Guide to Accessing Your Storage Device from Anywhere in the World

Debian can be run on virtually any computer found today. This guide is useful for conversion of old computers to NAS systems.

## Before Getting Started: 

### Hardware Requirements:
A Computer that has the following:
- Dual-core processor or higher
- 4 GB RAM minimum (non-ZFS build)
- 8 GB RAM or more (recommended for ZFS build)
- Storage: User-defined
  - Minimum 50 GB required for the OS and services
- Network connectivity (Ethernet or Wi-Fi)
  
### Network Requirements:
This NAS is designed for both local and remote access.

In BOTH cases, Ethernet is always recommended.

(If it is primarily a "repurpose" project, WiFi Cards also work.)

> **NOTE:** *Visit the Debian Documentation for the list of Supported WiFi Cards before beginning this project.*

#### Local Network (LAN)
- Legacy WiFi cards (100 Mbps rated) are widely supported
  - Real-world throughput may be ~25–40 Mbps
  - Suitable for light NAS workloads

#### Internet (Remote Access via Tailscale)
- Minimum 40 Mbps internet connection
> *Performance when accessing files remotely depends entirely on ISP bandwidth*


## Setup
This Debian NAS Setup has the following functionalities:
- Debian 12
- Web-based management interface
- Dockerized Jellyfin service
- Resilience scripts (watchdogs)
- Security
- Automation and monitoring
- Documentation and configuration management


## Getting Started
  ### Debian Setup
  There is plenty of onscreen instruction availble on how to "boot" and "use" Debian as an OS.
    
  I will be linking one of them here:

  > **NOTE** : *DO NOT CLICK ON GRAPHICAL INSTALL -> Select on Install (not Graphical Install)*

  [Debian 12 Installation]()`https://www.youtube.com/watch?v=Owr-PGxFBQE`
  > *You can use Rufus instead of Balena Etcher* 

### Initial Setup
   The following setup will update your system/server.
   `sudo apt update && sudo apt upgrade`
   
  -> I will be using nmcli instead of systemd
  -> i will also only use iptables directly (hence i wam removing ufw)

  ```bash
  sudo apt install network-manager

  sudo systemctl stop systemd-networkd
  sudo systemctl stop systemd-networkd.socket
  sudo systemctl stop systemd-networkd-wait-online
  sudo systemctl disable systemd-networkd systemd-networkd.socket systemd-networkd-wait-online
  sudo systemctl mask systemd-networkd systemd-networkd.socket systemd-networkd-wait-online

  sudo rm -rf /etc/systemd/network
  sudo rm -rf /run/systemd/network
  sudo rm -rf /lib/systemd/network

  sudo systemctl enable NetworkManager
  sudo systemctl start NetworkManager

  #Optionally you can configure your own ufw settings
  #THIS IS MY FIREWALL SETUP
  #ALLOW ALL OUTPUT TRAFFIC
  #ALL UNRESTRICTED ACCESS THROUGH TAILSCALE VPN
  #DISABLE INPUT ACCESS FROM ANYWHERE ELSE
  sudo systemctl stop ufw
  sudo systemctl disable ufw
  sudo apt purge -y ufw
  sudo apt autoremove -y
  sudo apt install -y iptables iptables-persistent
  # this usually leads to minor(MAJOR) security issues as there is a small window here that leaves your setup completely unguarded to outside traffic, however there really shouldnt be any issue as an individual is unlikely to be targeted (hence minor for small users, major for high profile servers)
  #the reason why i set it up like htis is because i did run into conflicts of ufw and iptables trying to exist at the same time with the rules i wanted
  sudo iptables -F
  sudo iptables -X
  sudo iptables -P INPUT DROP
  sudo iptables -P FORWARD DROP
  sudo iptables -P OUTPUT ACCEPT
  sudo iptables -A INPUT -i lo -j ACCEPT
  sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  sudo netfilter-persistent save
  #THE CHANGES TO BE MADE FOR TAILSCALE WILL BE GIVEN IN PACKAGES TO INSTALL SECTION


  sudo reboot #OPTIONAL, and recommended
  ```
  Configure Network Manager with your wifi/network devices

  My setup includes
  1. Ethernet
  2. Primary Wifi Network
  3. Backup Wifi Network

## Packages to Install:
  1. OpenSSH
  2. Cockpit
  3. Fail2Ban
  4. Cron
  5. SmartMonTools
  6. Logrotate
  7. Tailscale
  8. Docker & Jellyfin
  9. File Browser
  10. zfs
  
Install Script is as follows
```bash
sudo apt install zfsutils-linux -y
sudo modprobe zfs
sudo apt install openssh-server -y
sudo systemctl enable --now ssh
sudo apt install cockpit -y
sudo systemctl enable --now cockpit.socket
sudo apt install fail2ban -y
sudo systemctl enable --now fail2ban
sudo apt install cron -y
sudo systemctl enable --now cron
sudo apt install smartmontools -y
sudo apt install logrotate -y
sudo logrotate -f /etc/logrotate.conf #manual run

curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up #Process Login By making account and signing up

sudo apt install docker.io -y
sudo systemctl enable --now docker
```
For FileBrowser<br>
```bash
curl fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
```

The edited IPTABLE Rules
```bash
sudo iptables -A INPUT -i tailscale0 -j ACCEPT
sudo iptables -A INPUT -i tailscale0 -p tcp --dport 22 -j ACCEPT #allow ssh only through tailscale
sudo netfilter-persistent save
```

## Configs- Main Packages

### ZFS:
ZFS is a filesystem that is good at detecting disk errors and handling
Installation script
```bash
lsblk
# FIND THE DISK NAME FOR IT TO BE INSTALLED ON -> USE NON OS DISK -> Mine is as an example
# MAKE SURE THE FILES ARE BACKED UP
# THIS ACTION WILL WIPE YOUR DISK AND FORMAT IT
# MAKE A BACKUP
# REMINDER, MAKE A BACKUP, THIS ACTION WILL WIPE YOUR DISK

#WARNING REPLACE SDB WITH YOUR HARDDRIVE LETTER
sudo wipefs -a #/dev/sdb #REPLACE sdb with your HardDrive
#i commented #/dev/sdb for safety of the user
sudo zpool create archive /dev/sdb
zpool status #verify
```

### JELLYFIN

```bash
sudo mkdir -p /srv/media
sudo chmod -R 755 /srv/media
sudo docker run -d \
  --name jellyfin \
  -p 8096:8096 \
  -v /opt/jellyfin/config:/config \
  -v /opt/jellyfin/cache:/cache \
  -v /srv/media:/media \
  --restart unless-stopped \
  jellyfin/jellyfin
```

### File Browser

```bash
curl fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
sudo nano /etc/systemd/system/filebrowser.service
```
and paste the following
```text
[Unit]
Description=File Browser
After=network.target

[Service]
ExecStart=/usr/local/bin/filebrowser -r /archive -r /srv/media -a 0.0.0.0 -p 8080
Restart=always
User=root

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl daemon-reload
sudo systemctl enable filebrowser
sudo systemctl restart filebrowser
```


## Individual Scripts - Automation
Cronjobs are what help run script "timely" execution

> i have uploaded the scripts into the folder "Cronjobs"

firstly, i would like to explain the need for following files
1. usb-recovery.sh
2. battery-watchdog.sh
3. zfs-scrub-cron.sh
4. network-watchdog.sh
5. fdupes-scan.sh

### usb-recovery
I directly use all my hardrives using USB connections, hence i needed recovery scripts in case the USB port malfunctions

```bash
#!/bin/bash

LOG_FILE="/var/log/usb-recovery.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

echo "[$TIMESTAMP] Running USB recovery check..." >> "$LOG_FILE"

# Check if ZFS 'archive' is missing
if ! zpool list | grep -q "^archive "; then
    echo "[$TIMESTAMP] Pool 'archive' not found. Attempting USB rescan and re-import..." >> "$LOG_FILE"

    # Rescan USB devices (both SCSI and PCI)
    for host in /sys/class/scsi_host/host*; do
        echo "- - -" | sudo tee "$host/scan" > /dev/null
    done
    echo 1 | sudo tee /sys/bus/pci/rescan > /dev/null

    sleep 5

    # Try importing the ZFS pool
    if sudo zpool import archive; then
        echo "[$TIMESTAMP] Pool 'archive' successfully re-imported." >> "$LOG_FILE"
    else
        echo "[$TIMESTAMP] Failed to import 'archive'." >> "$LOG_FILE"
    fi
else
    echo "[$TIMESTAMP] Pool 'archive' is already active. No action needed." >> "$LOG_FILE"
fi
```
### battery-watchdog.sh
Configure Battery watchdogs for automatic shutdown below a cerrtain percentage, in this case, less than 20

```bash
#!/bin/bash

LOGFILE="/var/log/battery-watchdog.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

BATTERY_PATH="/sys/class/power_supply/BAT0"

#I use telegram bots to give me alerts so use bot tokens
#BOT_TOKEN="INSERT+YOUR+BOT+TOKEN"
#CHAT_ID="INSERT+CHAT+ID"

send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="$message" > /dev/null
}

# Check if battery exists
if [ ! -d "$BATTERY_PATH" ]; then
    echo "[$TIMESTAMP] No battery found. Skipping check." >> "$LOGFILE"
    exit 0
fi

CAPACITY=$(cat $BATTERY_PATH/capacity)
STATUS=$(cat $BATTERY_PATH/status)

if [ "$STATUS" = "Discharging" ] && [ "$CAPACITY" -le 20 ]; then
    echo "[$TIMESTAMP] Battery low: $CAPACITY%. Shutting down!" >> "$LOGFILE"
    send_telegram "🔋 NAS battery critically low: $CAPACITY%. Shutting down!"
    /sbin/shutdown -h now
else
    echo "[$TIMESTAMP] Battery OK: $CAPACITY% ($STATUS)" >> "$LOGFILE"
fi
```
### zfs-scrub-cron.sh
run zfs system check and scrub script and sends telegram message of the zfs scrub
```bash
#!/bin/bash

LOGFILE="/var/log/zpool-scrub.log"
POOL="archive"
#I use telegram bots to give me alerts so use bot tokens
#BOT_TOKEN="INSERT+YOUR+BOT+TOKEN"
#CHAT_ID="INSERT+CHAT+ID"

send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="$message" > /dev/null
}
# Start logging
echo "[ $(date) ] Scrubbing..." >> "$LOGFILE"

/sbin/zpool scrub "$POOL"
sleep 5

# Get zpool status and health
ZPOOL_STATUS=$(/sbin/zpool status "$POOL")
ZPOOL_HEALTH=$(/sbin/zpool list -H -o health "$POOL")

# Log full status to file
echo "$ZPOOL_STATUS" >> "$LOGFILE"

send_telegram "✅ ZFS scrub completed on *$POOL* at $(hostname) — Health: *$ZPOOL_HEALTH*"
```

### network-watchdog.sh
This is perhaps the most important of them all <br>
The server needs to be running at all times hence we need a script to check its status at all times (almost)

This Script:
1. Checks connection by pinging cloudflare
2. if primary is not connected, tries connecting
3. If not -> falls back to the backup
4. If it still fails -> Restart Network Manager (nmcli) -> tests again
5. If it still fails -> toggles nmcli radio -> tests again
6. IF it still fails, reboot
7. maximum allowed reboot times -> 5
  a. IF it crosses 5, system -> shutdown


> I realized later(now) that there is no use setting up telegram bot for network checks as it just wouldnt send any messages if the server was offline XD

>i am too unbothered to do it, as it doesnt take much space anyway, edit it on your own...

```bash
#!/bin/bash

# Set a full cron-safe PATH
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LOGFILE="/var/log/network-watchdog.log"
TIMESTAMP() { date "+%Y-%m-%d %H:%M:%S"; }

STATE_FILE="/var/lib/network-watchdog.state"
MAX_REBOOTS=5

# Ensure state file exists
if [ ! -f "$STATE_FILE" ]; then
    echo 0 > "$STATE_FILE"
fi

REBOOT_COUNT=$(cat "$STATE_FILE")

#I use telegram bots to give me alerts so use bot tokens
#BOT_TOKEN="INSERT+YOUR+BOT+TOKEN"
#CHAT_ID="INSERT+CHAT+ID"

send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="$message" > /dev/null
}


GATEWAY_IP=$(ip route | grep default | awk '{print $3}')
PING_TARGET=1.1.1.1
PING_COUNT=3
PING_TIMEOUT=3

## UNCOMMENT AND MAKE CHANGES

#PRIMARY_SSID="INSERT+PRIMARY+NETWORK+NAME"
#PRIMARY_PSK="INSERT+PRIMARY+NETWORK+PASSWORD"

#FALLBACK_SSID="INSERT+BACKUP+NETWORK+NAME"
#FALLBACK_PSK="INSERT+BACKUP+NETWORK+PASSWORD"

# Use nmcli instead of iwgetid for cron compatibility
CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)

function log() {
    echo "[$(TIMESTAMP)] $1" >> "$LOGFILE"
}

function ping_test() {
    ping -c $PING_COUNT -W $PING_TIMEOUT $PING_TARGET >/dev/null 2>&1
    return $?
}

function connect_wifi() {
    local ssid=$1
    local psk=$2
    log "Attempting to connect to Wi-Fi SSID: $ssid"
    nmcli device wifi connect "$ssid" password "$psk" >/dev/null 2>&1
    sleep 15
    # Refresh CURRENT_SSID after connection attempt
    CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
}

# Step 1: Ping test
if ping_test; then
    log "Network OK. Connected SSID: $CURRENT_SSID"
    echo 0 > "$STATE_FILE"
    exit 0
fi

log "Ping to gateway $GATEWAY_IP failed. Trying to reconnect Wi-Fi..."


# Step 2: Try reconnect on current SSID
connect_wifi "$CURRENT_SSID" "$([ "$CURRENT_SSID" = "$PRIMARY_SSID" ] && echo "$PRIMARY_PSK" || echo "$FALLBACK_PSK")"

CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)

if ping_test; then
    log "Network OK. Connected SSID: $CURRENT_SSID"
    echo 0 > "$STATE_FILE"
    exit 0
fi

log "Reconnect on current SSID failed. Trying failover SSID..."

# Step 3: Failover to other SSID
CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
if [ "$CURRENT_SSID" = "$PRIMARY_SSID" ]; then
    connect_wifi "$FALLBACK_SSID" "$FALLBACK_PSK"
else
    connect_wifi "$PRIMARY_SSID" "$PRIMARY_PSK"
fi

CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)

if ping_test; then
    log "Reconnected successfully to failover SSID."
    send_telegram "⚠️  CONNECTED TO FAILOVER SSID ⚠️ "

    echo 0 > "$STATE_FILE"

    # Optional: Try switching back to primary if we're on fallback
    if [ "$CURRENT_SSID" != "$PRIMARY_SSID" ]; then
        log "Attempting to switch back to primary SSID: $PRIMARY_SSID"
        connect_wifi "$PRIMARY_SSID" "$PRIMARY_PSK"

        if ping_test; then
            log "Successfully switched back to primary SSID."
            send_telegram "✅ Switched back to PRIMARY SSID."
        else
            log "Switch back to primary failed. Staying on fallback."
        fi
    fi

    exit 0
fi

log "All Wi-Fi reconnect attempts failed. Restarting NetworkManager..."

send_telegram "⚠️ Watchdog: Restarting NetworkManager service."

systemctl restart NetworkManager
sleep 30

# Refresh SSID after restart
CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)

if ping_test; then
    log "Network recovered after NetworkManager restart."
    echo 0 > "$STATE_FILE"
    exit 0
fi

log "NetworkManager restart failed. Cycling Wi-Fi radio..."

nmcli radio wifi off
sleep 10
nmcli radio wifi on
sleep 20

CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)

if ping_test; then
    log "Network recovered after Wi-Fi radio reset."
    echo 0 > "$STATE_FILE"
    exit 0
fi

REBOOT_COUNT=$((REBOOT_COUNT + 1))
echo "$REBOOT_COUNT" > "$STATE_FILE"

if [ "$REBOOT_COUNT" -ge "$MAX_REBOOTS" ]; then
    log "Maximum reboot attempts reached ($REBOOT_COUNT). Shutting down permanently."
    send_telegram "🚨 Watchdog: Max reboot attempts reached. Shutting down NAS."
    sleep 10
    /sbin/poweroff
else
    log "Reboot attempt $REBOOT_COUNT of $MAX_REBOOTS."
    send_telegram "⚠️ Watchdog reboot attempt $REBOOT_COUNT of $MAX_REBOOTS."
    sleep 10
    /sbin/reboot
fi
```
### fdupes (optional)
fdupes is a program that looks for duplicates

to install fdupes, do:
```bash
sudo apt update
sudo apt install fdupes
```


```bash
#!/bin/bash

LOGFILE="/var/log/fdupes.log"
SCAN_DIR="/mnt/media"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

#I use telegram bots to give me alerts so use bot tokens
#BOT_TOKEN="INSERT+YOUR+BOT+TOKEN"
#CHAT_ID="INSERT+CHAT+ID"

send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="$message" > /dev/null
}

DUPES=$(fdupes -r "$SCAN_DIR")
COUNT=$(echo "$DUPES" | grep -c '^/' || true)

echo "[$TIMESTAMP] Scan started for $SCAN_DIR" >> "$LOGFILE"

if [ "$COUNT" -gt 0 ]; then
    echo "[$TIMESTAMP] Found $COUNT duplicate file(s):" >> "$LOGFILE"
    echo "$DUPES" >> "$LOGFILE"

    send_telegram "⚠️ fdupes found $COUNT duplicate file(s) in $SCAN_DIR on $(hostname)"
else
    echo "[$TIMESTAMP] No duplicates found." >> "$LOGFILE"
    send_telegram "✅ fdupes scan complete: No duplicates found in $SCAN_DIR on $(hostname)"
fi
```


## FINAL SCRIPT FOR CRONJOBS

Cronjob is the final automation script that actual *runs* automation <br>
-> the usb recovery and battery watchdogs run after 2 minutes of boot time
-> USB recovery runs every 2 hours
-> ZFS Scrub every Sunday on 3 AM
-> Network watchdog runs every hour
-> Battery watchdog runs every 10 minutes
-> fdupes runs every sunday 4 am

Given as follows:<br>

First run<br>
`sudo crontab -e`

```bash
#Paste this in the end of the file
@reboot sleep 120 && /usr/local/bin/usb-recovery.sh >> /var/log/usb-recovery.lo>
@reboot sleep 120 && /usr/local/bin/battery-watchdog.sh >> /var/log/cron-battery-watchd>
0 */2 * * * /usr/local/bin/usb-recovery.sh >> /var/log/usb-recovery.log 2>&1
0 3 * * 0 /usr/local/bin/zfs-scrub-cron.sh >> /var/log/zpool-scrub.log 2>&1
0 * * * * /usr/local/bin/network-watchdog.sh >> /var/log/cron-network-watchd>
*/10 * * * * /usr/local/bin/battery-watchdog.sh >> /var/log/cron-battery-watchd>
0 4 * * 0 /usr/local/bin/fdupes-scan.sh >> /var/log/cron-fdupes.log 2>&1
```
## HOW TO ACCESS YOUR SERVER:

1. LOGIN in to your tailscale account<br>
2. Under Admin Console, Find Your Listed NAS Server Name<br>
3. Extract the IP Address of your Server Under Addresses
4. Use the following addresses on your server:
FOR COCKPIT<br>
`http://pasteipaddress:9090` <br>
FOR JELLYFIN<br>
`http://pasteipaddress:8096`<br>
FOR FILE BROWSER<br>
`http://pasteipaddress:8080`<br>
Initial Login for File browser will be<br>
user:admin<br>
password:admin<br>
you will be required to change it, or just change it on your own

