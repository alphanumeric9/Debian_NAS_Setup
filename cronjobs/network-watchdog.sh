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
