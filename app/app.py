from flask import Flask, jsonify
import os
from datetime import datetime, timezone

app = Flask(__name__)

@app.get("/")
def dashboard():
    return jsonify({
        "service":"CloudOps AutoPilot",
        "status":"running",
        "environment":os.getenv("APP_ENV","development"),
        "time_utc":datetime.now(timezone.utc).isoformat(),
        "features":["CloudWatch monitoring","Event-driven remediation","Lambda + Boto3","Terraform","Docker"]
    })

@app.get("/health")
def health():
    return jsonify({"status":"healthy"}), 200

@app.get("/api/status")
def status():
    return jsonify({"monitoring":"active","remediation_engine":"ready","deployment":"automated"})

if __name__ == "__main__":
    app.run(host="0.0.0.0",port=5000)
