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
