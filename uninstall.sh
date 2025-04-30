#!/bin/bash
set -e

SERVICE_NAME="deploy-app"
SCRIPT_DEST="/usr/local/bin/deploy_app.sh"
SERVICE_DEST="/etc/systemd/system/$SERVICE_NAME.service"

echo "🧹 Uninstalling $SERVICE_NAME..."

sudo systemctl stop "$SERVICE_NAME" || true
sudo systemctl disable "$SERVICE_NAME" || true

sudo rm -f "$SCRIPT_DEST"
sudo rm -f "$SERVICE_DEST"

sudo systemctl daemon-reexec

echo "❌ $SERVICE_NAME removed."
