#!/bin/bash
set -euo pipefail
set -x

# This script is designed to be run on an Amazon Linux instance.
# It installs necessary packages, configures Tomcat and Nginx, mounts an NFS share,
# and deploys WAR files from the NFS share to Tomcat.
# It also replaces configuration files for Nginx and Tomcat from the NFS share.
# Ensure the script is run as root
echo "Starting deployment on Amazon Linux..."

# Configurable variables
TOMCAT_VERSION="8.5.96"
TOMCAT_DIR="/var/lib/tomcat"
TOMCAT_USER="ec2-user"
JAVA_REQUIRED_VERSION="1.8"
NFS_SERVER="${NFS_SERVER:-172.31.87.110}"

# Log to file
exec > >(tee -a /var/log/deployment.log) 2>&1

# Update packages
sudo dnf update -y

# Install NFS utilities
if ! rpm -q nfs-utils >/dev/null 2>&1; then
    echo "🔧 Installing nfs-utils..."
    sudo dnf install -y nfs-utils
fi

# Install Nginx
if ! rpm -q nginx >/dev/null 2>&1; then
    echo "🔧 Installing nginx..."
    sudo dnf install -y nginx
    sudo systemctl enable nginx
fi

# Install Java 8
JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' || echo "")
if [[ "$JAVA_VERSION" != "$JAVA_REQUIRED_VERSION"* ]]; then
    echo "🔧 Installing Java 8 (Amazon Corretto)..."
    sudo dnf install -y java-1.8.0-amazon-corretto
fi

# Install Tomcat
if [[ ! -f "$TOMCAT_DIR/bin/startup.sh" ]]; then
    echo "⬇ Downloading Tomcat $TOMCAT_VERSION..."
    curl -L -O "https://archive.apache.org/dist/tomcat/tomcat-8/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" || { echo "Failed to download Tomcat"; exit 1; }
    sudo mkdir -p "$TOMCAT_DIR"
    sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C "$TOMCAT_DIR" --strip-components=1
    sudo bash -c "chmod +x $TOMCAT_DIR/bin/*.sh"
    sudo chown -R $TOMCAT_USER:$TOMCAT_USER "$TOMCAT_DIR"
    rm -f apache-tomcat-${TOMCAT_VERSION}.tar.gz
fi

# Create Tomcat systemd service
sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat 8.5
After=network.target

[Service]
Type=forking
ExecStart=$TOMCAT_DIR/bin/startup.sh
ExecStop=$TOMCAT_DIR/bin/shutdown.sh
User=$TOMCAT_USER
Group=$TOMCAT_USER
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl start tomcat

# Mount NFS
sudo mkdir -p /data
if ! mountpoint -q /data; then
    sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "$NFS_SERVER:/" /data || { echo "Failed to mount NFS"; exit 1; }
fi

# Copy WAR files
if ls /data/beanstalk-restore/wars/*.war >/dev/null 2>&1; then
    sudo cp /data/beanstalk-restore/wars/*.war /var/lib/tomcat/webapps/
else
    echo "Warning: No WAR files found"
fi

# Replace config files
[[ -f /data/beanstalk-restore/config/nginx.conf ]] || { echo "Error: nginx.conf missing"; exit 1; }
[[ -f /data/beanstalk-restore/config/server.xml ]] || { echo "Error: server.xml missing"; exit 1; }
sudo cp /data/beanstalk-restore/config/nginx.conf /etc/nginx/
sudo cp /data/beanstalk-restore/config/server.xml /var/lib/tomcat/conf/

# Restart services
sudo systemctl restart nginx || { echo "Failed to restart nginx"; exit 1; }
sudo systemctl restart tomcat || { echo "Failed to restart tomcat"; exit 1; }

echo "Deployment completed successfully!"