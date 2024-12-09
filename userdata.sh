#!/bin/bash
# Update the system packages
sudo dnf upgrade -y

# Install necessary tools
sudo dnf install -y wget unzip httpd

# ------------------------------
# Configure Promtail for Loki
# ------------------------------
# Download Promtail
wget https://github.com/grafana/loki/releases/download/v2.8.2/promtail-linux-amd64.zip
unzip promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo chmod a+x /usr/local/bin/promtail

# Create Promtail configuration directory
sudo mkdir /etc/promtail

# NOTE: Replace "<LOKI_SERVER_IP>" with the private IP address or hostname of your Loki server
sudo tee /etc/promtail/promtail-config.yaml <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/log/positions.yaml

clients:
  - url: http://<LOKI_SERVER_IP>:3100/loki/api/v1/push

scrape_configs:
  - job_name: webserver_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: webserver
          instance: $(hostname)
          __path__: /var/log/httpd/access_log
  - job_name: system_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: system
          instance: $(hostname)
          __path__: /var/log/*.log
EOF

# Create Promtail systemd service
sudo tee /etc/systemd/system/promtail.service <<EOF
[Unit]
Description=Promtail Log Collector
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/promtail -config.file /etc/promtail/promtail-config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Promtail
sudo systemctl daemon-reload
sudo systemctl enable promtail
sudo systemctl start promtail

# ------------------------------
# Configure Web Server (Apache)
# ------------------------------
# Start and enable the web server
systemctl start httpd
systemctl enable httpd

# Get the IMDSv2 token
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Background the curl requests
curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4 &> /tmp/local_ipv4 &
curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone &> /tmp/az &
curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/ &> /tmp/macid &
wait

macid=$(cat /tmp/macid)
local_ipv4=$(cat /tmp/local_ipv4)
az=$(cat /tmp/az)
vpc=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/${macid}/vpc-id)

echo "
<!doctype html>
<html lang=\"en\" class=\"h-100\">
<head>
<title>Details for EC2 instance</title>
</head>
<body>
<div>
<h1>AWS Instance Details</h1>
<h1>Samurai Katana</h1>

<br>
# insert an image or GIF
<img src="https://www.w3schools.com/images/w3schools_green.jpg" alt="W3Schools.com">
<br>

<p><b>Instance Name:</b> $(hostname -f) </p>
<p><b>Instance Private Ip Address: </b> ${local_ipv4}</p>
<p><b>Availability Zone: </b> ${az}</p>
<p><b>Virtual Private Cloud (VPC):</b> ${vpc}</p>
</div>
</body>
</html>
" > /var/www/html/index.html

# Clean up the temp files
rm -f /tmp/local_ipv4 /tmp/az /tmp/macid
EOF

# Restart Apache to apply logging changes
sudo systemctl restart httpd

# ------------------------------
# Verify Setup
# ------------------------------
# Print completion message
echo "Setup complete. Web server running, and Promtail is configured to send logs to Loki."
