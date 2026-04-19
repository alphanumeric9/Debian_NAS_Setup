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
