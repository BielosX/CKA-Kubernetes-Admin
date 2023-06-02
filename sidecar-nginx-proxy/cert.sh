#!/bin/sh

apk add openssl

openssl req -newkey rsa:4096 \
            -x509 \
            -sha256 \
            -days 365 \
            -nodes \
            -out /etc/nginx/cert/nginx.crt \
            -keyout /etc/nginx/cert/nginx.key \
            -subj "/C=us/ST=washington/L=seattle/O=example/OU=example/CN=example.com"