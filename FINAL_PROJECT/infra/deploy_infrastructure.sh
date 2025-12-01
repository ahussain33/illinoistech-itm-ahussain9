#!/bin/bash
set -e
echo "=== Deploying Resume Parser Application ==="
########################################
# 1. Load config
########################################
KEY_PATH="my-key-pair-2.pem"
USER="ubuntu"
PROJECT_ROOT="$HOME/ITMO_444_Fall2025/FINAL_PROJECT"
API_DIR="$PROJECT_ROOT/api"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
INFRA_DIR="$PROJECT_ROOT/infra"
EC2_IP=$(cat "$INFRA_DIR/public_ip.txt")
echo "[INFO] Using EC2 IP: $EC2_IP"
########################################
# 2. Create new S3 bucket
########################################
BUCKET_NAME="abiha-resume-parser-$(date +%Y%m%d-%H%M)"
echo "$BUCKET_NAME" > "$INFRA_DIR/bucket_name.txt"
echo ">>> Creating bucket: $BUCKET_NAME ..."
aws s3 mb "s3://$BUCKET_NAME"
########################################
# 3. Upload API + frontend + bucket file
########################################
echo ">>> Uploading project files to EC2 ..."
rsync -avz -e "ssh -i $INFRA_DIR/$KEY_PATH" \
    "$API_DIR" "$FRONTEND_DIR" "$INFRA_DIR/bucket_name.txt" \
    $USER@$EC2_IP:/home/ubuntu/FINAL_PROJECT/
########################################
# 4. Configure EC2
########################################
echo ">>> Running EC2 setup ..."
ssh -i "$INFRA_DIR/$KEY_PATH" ubuntu@"$EC2_IP" "bash -s" << 'EOF'
set -e
echo "--- EC2: preparing directories ---"
mkdir -p ~/FINAL_PROJECT/api
#############################################
# Write FINAL app.py directly onto EC2
#############################################
cat > ~/FINAL_PROJECT/api/app.py << 'APPFILE'
import os
from flask import Flask, request, jsonify, send_from_directory
import boto3
from resume_parser import parse_resume
app = Flask(__name__)
# FIXED: proper frontend directory path
FRONTEND_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "frontend")
)
RESUME_BUCKET_NAME = os.environ.get("RESUME_BUCKET_NAME")
if not RESUME_BUCKET_NAME:
    raise RuntimeError("RESUME_BUCKET_NAME environment variable is not set")
s3_client = boto3.client("s3")
@app.route("/")
def serve_index():
    return send_from_directory(FRONTEND_DIR, "index.html")
@app.route("/<path:path>")
def serve_static(path):
    return send_from_directory(FRONTEND_DIR, path)
@app.route("/upload", methods=["POST"])
def upload():
    file = request.files.get("file")
    if not file:
        return jsonify({"error": "No file uploaded"}), 400
    filename = file.filename
    filepath = f"/tmp/{filename}"
    file.save(filepath)
    s3_client.upload_file(filepath, RESUME_BUCKET_NAME, filename)
    parsed = parse_resume(filepath)
    return jsonify(parsed)
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
APPFILE
#############################################
# Load bucket name from file
#############################################
echo "--- EC2: reading bucket name ---"
export RESUME_BUCKET_NAME=$(cat ~/FINAL_PROJECT/bucket_name.txt)
echo "Bucket: $RESUME_BUCKET_NAME"
#############################################
# Install dependencies
#############################################
echo "--- EC2: installing Python + dependencies ---"
sudo apt update -y
sudo apt install -y python3-pip gunicorn
# FIXED pip behavior for Ubuntu 22.04+ (PEP 668)
sudo -H pip3 install -r ~/FINAL_PROJECT/api/requirements.txt
#############################################
# Stop nginx and old gunicorn
#############################################
echo "--- EC2: stopping nginx/gunicorn ---"
sudo systemctl stop nginx || true
sudo systemctl disable nginx || true
sudo pkill -f nginx || true
#############################################
# Export bucket name permanently
#############################################
echo "RESUME_BUCKET_NAME=$RESUME_BUCKET_NAME" | sudo tee /etc/environment
#############################################
# Start Gunicorn
#############################################
echo "--- EC2: starting gunicorn ---"
cd ~/FINAL_PROJECT/api
sudo -E bash -c "nohup gunicorn --bind 0.0.0.0:80 app:app > /home/ubuntu/gunicorn.log 2>&1 &"
EOF
########################################
# 5. Done
########################################
echo "[SUCCESS] Deployment complete!"
echo "Open browser: http://$EC2_IP"
