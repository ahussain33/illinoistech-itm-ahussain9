#!/bin/bash
set -e

# Load config + CloudWatch helper
source config.txt
source cloudwatch_utils.sh

log_to_cw "Starting application deployment..."

# ------------------------
# 1. Get instance public IP
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
  echo "Could not determine public IP for instance. Check that it has a public IP."
  exit 1
fi

echo "Deploying app to EC2 instance at $PUBLIC_IP..."
log_to_cw "Deploying app to EC2 instance at $PUBLIC_IP"

# ------------------------
# 2. Wait for SSH to be ready
# ------------------------
echo "Waiting for EC2 SSH to be ready..."
while ! ssh -o "StrictHostKeyChecking=no" -i "$KEY_FILE" ubuntu@"$PUBLIC_IP" "echo ssh-ready" >/dev/null 2>&1; do
  echo "  still waiting..."
  sleep 10
done
echo "SSH is ready."

# ------------------------
# 3. Run all deployment commands ON THE EC2 INSTANCE
# ------------------------
ssh -o "StrictHostKeyChecking=no" -i "$KEY_FILE" ubuntu@"$PUBLIC_IP" << EOF_REMOTE
set -e

echo "=== On EC2: updating packages and installing deps ==="
sudo apt update -y
sudo apt install -y python3-pip git

cd /home/ubuntu

# Set bucket name for the app (optional but nice)
echo "export RESUME_BUCKET_NAME=$RESUME_BUCKET_NAME" | sudo tee /etc/profile.d/resume_app.sh >/dev/null
export RESUME_BUCKET_NAME=$RESUME_BUCKET_NAME

echo "=== On EC2: cloning or updating repo ==="
if [[ -d ITMO_444_Fall2025 ]]; then
  cd ITMO_444_Fall2025
  git pull || true
else
  git clone https://github.com/ahussain33/ITMO_444_Fall2025.git
  cd ITMO_444_Fall2025
fi

cd FINAL_PROJECT/api

echo "=== On EC2: installing Python dependencies ==="
pip3 install -r requirements.txt gunicorn

echo "=== On EC2: stopping any old gunicorn processes (if any) ==="
sudo pkill -f "gunicorn .*app:app" || true

echo "=== On EC2: starting gunicorn on port 80 ==="
sudo nohup gunicorn --bind 0.0.0.0:80 app:app >/var/log/gunicorn.log 2>&1 &

echo "=== On EC2: deployment steps finished ==="
EOF_REMOTE

log_to_cw "Deployment complete to $PUBLIC_IP"
echo "Application deployed. Open: http://$PUBLIC_IP"

