#!/bin/bash
# Optional: attach a USB/IP device (e.g. from usbipd-win) from inside the container.
# Runs only when USBIP_SERVER and USBIP_BUSID are set.
[ -z "$USBIP_SERVER" ] || [ -z "$USBIP_BUSID" ] && exit 0

if [ ! -d /sys/devices/platform/vhci_hcd.0 ]; then
    echo "usbip: vhci-hcd not loaded on the Docker host (run: sudo modprobe vhci-hcd). Skipping attach."
    exit 0
fi

(
    for i in $(seq 1 "${USBIP_RETRIES:-10}"); do
        if usbip attach -r "$USBIP_SERVER" -b "$USBIP_BUSID"; then
            echo "usbip: attached $USBIP_BUSID from $USBIP_SERVER"
            exit 0
        fi
        echo "usbip: attach attempt $i failed, retrying in 5s"
        sleep 5
    done
    echo "usbip: giving up attaching $USBIP_BUSID from $USBIP_SERVER"
) &
exit 0
