#!/bin/bash
set -euo pipefail

# Variables
SERVICE_NAME="deploy-app"
SCRIPT_NAME="deploy_app.sh"
SERVICE_FILE="deploy-app.service"
SCRIPT_SRC="./$SCRIPT_NAME"
SERVICE_SRC="./$SERVICE_FILE"
SCRIPT_DEST="/usr/local/bin/$SCRIPT_NAME"
SERVICE_DEST="/etc/systemd/system/$SERVICE_NAME.service"
LOG_FILE="/var/log/install-deploy-app.log"

# Ensure script is run with sudo if not root
if [[ $EUID -ne 0 ]]; then
    echo "This script requires root privileges. Running with sudo..."
    exec sudo "$0" "$@"
fi

echo "Installing $SERVICE_NAME..." | tee -a "$LOG_FILE"

# Validate source files
for file in "$SCRIPT_SRC" "$SERVICE_SRC"; do
    if [[ ! -f "$file" ]]; then
        echo "Error: $file not found in current directory" | tee -a "$LOG_FILE"
        exit 1
    fi
done

# Check for existing files
for dest in "$SCRIPT_DEST" "$SERVICE_DEST"; do
    if [[ -f "$dest" ]]; then
        echo "Warning: $dest already exists. Backing up..." | tee -a "$LOG_FILE"
        cp "$dest" "${dest}.bak-$(date +%F_%H-%M-%S)" || {
            echo "Error: Failed to back up $dest" | tee -a "$LOG_FILE"
            exit 1
        }
    fi
done

# Copy and set permissions
echo "Copying $SCRIPT_NAME to $SCRIPT_DEST..." | tee -a "$LOG_FILE"
cp "$SCRIPT_SRC" "$SCRIPT_DEST" || {
    echo "Error: Failed to copy $SCRIPT_SRC to $SCRIPT_DEST" | tee -a "$LOG_FILE"
    exit 1
}
chmod 755 "$SCRIPT_DEST" || {
    echo "Error: Failed to set permissions on $SCRIPT_DEST" | tee -a "$LOG_FILE"
    exit 1
}

echo "Copying $SERVICE_FILE to $SERVICE_DEST..." | tee -a "$LOG_FILE"
cp "$SERVICE_SRC" "$SERVICE_DEST" || {
    echo "Error: Failed to copy $SERVICE_SRC to $SERVICE_DEST" | tee -a "$LOG_FILE"
    exit 1
}
chmod 644 "$SERVICE_DEST" || {
    echo "Error: Failed to set permissions on $SERVICE_DEST" | tee -a "$LOG_FILE"
    exit 1
}

# Reload systemd and enable service
echo "Reloading systemd daemon..." | tee -a "$LOG_FILE"
systemctl daemon-reload || {
    echo "Error: Failed to reload systemd daemon" | tee -a "$LOG_FILE"
    exit 1
}

echo "Enabling $SERVICE_NAME..." | tee -a "$LOG_FILE"
systemctl enable "$SERVICE_NAME" || {
    echo "Error: Failed to enable $SERVICE_NAME" | tee -a "$LOG_FILE"
    exit 1
}

echo "$SERVICE_NAME installed successfully." | tee -a "$LOG_FILE"
echo "Run it manually with: systemctl start $SERVICE_NAME" | tee -a "$LOG_FILE"
echo "Logs are available in $LOG_FILE"