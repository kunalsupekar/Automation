#!/bin/bash
set -e

sudo mkdir -p /data

# Mount NFS volume
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 172.31.87.110:/ /data

# Copy .war files to Tomcat webapps directory
sudo cp /data/beanstalk-restore/wars/*.war /opt/tomcat/webapps/

# Remove existing Nginx and Tomcat config files
sudo rm -rf /etc/nginx/nginx.conf
sudo rm -rf /opt/tomcat/conf/server.xml

# Copy new config files
sudo cp /data/beanstalk-restore/config/nginx.conf /etc/nginx/
sudo cp /data/beanstalk-restore/config/server.xml /opt/tomcat/conf/

# Restart services
sudo systemctl restart nginx
sudo systemctl restart tomcat

echo "✅ Deployment completed successfully"
