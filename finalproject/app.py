import os
import json
import boto3
from botocore.exceptions import ClientError
from flask import Flask, request, jsonify, send_from_directory
from werkzeug.utils import secure_filename
from resume_parser import parse_resume

# Serve static files (frontend) from ../frontend
app = Flask(__name__, static_folder="../frontend", static_url_path="/")

# Environment configuration
S3_BUCKET = os.environ.get("RESUME_BUCKET_NAME")
if not S3_BUCKET:
    raise RuntimeError("RESUME_BUCKET_NAME environment variable is not set")

s3_client = boto3.client("s3")


@app.route("/health", methods=["GET"])
def health():
    """Simple health-check endpoint."""
    return jsonify({"status": "ok"}), 200


@app.route("/upload", methods=["POST"])
def upload_resume():
    # Validate file presence
    if "file" not in request.files:
        return jsonify({"status": "error", "message": "No file part"}), 400

    file = request.files["file"]
    if file.filename == "":
        return jsonify({"status": "error", "message": "No selected file"}), 400

    # Save to /tmp
    filename = secure_filename(file.filename)
    file_path = f"/tmp/{filename}"
    file.save(file_path)

    parsed_data = None
    try:
        parsed_data = parse_resume(file_path)
    except Exception as e:
        app.logger.exception("Error parsing resume")
        return (
            jsonify(
                {
                    "status": "error",
                    "message": f"Failed to parse resume: {str(e)}",
                }
            ),
            400,
        )
    finally:
        # Clean up temp file
        if os.path.exists(file_path):
            try:
                os.remove(file_path)
            except OSError:
                # Not fatal, but log it
                app.logger.warning("Failed to remove temp file %s", file_path)

    # Ensure parsed_data is JSON-serializable
    try:
        body = json.dumps(parsed_data, ensure_ascii=False)
    except TypeError as e:
        app.logger.exception("Parsed data is not JSON serializable")
        return (
            jsonify(
                {
                    "status": "error",
                    "message": f"Internal error serializing parsed data: {str(e)}",
                }
            ),
            500,
        )

    s3_key = f"resumes/{os.path.splitext(filename)[0]}.json"
    try:
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=body,
            ContentType="application/json",
        )
    except ClientError as e:
        app.logger.exception("Error uploading parsed resume to S3")
        return (
            jsonify(
                {
                    "status": "error",
                    "message": f"Failed to upload to S3: {str(e)}",
                }
            ),
            500,
        )

    return jsonify({"status": "success", "s3_key": s3_key}), 200

@app.route("/")
def index():
    return send_from_directory(app.static_folder, "index.html")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
