from flask import Flask, request
import json
import socket
import os
import time

app = Flask(__name__)

ip = socket.gethostbyname(socket.getfqdn())
started = time.ctime(os.path.getmtime('/proc/1/cmdline'))
health = "HEALTHY"


@app.route("/")
def hello_world():
    return "Hello"


@app.route("/details")
def details():
    response = {
        'started': str(started),
        'ip': str(ip)
    }
    return json.dumps(response)


@app.route("/health")
def get_health():
    global health
    if health == "HEALTHY":
        return health, 200
    else:
        return "UNHEALTHY", 500


@app.route("/health", methods=['POST'])
def set_health():
    data = request.get_json()
    global health
    health = data['health']
    return "OK"
