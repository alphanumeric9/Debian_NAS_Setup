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
