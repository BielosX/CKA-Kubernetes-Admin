#!/bin/bash

# Create static pod (managed directly by kubelet)
temp_path=$(mktemp)
kubectl run busybox \
  --image=busybox:1.36.0 \
  --dry-run=client \
  -o yaml -- sh -c 'sleep 10; echo "Hello"' > "$temp_path"
minikube cp "$temp_path" /etc/kubernetes/manifests/hello.yaml
rm "$temp_path"