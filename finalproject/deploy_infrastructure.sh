#!/bin/bash
set -e

source config.txt
source cloudwatch_utils.sh

log_to_cw "Starting application deployment..."

# ------------------------
# Get instance IP
# ------------------------
if [[ -f instance_ip.txt ]]; then
  PUBLIC_IP=$(cat instance_ip.txt)
else
  if [[ ! -f instance_id.txt ]]; then
    echo "instance_id.txt not found. Run create_infrastructure.sh first."
    exit 1
  fi

  INSTANCE_ID=$(cat instance_id.txt)
  PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

  echo "$PUBLIC_IP" > instance_ip.txt
fi

if [[ -z "$PUBLIC_IP" || "$PUBLIC_IP" == "None" ]]; then
  echo "Could not determine public IP for instance. Check that it has an associated public IP."
  exit 1
fi

log_to_cw "Deploying app to EC2 instance at $PUBLIC_IP"

# ------------------------
# SSH + deploy steps
# ------------------------
ssh -o "StrictHostKeyChecking=no" -i "$KEY_FILE" ubuntu@"$PUBLIC_IP" << 'REMOTE_EOF'
set -e

# Update packages and install dependencies
sudo apt update -y
sudo apt install -y python3-pip git

# Make bucket name available to the app (optional, for S3 usage later)
echo "export RESUME_BUCKET_NAME='"$RESUME_BUCKET_NAME"'" | sudo tee /etc/profile.d/resume_app.sh >/dev/null
export RESUME_BUCKET_NAME='"$RESUME_BUCKET_NAME"'

cd /home/ubuntu

# Clone repo if not already present
if [[ ! -d ITMO_444_Fall2025 ]]; then
  git clone https://github.com/ahussain33/ITMO_444_Fall2025.git
fi

cd ITMO_444_Fall2025/FINAL_PROJECT/api

# Install Python dependencies
pip3 install -r requirements.txt gunicorn

# Kill any existing gunicorn processes (idempotent)
pkill -f "gunicorn .*app:app" || true

# Start Gunicorn on port 80
sudo nohup gunicorn --bind 0.0.0.0:80 app:app >/var/log/gunicorn.log 2>&1 &
REMOTE_EOF

log_to_cw "Deployment complete. App should be available at http://$PUBLIC_IP"
send_cw_metric 1

echo "Application deployed. Open: http://$PUBLIC_IP"

