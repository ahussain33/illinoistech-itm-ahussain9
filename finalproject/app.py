import os
import json
import boto3
from flask import Flask, request, jsonify
from resume_parser import parse_resume   # whatever your function is

app = Flask(__name__)

S3_BUCKET = os.environ.get("RESUME_BUCKET_NAME")  # we already export this in deploy_infrastructure.sh
s3 = boto3.client("s3")

@app.route("/upload", methods=["POST"])
def upload():
    if "file" not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files["file"]

    # 1. Parse the resume
    parsed = parse_resume(file)  # you implement this in resume_parser.py

    # 2. Store result in S3 as JSON
    key_name = f"parsed-resumes/{file.filename}.json"
    s3.put_object(
        Bucket=S3_BUCKET,
        Key=key_name,
        Body=json.dumps(parsed),
        ContentType="application/json"
    )

    # 3. Return something to the frontend
    return jsonify({
        "message": "Resume parsed and stored in S3",
        "s3_key": key_name,
        "data": parsed
    })
