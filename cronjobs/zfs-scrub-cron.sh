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
