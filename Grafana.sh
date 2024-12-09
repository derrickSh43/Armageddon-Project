#!/bin/bash
# Update system packages
sudo dnf upgrade -y

# Add Grafana repository
sudo rpm --import https://rpm.grafana.com/gpg.key
cat <<EOF | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

# Install and start Grafana
sudo dnf install -y grafana
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

# Install and configure Loki
sudo wget https://github.com/grafana/loki/releases/download/v2.8.2/loki-linux-amd64.zip
sudo dnf install -y unzip
unzip loki-linux-amd64.zip
sudo mv loki-linux-amd64 /usr/local/bin/loki
sudo chmod a+x /usr/local/bin/loki

# Create Loki user and directories
sudo useradd --system loki
sudo mkdir /etc/loki
sudo wget -O /etc/loki/loki-config.yaml https://raw.githubusercontent.com/grafana/loki/v2.8.2/cmd/loki/loki-local-config.yaml
sudo chown -R loki:loki /etc/loki

# Create Loki systemd service
cat <<EOF | sudo tee /etc/systemd/system/loki.service
[Unit]
Description=Loki Log Aggregation System
After=network.target

[Service]
User=loki
ExecStart=/usr/local/bin/loki -config.file /etc/loki/loki-config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, start Loki, and enable it at boot
sudo systemctl daemon-reload
sudo systemctl start loki
sudo systemctl enable loki
