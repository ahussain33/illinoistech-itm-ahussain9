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
    try:
        if "file" not in request.files:
            return jsonify({"status": "error", "message": "No file part"}), 400

        file = request.files["file"]
        filename = file.filename

        if filename == "":
            return jsonify({"status": "error", "message": "No selected file"}), 400

        # Save file locally
        filepath = os.path.join("/tmp", filename)
        file.save(filepath)

        # Upload file to S3
  s3_client.upload_file(filepath, RESUME_BUCKET_NAME, filename)

        # ⭐ USE YOUR REAL PARSER HERE
        parsed_data = parse_resume(filepath)

        return jsonify({
            "status": "success",
            "s3_key": filename,
            "parsed_text": parsed_data.get("raw_text", ""),
            "parsed": parsed_data  # full structured output
        }), 200

    except Exception as e:
        print("UPLOAD ERROR:", str(e))
        return jsonify({"status": "error", "message": str(e)}), 500

    except Exception as e:

        print("UPLOAD ERROR:", str(e))
        return jsonify({
            "status": "error",
            "message": str(e)   # <-- THIS is what will finally show on the frontend
        }), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)



