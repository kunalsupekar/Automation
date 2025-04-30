#!/bin/bash
set -e

SERVICE_NAME="deploy-app"
SCRIPT_NAME="deploy_app.sh"
SERVICE_FILE="deploy-app.service"

SCRIPT_DEST="/usr/local/bin/$SCRIPT_NAME"
SERVICE_DEST="/etc/systemd/system/$SERVICE_NAME.service"

echo "📦 Installing $SERVICE_NAME..."

# Copy and set permissions
sudo cp "$SCRIPT_NAME" "$SCRIPT_DEST"
sudo chmod 755 "$SCRIPT_DEST"

sudo cp "$SERVICE_FILE" "$SERVICE_DEST"
sudo chmod 644 "$SERVICE_DEST"

# Reload systemd and enable service
sudo systemctl daemon-reexec
sudo systemctl enable "$SERVICE_NAME"

echo "✅ $SERVICE_NAME installed."
echo "👉 Run it manually with: sudo systemctl start $SERVICE_NAME"
