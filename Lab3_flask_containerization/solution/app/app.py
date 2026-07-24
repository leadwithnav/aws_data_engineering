import os
import socket
import datetime
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    return "Welcome to the Containerized Flask Application!"

@app.route('/health')
def health():
    return "healthy"

if __name__ == '__main__':
    # Local development server (Gunicorn will run the app in production)
    app.run(host='0.0.0.0', port=5000, debug=True)
