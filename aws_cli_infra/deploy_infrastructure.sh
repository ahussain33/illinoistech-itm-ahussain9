#!/bin/bash

source config.txt
source cloudwatch_utils.sh
INSTANCE_IP=$(cat instance_ip.txt)
log_to_cw "Deploying NGINX on $INSTANCE_IP"
ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ubuntu@"$INSTANCE_IP" <<'EOF'
sudo apt update -y
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
EOF
log_to_cw "NGINX deployed and running on $INSTANCE_IP"
send_cw_metric 1

