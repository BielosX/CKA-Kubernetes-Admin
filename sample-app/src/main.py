from flask import Flask
import json
import socket
import os
import time

app = Flask(__name__)

ip = socket.gethostbyname(socket.getfqdn())
started = time.ctime(os.path.getmtime('/proc/1/cmdline'))


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
