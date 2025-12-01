#!/bin/bash
set -e

IP=$(cat instance_ip.txt)

ssh -i my-key-pair-2.pem ubuntu@$IP << 'INNEREOF'

cat > ~/FINAL_PROJECT/api/app.py << 'APPFILE'
import os
from flask import Flask, request, jsonify, send_from_directory
import boto3
from resume_parser import parse_resume

app = Flask(__name__)

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
    try:
        if "file" not in request.files:
            return jsonify({"status": "error", "message": "No file part"}), 400

        file = request.files["file"]
        filename = file.filename

        if filename == "":
            return jsonify({"status": "error", "message": "No selected file"}), 400

        filepath = os.path.join("/tmp", filename)
        file.save(filepath)

        s3_client.upload_file(filepath, RESUME_BUCKET_NAME, filename)

        # Parse resume
        parsed_data = parse_resume(filepath)

        return jsonify({
            "status": "success",
            "s3_key": filename,
            "parsed_text": parsed_data.get("raw_text", ""),
            "parsed": parsed_data
        }), 200

    except Exception as e:
        print("UPLOAD ERROR:", str(e))
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
APPFILE

sudo pkill -f gunicorn || true

sudo touch /home/ubuntu/gunicorn.log
sudo chown ubuntu:ubuntu /home/ubuntu/gunicorn.log

cd ~/FINAL_PROJECT/api

sudo -E nohup gunicorn --bind 0.0.0.0:80 app:app \
    > /home/ubuntu/gunicorn.log 2>&1 &

INNEREOF
