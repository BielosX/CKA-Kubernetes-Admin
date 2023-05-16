#!/bin/bash

# Create static pod (managed directly by kubelet)
temp_path=$(mktemp)
kubectl run busybox \
  --image=busybox:1.36.0 \
  --dry-run=client \
  -o yaml -- sh -c 'sleep 10; echo "Hello"' > "$temp_path"
minikube cp "$temp_path" /etc/kubernetes/manifests/hello.yaml
rm "$temp_path"

# Expose Redis server created in test-namespace as NodePort service available on 30123
kubectl create namespace test-namespace
kubectl run redis --image=redis:7-alpine --port 6379 -n test-namespace
kubectl create service nodeport redis-service --tcp=6379:6379 --node-port=30123 -n test-namespace