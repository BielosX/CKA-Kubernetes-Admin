#!/bin/bash

CONTAINERD_VERSION="$1"
CONTAINERD_URL="https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
wget -nv -O containerd.tar.gz "$CONTAINERD_URL"
tar Cxzvf /usr/local containerd.tar.gz
mkdir -p /usr/local/lib/systemd/system
wget -nv -O /usr/local/lib/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

RUNC_VERSION="$2"
wget -nv -O runc.amd64 "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64"
install -m 755 runc.amd64 /usr/local/sbin/runc

systemctl daemon-reload
systemctl enable containerd.service
systemctl start containerd.service
