#!/bin/bash
set -euo pipefail

# Variables
SERVICE_NAME="deploy-app"
SCRIPT_NAME="deploy_app.sh"
SERVICE_FILE="deploy-app.service"
SCRIPT_DEST="/usr/local/bin/$SCRIPT_NAME"
SERVICE_DEST="/etc/systemd/system/$SERVICE_NAME.service"
TOMCAT_SERVICE="/etc/systemd/system/tomcat.service"
TOMCAT_DIR="/var/lib/tomcat"
NFS_MOUNT="/data"
LOG_FILE="/var/log/uninstall-deploy-app.log"
INSTALL_LOG="/var/log/install-deploy-app.log"
DEPLOY_LOG="/var/log/deployment.log"

# Ensure script is run with sudo if not root
if [[ $EUID -ne 0 ]]; then
    echo "This script requires root privileges. Running with sudo..." | tee -a "$LOG_FILE"
    exec sudo "$0" "$@"
fi

echo "Uninstalling $SERVICE_NAME..." | tee -a "$LOG_FILE"

# Stop and disable deploy-app service
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Stopping $SERVICE_NAME service..." | tee -a "$LOG_FILE"
    systemctl stop "$SERVICE_NAME" || {
        echo "Warning: Failed to stop $SERVICE_NAME" | tee -a "$LOG_FILE"
    }
fi

if systemctl is-enabled --quiet "$SERVICE_NAME"; then
    echo "Disabling $SERVICE_NAME service..." | tee -a "$LOG_FILE"
    systemctl disable "$SERVICE_NAME" || {
        echo "Warning: Failed to disable $SERVICE_NAME" | tee -a "$LOG_FILE"
    }
fi

# Remove deploy-app service file
if [[ -f "$SERVICE_DEST" ]]; then
    echo "Removing $SERVICE_DEST..." | tee -a "$LOG_FILE"
    rm -f "$SERVICE_DEST" || {
        echo "Error: Failed to remove $SERVICE_DEST" | tee -a "$LOG_FILE"
        exit 1
    }
fi

# Stop and disable tomcat service
if systemctl is-active --quiet tomcat; then
    echo "Stopping tomcat service..." | tee -a "$LOG_FILE"
    systemctl stop tomcat || {
        echo "Warning: Failed to stop tomcat" | tee -a "$LOG_FILE"
    }
fi

if systemctl is-enabled --quiet tomcat; then
    echo "Disabling tomcat service..." | tee -a "$LOG_FILE"
    systemctl disable tomcat || {
        echo "Warning: Failed to disable tomcat" | tee -a "$LOG_FILE"
    }
fi

# Remove tomcat service file
if [[ -f "$TOMCAT_SERVICE" ]]; then
    echo "Removing $TOMCAT_SERVICE..." | tee -a "$LOG_FILE"
    rm -f "$TOMCAT_SERVICE" || {
        echo "Error: Failed to remove $TOMCAT_SERVICE" | tee -a "$LOG_FILE"
        exit 1
    }
fi

# Reload systemd
echo "Reloading systemd daemon..." | tee -a "$LOG_FILE"
systemctl daemon-reload || {
    echo "Error: Failed to reload systemd daemon" | tee -a "$LOG_FILE"
    exit 1
}

# Remove deployment script
if [[ -f "$SCRIPT_DEST" ]]; then
    echo "Removing $SCRIPT_DEST..." | tee -a "$LOG_FILE"
    rm -f "$SCRIPT_DEST" || {
        echo "Error: Failed to remove $SCRIPT_DEST" | tee -a "$LOG_FILE"
        exit 1
    }
fi

# Remove Tomcat installation
if [[ -d "$TOMCAT_DIR" ]]; then
    echo "Removing Tomcat directory $TOMCAT_DIR..." | tee -a "$LOG_FILE"
    rm -rf "$TOMCAT_DIR" || {
        echo "Error: Failed to remove $TOMCAT_DIR" | tee -a "$LOG_FILE"
        exit 1
    }
fi

# Unmount and remove NFS mount point
if mountpoint -q "$NFS_MOUNT"; then
    echo "Unmounting $NFS_MOUNT..." | tee -a "$LOG_FILE"
    umount "$NFS_MOUNT" || {
        echo "Warning: Failed to unmount $NFS_MOUNT" | tee -a "$LOG_FILE"
    }
fi

if [[ -d "$NFS_MOUNT" ]]; then
    echo "Removing NFS mount point $NFS_MOUNT..." | tee -a "$LOG_FILE"
    rmdir "$NFS_MOUNT" || {
        echo "Warning: Failed to remove $NFS_MOUNT (directory not empty?)" | tee -a "$LOG_FILE"
    }
fi

# Remove log files
for log in "$INSTALL_LOG" "$DEPLOY_LOG"; do
    if [[ -f "$log" ]]; then
        echo "Removing $log..." | tee -a "$LOG_FILE"
        rm -f "$log" || {
            echo "Error: Failed to remove $log" | tee -a "$LOG_FILE"
            exit 1
        }
    fi
done

# Remove backup files
echo "Removing backup files..." | tee -a "$LOG_FILE"
find /usr/local/bin /etc/systemd/system -type f -name "${SCRIPT_NAME}.bak-*" -exec rm -f {} \; || {
    echo "Warning: Failed to remove some backup files" | tee -a "$LOG_FILE"
}
find /etc/systemd/system -type f -name "${SERVICE_FILE}.bak-*" -exec rm -f {} \; || {
    echo "Warning: Failed to remove some backup files" | tee -a "$LOG_FILE"
}

echo "$SERVICE_NAME and related components uninstalled successfully." | tee -a "$LOG_FILE"
echo "Logs are available in $LOG_FILE" | tee -a "$LOG_FILE"